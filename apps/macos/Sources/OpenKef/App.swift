import AppKit
import SwiftUI

/// Entry point. Modes:
///   OPENKEF_HOST=<ip>           bind to a speaker directly (else Bonjour `_kef-info._tcp`)
///   OPENKEF_MOCK=<state>        render a fixture state without a speaker (playing|paused|offline|switching|loading|error)
///   OpenKef --music-now-playing  print Music.app's current track (or 'not running') and exit
///   OpenKef --snapshot-window <dir>  MET-11 window states, light + dark
///   OpenKef --snapshot <dir>    write every state, light + dark, as 2x PNGs and exit
@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--music-now-playing") {   // MET-11 check: prints Music's current track; never launches Music
            switch MusicReader.read() {
            case .notRunning: print("Music: not running")
            case .failed(let e): print("Music: error: \(e)")
            case .track(let t):
                print("Music: \(t.state)" + (t.name.isEmpty ? "" : " | \(t.name) | \(t.artist) | \(t.album) | \(Int(t.position))s/\(Int(t.duration))s"))
            }
            return
        }
        if let i = args.firstIndex(of: "--snapshot-window"), i + 1 < args.count {
            MainActor.assumeIsolated { WindowSnapshot.run(to: URL(fileURLWithPath: args[i + 1])) }
            return
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            MainActor.assumeIsolated { Snapshot.run(to: URL(fileURLWithPath: args[i + 1])) }
            return
        }
        OpenKefApp.main()
    }
}

struct OpenKefApp: App {
    @StateObject private var model = OpenKefApp.makeModel()
    @StateObject private var route = WindowModel()
    @StateObject private var music = MusicNowPlayingModel()

    var body: some Scene {
        MenuBarExtra("open-kef", systemImage: "hifispeaker") {
            PanelView(model: model)
        }
        .menuBarExtraStyle(.window)

        // MET-11 Now Playing window. Opened with ⌘0 from the app menu, or at launch with OPENKEF_WINDOW=1.
        Window("OpenKef", id: "now-playing") {
            NowPlayingWindow(model: model, route: route, music: music)
                .onAppear { route.start(); music.start() }
                .onDisappear { route.stop(); music.stop() }
        }
        .windowResizability(.contentSize)
        .keyboardShortcut("0")
        .launchPresented(ProcessInfo.processInfo.environment["OPENKEF_WINDOW"] == "1")
    }

    @MainActor static func makeModel() -> PanelModel {
        let env = ProcessInfo.processInfo.environment
        if let m = env["OPENKEF_MOCK"] { return Mock.model(m) }
        if let host = env["OPENKEF_HOST"], let c = SpeakerClient(host: host) {
            let m = PanelModel(client: c); m.start(); return m
        }
        let m = PanelModel(client: nil)
        let search = { [weak m] in
            discovery.find { host in
                Task { @MainActor in
                    guard let m else { return }
                    if let host, let c = SpeakerClient(host: host) { m.bind(c) } else { m.phase = .offline }
                }
            }
        }
        m.rediscover = search
        search()
        return m
    }
    private static let discovery = Discovery()
}

extension Scene {
    /// Window shown at launch only when asked (macOS 15+; on 14 it opens with ⌘0).
    func launchPresented(_ on: Bool) -> some Scene {
        if #available(macOS 15.0, *) { return AnyScene15(self.defaultLaunchBehavior(on ? .presented : .suppressed)) }
        return AnyScene15(self)
    }
}
struct AnyScene15<S: Scene>: Scene { let s: S; init(_ s: S) { self.s = s }; var body: some Scene { s } }
