import AppKit
import SwiftUI

/// Fixture states matching mockups/met-7 (Teardrop · Massive Attack, volume 40, Wi-Fi, Living Room · LSX II LT).
enum Mock {
    static let states = ["playing", "paused", "offline", "switching", "loading", "error"]

    @MainActor static func model(_ name: String) -> PanelModel {
        let m = PanelModel(client: nil)
        var s = SpeakerState()
        s.volume = 40; s.source = "wifi"; s.status = "powerOn"
        s.device_name = "Living Room"; s.model_name = "LSX II LT"
        s.now_playing = .init(state: name == "paused" ? "paused" : "playing", title: "Teardrop",
                              artist: "Massive Attack", album: "Mezzanine", artwork_url: "")
        m.state = s
        m.displayVolume = 40
        switch name {
        case "offline": m.phase = .offline
        case "switching": m.phase = .switching(to: "tv", from: "wifi")
        case "loading": m.phase = .loading; m.state.device_name = ""
        case "error": m.phase = .ready; m.error = "Couldn’t set volume. Reverted."
        default: m.phase = .ready
        }
        return m
    }
}

/// `--snapshot <dir>`: renders each state at panel width, 2x, light and dark, via ImageRenderer.
enum Snapshot {
    @MainActor static func run(to dir: URL) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            for name in Mock.states {
                let view = PanelView(model: Mock.model(name), snapshot: true)
                    .environment(\.colorScheme, scheme)
                let r = ImageRenderer(content: view)
                r.scale = 2
                guard let cg = r.cgImage else { print("render failed: \(name)"); continue }
                let rep = NSBitmapImageRep(cgImage: cg)
                let file = dir.appendingPathComponent("c-the-ruler--\(name)\(scheme == .dark ? "--dark" : "").png")
                try? rep.representation(using: .png, properties: [:])?.write(to: file)
                print("wrote \(file.path)")
            }
        }
    }
}
