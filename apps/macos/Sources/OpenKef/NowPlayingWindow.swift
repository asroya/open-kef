import AVKit
import SwiftUI

// MET-11 Now Playing window (mockups/met-11 rev 2 + tokens v0.4). Idle subline = device · source.

enum WindowState: Equatable { case playing, mac, idle, offline, connecting }

@MainActor
final class WindowModel: ObservableObject {
    @Published var macIsAirPlaying = false
    private var timer: Timer?
    func start() {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }
    func stop() { timer?.invalidate(); timer = nil }
    func refresh() { macIsAirPlaying = MacAudioRoute.defaultOutputIsAirPlay() }
}

struct NowPlayingWindow: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var route: WindowModel
    @ObservedObject var music: MusicNowPlayingModel
    var snapshot = false
    @Environment(\.colorScheme) private var scheme
    private var p: T.Palette { scheme == .dark ? T.dark : T.light }

    var state: WindowState {
        if model.phase == .offline { return .offline }
        if model.phase == .loading { return .connecting }
        if route.macIsAirPlaying && model.state.source == "wifi" { return .mac }
        let np = model.state.now_playing
        if !np.title.isEmpty && (np.state == "playing" || np.state == "paused") { return .playing }
        return .idle
    }
    private var offline: Bool { state == .offline }
    private var loading: Bool { state == .connecting }
    /// Match the panel: disable ruler / inputs / AirPlay until truly connected.
    private var controlsEnabled: Bool { !offline && !loading }
    private var name: String { model.deviceName }

    var body: some View {
        VStack(spacing: 0) {
            if snapshot { titleBar }
            VStack(alignment: .leading, spacing: 0) {
                nowPlaying
                section { airplayRow }
                section { input }
                section { otherApps }
            }
            .padding(.top, T.Space.s5).padding(.horizontal, T.Space.s5).padding(.bottom, T.Space.s4)
            footer
        }
        .frame(minWidth: T.Window.minWidth, idealWidth: T.Window.width)
        .frame(width: T.Window.width)
        .background(p.bg)
        .foregroundStyle(p.text)
        .overlay { if snapshot { RoundedRectangle(cornerRadius: T.Radius.panel).strokeBorder(p.line, lineWidth: 1) } }
        .clipShape(RoundedRectangle(cornerRadius: snapshot ? T.Radius.panel : 0))
        .environment(\.palette, p)
        .toolbar { ToolbarItem(placement: .status) { status } }
    }

    // MARK: chrome (snapshot stand-in for the native title bar)
    private var titleBar: some View {
        HStack(spacing: T.Space.s2) {
            HStack(spacing: T.Space.s2) { ForEach(0..<3) { _ in Circle().strokeBorder(p.line, lineWidth: 1).background(Circle().fill(p.bg)).frame(width: T.Space.s3, height: T.Space.s3) } }
            Spacer()
            Text("OpenKef").typeStyle(T.TypeScale.label)
            Spacer()
            status
        }
        .padding(.horizontal, T.Space.s3)
        .frame(height: T.Size.rowHeight)
        .background(p.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(p.line).frame(height: 1) }
    }
    private var status: some View {
        let label = offline ? "Offline" : loading ? "Connecting" : "Connected"
        let dot = offline ? T.Status.offline(p) : loading ? p.textMuted : T.Status.connected(p)
        let text = offline ? p.danger : p.textMuted
        return HStack(spacing: T.Space.s1) {
            Circle().fill(dot).frame(width: T.Status.dot, height: T.Status.dot)
            Text(label).typeStyle(T.TypeScale.label).foregroundStyle(text)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: now playing + ruler
    private var lines: (title: String, sub: String?, label: String?) {
        let np = model.state.now_playing
        let src = sourceLabel(model.state.source)
        switch state {
        case .offline: return ("\(name) is offline", "Check that the speaker is on and on this network", nil)
        case .connecting: return ("Connecting…", name, nil)
        case .mac:
            if let t = music.track, t.state == "playing", !t.name.isEmpty {
                return (t.name, [t.artist, t.album].filter { !$0.isEmpty }.joined(separator: " · "), "AirPlay 2 from this Mac · Wi-Fi")
            }
            return ("This Mac", "System audio", "AirPlay 2 from this Mac · Wi-Fi")
        case .playing:
            let sub = [np.artist, np.album].filter { !$0.isEmpty }.joined(separator: " · ")
            return (np.title, sub.isEmpty ? nil : sub, model.state.source == "wifi" ? "AirPlay 2 · Wi-Fi" : src)
        case .idle: return ("Nothing playing", "\(name) · \(src)", src)
        }
    }

    private var nowPlaying: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: T.Space.s4) {
                art
                VStack(alignment: .leading, spacing: 0) {
                    Text(lines.title).typeStyle(T.TypeScale.title)
                        .foregroundStyle(offline ? p.danger : (state == .idle || loading) ? p.textMuted : p.text)
                    if let s = lines.sub { Text(s).typeStyle(T.TypeScale.body).foregroundStyle(p.textMuted) }
                    if let l = lines.label { Text(l).typeStyle(T.TypeScale.label).foregroundStyle(p.textMuted) }
                }
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                transport
            }
            RulerView(volume: model.displayVolume, showLevel: controlsEnabled, loading: loading, enabled: controlsEnabled,
                      snapshot: snapshot, pinBottom: true, set: model.setVolume)
                .padding(.top, T.Space.s5)
            Color.clear.frame(height: T.Space.s4)   // section padding-bottom (space.4)
        }
        .accessibilityElement(children: .contain).accessibilityLabel("Now playing")
    }

    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: T.Radius.art).fill(p.surface)
            RoundedRectangle(cornerRadius: T.Radius.art).strokeBorder(p.line, lineWidth: 1)
            Image(systemName: offline ? "exclamationmark.triangle" : state == .mac ? "airplayaudio" : "music.note")
                .foregroundStyle(offline ? p.danger : p.textMuted)
        }
        .font(.system(size: T.Icon.size, weight: T.Icon.weight))
        .frame(width: T.Size.artLarge, height: T.Size.artLarge)
        .accessibilityHidden(true)
    }

    private var transport: some View {
        let c = model.state.now_playing.controls
        let live = state == .playing || state == .mac
        let showPause = live && model.isPlaying
        return HStack(spacing: 0) {
            Button { model.skip(forward: false) } label: { glyph("backward.fill") }
                .disabled(!live || !c.previous).accessibilityLabel("Previous")
            Button(action: model.playPause) { glyph(showPause ? "pause.fill" : "play.fill") }
                .disabled(!live || (showPause && !c.pause)).accessibilityLabel(showPause ? "Pause" : "Play")
            Button { model.skip(forward: true) } label: { glyph("forward.fill") }
                .disabled(!live || !c.next).accessibilityLabel("Next")
        }
        .buttonStyle(HitButtonStyle())
    }
    private func glyph(_ s: String) -> some View { Image(systemName: s).font(.system(size: T.Icon.size * 0.75, weight: T.Icon.weight)) }

    // MARK: sections
    private func section<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        // Mockup: each section is `padding: space.4 0` with a 1pt `color.line` top border.
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(p.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 0) { c() }.padding(.vertical, T.Space.s4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func header(_ s: String) -> some View {
        Text(s).typeStyle(T.TypeScale.label).foregroundStyle(p.textMuted).padding(.bottom, T.Space.s2)
    }

    private var airplayRow: some View {
        HStack(spacing: T.Space.s3) {
            VStack(alignment: .leading, spacing: 0) {
                Text(state == .mac ? "This Mac is playing on \(name)" : "Play to \(name) with AirPlay")
                    .font(.system(size: T.TypeScale.body.size, weight: T.TypeScale.title.weight))
                Text(state == .mac ? "Mac output is set to \(name) · AirPlay 2" : "Opens the AirPlay menu. Pick \(name) as the output.")
                    .typeStyle(T.TypeScale.body).foregroundStyle(p.textMuted)
            }
            .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            AirPlayButton(snapshot: snapshot).disabled(!controlsEnabled)
        }
        .frame(minHeight: T.Size.rowHeight)
        .accessibilityElement(children: .contain).accessibilityLabel("AirPlay")
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Input")
            HStack(spacing: T.Space.s4) {
                ForEach(panelSources, id: \.id) { src in
                    let active = !offline && model.state.source == src.id
                    Button { model.setSource(src.id) } label: {
                        Text(src.label)
                            .font(.system(size: T.TypeScale.body.size, weight: active ? T.TypeScale.title.weight : T.TypeScale.body.weight))
                            .foregroundStyle(active ? p.text : p.textMuted)
                            .frame(height: T.Size.iconHit).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!controlsEnabled)
                    .opacity(controlsEnabled ? 1 : T.Opacity.disabled)
                    .accessibilityAddTraits(active ? [.isSelected] : [])
                }
            }
        }
        .accessibilityElement(children: .contain).accessibilityLabel("Input")
    }

    private var otherApps: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Other apps")
            VStack(alignment: .leading, spacing: 0) {
                Text("YouTube Music").font(.system(size: T.TypeScale.body.size, weight: T.TypeScale.title.weight))
                Text("On this Mac: play it in Safari, then choose \(name) from Safari’s AirPlay button.").typeStyle(T.TypeScale.body).foregroundStyle(p.textMuted)
                Text("On your phone: tap Cast in the YouTube Music app and choose \(name) (Google Cast).").typeStyle(T.TypeScale.body).foregroundStyle(p.textMuted)
            }
            .padding(.vertical, T.Space.s2)
        }
    }

    private var footer: some View {
        HStack(spacing: T.Space.s3) {
            Text("\(name) · \(model.modelName)")
            Spacer()
            Text(offline ? "Last seen on this network" : loading ? "Looking for \(name) on this network" : "\(sourceLabel(model.state.source)) input")
        }
        .typeStyle(T.TypeScale.label).foregroundStyle(p.textMuted).lineLimit(1)
        .padding(.vertical, T.Space.s2).padding(.horizontal, T.Space.s5)
        .background(p.surface)
        .overlay(alignment: .top) { Rectangle().fill(p.line).frame(height: 1) }
    }
}

