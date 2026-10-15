import AppKit
import Foundation

/// Current track from the Mac's Music app (MET-11), via AppleScript (public Apple Events).
/// Never launches Music: it checks NSRunningApplication first and returns nil when Music isn't running.
/// Needs NSAppleEventsUsageDescription in Info.plist and the user's Automation consent for Music.
struct MusicTrack: Equatable {
    var name = "", artist = "", album = ""
    var duration: Double = 0, position: Double = 0
    /// "playing" / "paused" / "stopped" / "fast forwarding" / "rewinding"
    var state = ""
}

enum MusicReader {
    static let bundleID = "com.apple.Music"
    static var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }

    // Fields joined by U+001F so titles with commas/tabs survive.
    private static let script = """
    tell application id "com.apple.Music"
      set pstate to player state as text
      if pstate is "stopped" then return pstate
      set trk to current track
      set sep to (ASCII character 31)
      return pstate & sep & (name of trk) & sep & (artist of trk) & sep & (album of trk) & sep & ((duration of trk) as text) & sep & ((player position) as text)
    end tell
    """

    enum Result: Equatable { case notRunning, track(MusicTrack), failed(String) }

    /// Blocking (Apple Events round-trip); call off the main thread.
    static func read() -> Result {
        guard isRunning else { return .notRunning }   // `tell application` would launch it otherwise
        var err: NSDictionary?
        guard let out = NSAppleScript(source: script)?.executeAndReturnError(&err).stringValue else {
            return .failed((err?[NSAppleScript.errorMessage] as? String) ?? "AppleScript error")
        }
        return .track(parse(out))
    }

    static func parse(_ s: String) -> MusicTrack {
        let f = s.components(separatedBy: "\u{1F}")
        var t = MusicTrack(state: f[0])
        guard f.count >= 6 else { return t }
        let num = { (x: String) in Double(x.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        t.name = f[1]; t.artist = f[2]; t.album = f[3]; t.duration = num(f[4]); t.position = num(f[5])
        return t
    }
}

/// Observable wrapper that polls Music every `interval` while started. Not wired into any UI yet.
@MainActor
final class MusicNowPlayingModel: ObservableObject {
    @Published private(set) var track: MusicTrack?
    @Published private(set) var running = false
    @Published private(set) var error: String?
    private var timer: Timer?

    func start(interval: TimeInterval = 2) {
        stop(); refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }

    func refresh() {
        Task.detached {
            let r = MusicReader.read()
            await MainActor.run { [weak self] in self?.apply(r) }
        }
    }
    private func apply(_ r: MusicReader.Result) {
        switch r {
        case .notRunning: running = false; track = nil; error = nil
        case .track(let t): running = true; track = t; error = nil
        case .failed(let e): running = true; error = e
        }
    }
}
