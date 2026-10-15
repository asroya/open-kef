import Foundation
import SwiftUI

/// Mirrors openkef_core::SpeakerState (JSON over the C ABI).
struct SpeakerState: Codable, Equatable {
    struct NowPlaying: Codable, Equatable {
        struct Controls: Codable, Equatable { var next = false; var previous = false; var pause = false }
        var state = ""; var title = ""; var artist = ""; var album = ""; var artwork_url = ""
        var controls = Controls()
    }
    var volume: Int = 0
    var muted = false
    var source = ""
    var status = ""
    var now_playing = NowPlaying()
    var device_name = ""
    var model_name = ""
}

/// Panel sources for the LSX II LT, in order (MET-6). Wire name -> label.
let panelSources: [(id: String, label: String)] = [
    ("wifi", "Wi-Fi"), ("bluetooth", "Bluetooth"), ("tv", "TV"), ("optical", "Optical"), ("usb", "USB"),
]
func sourceLabel(_ id: String) -> String { panelSources.first { $0.id == id }?.label ?? id }

enum Phase: Equatable {
    case loading
    case ready
    case offline
    case switching(to: String, from: String)
}

@MainActor
final class PanelModel: ObservableObject {
    @Published var phase: Phase = .loading
    @Published var state = SpeakerState()
    /// Volume shown on the ruler (optimistic while dragging).
    @Published var displayVolume: Int = 0
    @Published var error: String?
    /// Fallback name for loading/offline before the speaker reports one.
    @Published var fallbackName = "Living Room"

    private var client: SpeakerClient?
    private var volumeInFlight = false
    private var pendingVolume: Int?
    private var playInFlight = false
    /// Restarts Bonjour discovery when there is no speaker bound yet (set by the app).
    var rediscover: (() -> Void)?

    init(client: SpeakerClient?) { self.client = client }

    var isPlaying: Bool { state.now_playing.state == "playing" }
    var deviceName: String { state.device_name.isEmpty ? fallbackName : state.device_name }
    var modelName: String { state.model_name.isEmpty ? "LSX II LT" : state.model_name }

    /// Binds a speaker found later (Bonjour) and starts its event loop.
    func bind(_ c: SpeakerClient) { client = c; start() }

    func start() {
        client?.onEvent = { [weak self] ev in
            Task { @MainActor in self?.handle(ev) }
        }
        client?.start()
    }

    func handle(_ ev: SpeakerClient.Event) {
        switch ev {
        case .state(let s):
            if case .switching(let to, _) = phase {
                // Hold the optimistic source until the speaker reports it (or the switch times out/fails).
                guard s.source == to else { var t = s; t.source = to; state = t; return }
            }
            state = s
            if pendingVolume == nil && !volumeInFlight { displayVolume = s.volume }
            phase = .ready
        case .offline:
            phase = .offline
        }
    }

    // MARK: commands

    func setVolume(_ v: Int) {
        displayVolume = v
        guard let client else { return }
        if volumeInFlight { pendingVolume = v; return }
        volumeInFlight = true
        Task.detached { [weak self] in
            let ok = client.setVolume(v)
            await self?.volumeDone(ok: ok)
        }
    }

    private func volumeDone(ok: Bool) {
        volumeInFlight = false
        if let next = pendingVolume { pendingVolume = nil; setVolume(next); return }
        if ok { error = nil; state.volume = displayVolume } else { fail("Couldn’t set volume. Reverted.") }
    }

    func setSource(_ id: String) {
        guard phase == .ready, id != state.source else { return }
        guard let client else { return }   // no speaker bound (mock/discovery): nothing to switch
        let from = state.source
        phase = .switching(to: id, from: from)
        Task.detached { [weak self] in
            let ok = client.setSource(id)
            await self?.sourceDone(ok: ok, id: id)
        }
    }

    private func sourceDone(ok: Bool, id: String) {
        guard case .switching(let to, let from) = phase, to == id else { return }
        if !ok { state.source = from; phase = .ready; fail("Couldn’t switch source."); return }
        error = nil
        state.source = id
        // Stay in .switching until a poll confirms `id`; give up waiting after 5 s.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, case .switching(let t, _) = self.phase, t == id else { return }
            self.phase = .ready
        }
    }

    func playPause() {
        guard let client, !playInFlight else { return }
        // Decide the target once, before the call, so a `state` event that lands first can't make us invert it again.
        let from = state.now_playing.state
        // The UI decides the target; the core sends that exact command (no re-read + toggle in Rust).
        let target = isPlaying ? "paused" : "playing"
        playInFlight = true
        state.now_playing.state = target
        Task.detached { [weak self] in
            let ok = client.setPlaying(target == "playing")
            await self?.playDone(ok: ok, from: from, target: target)
        }
    }

    private func playDone(ok: Bool, from: String, target: String) {
        playInFlight = false
        if ok { error = nil; return }
        if state.now_playing.state == target { state.now_playing.state = from }
        fail("Couldn’t change playback.")
    }

    /// Skip track. Only sent when the speaker reports the control as available.
    func skip(forward: Bool) {
        guard let client, phase == .ready else { return }
        let c = state.now_playing.controls
        guard forward ? c.next : c.previous else { return }
        Task.detached { [weak self] in
            let ok = forward ? client.next() : client.previous()
            if !ok { await self?.fail("Couldn’t skip track.") }
        }
    }

    func retry() {
        phase = .loading
        if let client { client.start() } else { rediscover?() }
    }

    private func fail(_ msg: String) {
        displayVolume = state.volume   // snap back to the last level the speaker reported
        error = msg
    }
}
