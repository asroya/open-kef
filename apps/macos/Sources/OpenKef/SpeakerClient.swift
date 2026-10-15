import COpenKef
import Foundation
import Network

/// Thin Swift wrapper over the Rust C ABI. All calls block; never call on the main thread.
final class SpeakerClient: @unchecked Sendable {
    enum Event { case state(SpeakerState), offline(String) }
    var onEvent: ((Event) -> Void)?
    private let handle: OpaquePointer

    init?(host: String) {
        guard let h = okef_connect(host) else { return nil }
        handle = h
    }
    deinit { okef_free(handle) }

    func setVolume(_ v: Int) -> Bool { okef_set_volume(handle, UInt8(clamping: v)) == 0 }
    func setMute(_ m: Bool) -> Bool { okef_set_mute(handle, m) == 0 }
    func setSource(_ id: String) -> Bool { okef_set_source(handle, id) == 0 }
    func playPause() -> Bool { okef_play_pause(handle) == 0 }
    func next() -> Bool { okef_next(handle) == 0 }
    func previous() -> Bool { okef_previous(handle) == 0 }

    func state() -> SpeakerState? {
        guard let p = okef_get_state(handle) else { return nil }
        defer { okef_string_free(p) }
        return try? JSONDecoder().decode(SpeakerState.self, from: Data(String(cString: p).utf8))
    }

    /// Starts the Rust subscribe/long-poll loop (reconnect + backoff + offline detection live in Rust).
    func start() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        okef_events_start(handle, { ctx, json in
            guard let ctx, let json else { return }
            let me = Unmanaged<SpeakerClient>.fromOpaque(ctx).takeUnretainedValue()
            me.dispatch(String(cString: json))
        }, ctx)
    }

    private struct Wire: Decodable { let type: String; let state: SpeakerState?; let reason: String? }
    private func dispatch(_ json: String) {
        guard let w = try? JSONDecoder().decode(Wire.self, from: Data(json.utf8)) else { return }
        if w.type == "state", let s = w.state { onEvent?(.state(s)) } else { onEvent?(.offline(w.reason ?? "")) }
    }
}

/// Bonjour discovery of `_kef-info._tcp`; resolves the first speaker to an IP host string.
final class Discovery {
    private var browser: NWBrowser?
    private var conn: NWConnection?

    func find(_ done: @escaping (String) -> Void) {
        let b = NWBrowser(for: .bonjour(type: "_kef-info._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, self.conn == nil, let r = results.first else { return }
            let c = NWConnection(to: r.endpoint, using: .tcp)
            self.conn = c
            c.stateUpdateHandler = { st in
                guard case .ready = st, case .hostPort(let host, _)? = c.currentPath?.remoteEndpoint else { return }
                var h = "\(host)"
                if let pct = h.firstIndex(of: "%") { h = String(h[..<pct]) }
                c.cancel(); b.cancel()
                done(h)
            }
            c.start(queue: .global())
        }
        b.start(queue: .global())
        browser = b
    }
}