/// The window's single primary action: filled `accent` button. A transparent AVRoutePickerView sits on top
/// so the click opens the system AirPlay picker (public API; we can't select the route ourselves).
struct AirPlayButton: View {
    var snapshot = false
    @Environment(\.palette) private var p
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        HStack(spacing: T.Space.s2) {
            Image(systemName: "airplayaudio").font(.system(size: T.Icon.size, weight: T.Icon.weight))
            Text("AirPlay").font(.system(size: T.TypeScale.body.size, weight: T.Button.Primary.labelWeight))
        }
        .foregroundStyle(T.Button.Primary.labelColor(p))
        .padding(.horizontal, T.Button.Primary.paddingX)
        .frame(height: T.Button.Primary.height)
        .background(RoundedRectangle(cornerRadius: T.Button.Primary.radius).fill(T.Button.Primary.fill(p)))
        .opacity(enabled ? 1 : T.Button.Primary.disabledOpacity)
        .overlay { if !snapshot && enabled { RoutePicker().opacity(0.02) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AirPlay")
        .accessibilityHint("Opens the AirPlay menu")
        .accessibilityAddTraits(.isButton)
    }
}

struct RoutePicker: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView(); v.isRoutePickerButtonBordered = false; return v
    }
    func updateNSView(_ v: AVRoutePickerView, context: Context) {}
}
