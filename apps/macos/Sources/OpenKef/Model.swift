import Foundation
import SwiftUI

/// Mirrors openkef_core::SpeakerState (JSON over the C ABI).
struct SpeakerState: Codable, Equatable {
    struct NowPlaying: Codable, Equatable {
        var state = ""; var title = ""; var artist = ""; var album = ""; var artwork_url = ""
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
            if case .switching(let to, _) = phase, s.source != to { state = s; return }
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
        let from = state.source
        phase = .switching(to: id, from: from)
        guard let client else { return }
        Task.detached { [weak self] in
            let ok = client.setSource(id)
            await self?.sourceDone(ok: ok, id: id)
        }
    }

    private func sourceDone(ok: Bool, id: String) {
        if ok { error = nil; state.source = id } else { fail("Couldn’t switch source.") }
        if case .switching = phase { phase = .ready }
    }

    func playPause() {
        guard let client else { return }
        Task.detached { [weak self] in
            let ok = client.playPause()
            await MainActor.run { if ok { self?.error = nil } else { self?.fail("Couldn’t change playback.") } }
        }
    }

    func retry() { phase = .loading; client?.start() }

    private func fail(_ msg: String) {
        displayVolume = state.volume   // snap back to the last level the speaker reported
        error = msg
    }
}
