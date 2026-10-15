import AppKit
import SwiftUI

/// Fixture states matching mockups/met-7 (Teardrop · Massive Attack, volume 40, Wi-Fi, Living Room · LSX II LT).
enum Mock {
    static let states = ["playing", "paused", "offline", "switching", "loading", "error", "tv-playing"]

    @MainActor static func model(_ name: String) -> PanelModel {
        let m = PanelModel(client: nil)
        var s = SpeakerState()
        s.volume = 40; s.source = "wifi"; s.status = "powerOn"
        s.device_name = "Living Room"; s.model_name = "LSX II LT"
        s.now_playing = .init(state: name == "paused" ? "paused" : "playing", title: "Teardrop",
                              artist: "Massive Attack", album: "Mezzanine", artwork_url: "")
        s.now_playing.controls = .init(next: true, previous: true, pause: true)
        if name == "tv-playing" {
            // Live MET-6 shape for the TV input: title "TV", no metadata, every control false.
            s.source = "tv"
            s.now_playing = .init(state: "playing", title: "TV", artist: "", album: "", artwork_url: "")
            s.now_playing.controls = .init(next: false, previous: false, pause: false)
        }
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

/// `--snapshot-window <dir>`: MET-11 window states (playing, mac, idle, offline), light + dark, 2x.
enum WindowSnapshot {
    static let states = ["playing", "mac", "idle", "offline"]
    @MainActor static func run(to dir: URL) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            for name in states {
                let m = Mock.model(name == "offline" ? "offline" : "playing")
                let route = WindowModel()
                switch name {
                case "mac": route.macIsAirPlaying = true; m.state.now_playing = .init(state: "playing"); m.state.now_playing.controls = .init(next: true, previous: true, pause: true)
                case "idle": m.state.now_playing = .init(state: "stopped")
                default: break
                }
                let view = NowPlayingWindow(model: m, route: route, music: MusicNowPlayingModel(), snapshot: true)
                    .environment(\.colorScheme, scheme)
                let r = ImageRenderer(content: view); r.scale = 2
                guard let cg = r.cgImage else { print("render failed: \(name)"); continue }
                let file = dir.appendingPathComponent("window--\(name)--\(scheme == .dark ? "dark" : "light").png")
                try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: file)
                print("wrote \(file.path)")
            }
        }
    }
}
