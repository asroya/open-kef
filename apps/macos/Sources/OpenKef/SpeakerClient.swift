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

/// Bonjour discovery of `_kef-info._tcp`; resolves a speaker to an IPv4 host string.
/// Calls `done(nil)` if browsing fails or nothing resolves within `timeout`, so the UI can leave `loading`.
final class Discovery {
    private let q = DispatchQueue(label: "openkef.discovery")
    private var browser: NWBrowser?
    private var conn: NWConnection?
    private var tried = Set<NWEndpoint>()
    private var done: ((String?) -> Void)?

    func find(timeout: TimeInterval = 8, _ done: @escaping (String?) -> Void) {
        q.async { [self] in
            stop()
            self.done = done
            tried = []
            let b = NWBrowser(for: .bonjour(type: "_kef-info._tcp", domain: nil), using: .tcp)
            b.stateUpdateHandler = { [weak self] st in
                if case .failed = st { self?.finish(nil) }
            }
            b.browseResultsChangedHandler = { [weak self] results, _ in self?.tryNext(results) }
            browser = b
            b.start(queue: q)
            q.asyncAfter(deadline: .now() + timeout) { [weak self] in self?.finish(nil) }
        }
    }

    private func tryNext(_ results: Set<NWBrowser.Result>) {
        guard done != nil, conn == nil, let r = results.first(where: { !tried.contains($0.endpoint) }) else { return }
        tried.insert(r.endpoint)
        // Prefer IPv4 so the host string is a plain dotted quad (no scoped IPv6 literals).
        let params = NWParameters.tcp
        (params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options)?.version = .v4
        let c = NWConnection(to: r.endpoint, using: params)
        conn = c
        c.stateUpdateHandler = { [weak self] st in
            guard let self else { return }
            switch st {
            case .ready:
                guard case .hostPort(let host, _)? = c.currentPath?.remoteEndpoint else { self.drop(c); return }
                var h = "\(host)"
                if let pct = h.firstIndex(of: "%") { h = String(h[..<pct]) }
                self.finish(h)
            case .failed, .waiting:
                self.drop(c)
            default: break
            }
        }
        c.start(queue: q)
    }

    /// A candidate failed: forget it and try any other result we haven't tried yet.
    private func drop(_ c: NWConnection) {
        c.cancel()
        guard conn === c else { return }
        conn = nil
        if let b = browser { tryNext(b.browseResults) }
    }

    private func finish(_ host: String?) {
        guard let d = done else { return }
        done = nil
        stop()
        d(host)
    }

    private func stop() {
        conn?.cancel(); conn = nil
        browser?.cancel(); browser = nil
    }
}
