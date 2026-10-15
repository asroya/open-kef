import AppKit
import SwiftUI

/// Entry point. Modes:
///   OPENKEF_HOST=<ip>           bind to a speaker directly (else Bonjour `_kef-info._tcp`)
///   OPENKEF_MOCK=<state>        render a fixture state without a speaker (playing|paused|offline|switching|loading|error)
///   OpenKef --snapshot <dir>    write every state, light + dark, as 2x PNGs and exit
@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            MainActor.assumeIsolated { Snapshot.run(to: URL(fileURLWithPath: args[i + 1])) }
            return
        }
        OpenKefApp.main()
    }
}

struct OpenKefApp: App {
    @StateObject private var model = OpenKefApp.makeModel()

    var body: some Scene {
        MenuBarExtra("open-kef", systemImage: "hifispeaker") {
            PanelView(model: model)
        }
        .menuBarExtraStyle(.window)
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
