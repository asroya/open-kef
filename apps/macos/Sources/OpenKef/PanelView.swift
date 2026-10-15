import SwiftUI

// Direction C, "The ruler". Every value comes from Tokens.swift (generated from design/tokens.json),
// except 1pt hairlines/tick widths (tokens.rules: "a 1pt line"; tick-width token still open in the spec).

extension View {
    func typeStyle(_ s: T.TypeStyle) -> some View {
        self.font(.system(size: s.size, weight: s.weight))
            .tracking(s.tracking)
            .monospacedDigit(s.tabular)
            .lineSpacing(s.lineHeight - s.size)
            .frame(minHeight: s.lineHeight)
    }
    @ViewBuilder func monospacedDigit(_ on: Bool) -> some View { if on { self.monospacedDigit() } else { self } }
}

struct Palette: EnvironmentKey { static let defaultValue = T.light }
extension EnvironmentValues { var palette: T.Palette { get { self[Palette.self] } set { self[Palette.self] = newValue } } }

/// Square icon button at `size.iconHit`, hover fill `color.surface`.
struct HitButtonStyle: ButtonStyle {
    @Environment(\.palette) var p
    @Environment(\.isEnabled) var enabled
    @State private var hover = false
    var width: CGFloat? = T.Size.iconHit
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(p.text)
            .frame(width: width, height: T.Size.iconHit)
            .padding(.horizontal, width == nil ? T.Space.s2 : 0)
            .background(RoundedRectangle(cornerRadius: T.Radius.control).fill(hover && enabled ? p.surface : .clear))
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : T.Opacity.disabled)
            .onHover { hover = $0 }
    }
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    /// Snapshot mode draws the mockup's `color.bg` + 1pt `color.line` edge instead of the live system material.
    var snapshot = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var p: T.Palette { scheme == .dark ? T.dark : T.light }
    private var offline: Bool { model.phase == .offline }
    private var loading: Bool { model.phase == .loading }
    private var switching: (to: String, from: String)? {
        if case .switching(let to, let from) = model.phase { return (to, from) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nowPlaying
            RulerView(volume: model.displayVolume, showLevel: !offline && !loading, loading: loading,
                      enabled: !offline && !loading, snapshot: snapshot, set: model.setVolume)
                .padding(.top, T.Space.s5)
            sources.padding(.top, T.Space.s4)
            footer.padding(.top, T.Space.s2)
        }
        .padding(T.Space.s3)
        .frame(width: T.Size.panelWidth)
        .background { if snapshot { RoundedRectangle(cornerRadius: T.Radius.panel).fill(p.bg) } }
        .overlay { if snapshot { RoundedRectangle(cornerRadius: T.Radius.panel).strokeBorder(p.line, lineWidth: 1) } }
        .environment(\.palette, p)
        .animation(reduceMotion ? nil : T.Motion.easing(T.Motion.base), value: model.phase)
        .animation(reduceMotion ? nil : T.Motion.easing(T.Motion.fast), value: model.error)
    }

    // MARK: now playing

    private var titleText: (String, String) {
        if offline { return ("\(model.deviceName) is offline", "Check power and Wi-Fi") }
        if let s = switching { return ("Switching to \(sourceLabel(s.to))…", "From \(sourceLabel(s.from))") }
        if loading { return ("Connecting…", model.deviceName) }
        let np = model.state.now_playing
        return (np.title.isEmpty ? sourceLabel(model.state.source) : np.title, np.artist)
    }

    private var nowPlaying: some View {
        HStack(spacing: T.Space.s3) {
            art
            VStack(alignment: .leading, spacing: 0) {
                Text(titleText.0).typeStyle(T.TypeScale.title).foregroundStyle(offline ? p.danger : p.text)
                Text(titleText.1).typeStyle(T.TypeScale.body).foregroundStyle(p.textMuted)
            }
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            let showPause = model.isPlaying && model.phase == .ready
            // Sources like TV report controls.pause == false: the speaker can't pause them.
            let canToggle = showPause ? model.state.now_playing.controls.pause : true
            Button(action: model.playPause) {
                Image(systemName: showPause ? "pause.fill" : "play.fill")
                    .font(.system(size: T.Icon.size * 0.6, weight: T.Icon.weight))
            }
            .buttonStyle(HitButtonStyle())
            .disabled(offline || loading || switching != nil || !canToggle)
            .accessibilityLabel(showPause ? "Pause" : "Play")
        }
    }

    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: T.Radius.art).fill(p.surface)
            RoundedRectangle(cornerRadius: T.Radius.art).strokeBorder(p.line, lineWidth: 1)
            if offline {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(p.danger)
            } else if let url = URL(string: model.state.now_playing.artwork_url), !snapshot,
                      !model.state.now_playing.artwork_url.isEmpty {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { note }
                    .clipShape(RoundedRectangle(cornerRadius: T.Radius.art))
            } else { note }
        }
        .font(.system(size: T.Icon.size, weight: T.Icon.weight))
        .frame(width: T.Size.art, height: T.Size.art)
        .accessibilityHidden(true)
    }
    private var note: some View { Image(systemName: "music.note").foregroundStyle(p.textMuted) }

    // MARK: sources

    private var sources: some View {
        HStack(spacing: T.Space.s3) {
            ForEach(panelSources, id: \.id) { src in
                let active = model.phase == .ready && model.state.source == src.id
                let pending = switching?.to == src.id
                Button { model.setSource(src.id) } label: {
                    Text(src.label)
                        .font(.system(size: T.TypeScale.body.size, weight: active ? T.TypeScale.title.weight : T.TypeScale.body.weight))
                        .tracking(T.TypeScale.body.tracking)
                        .foregroundStyle(pending ? T.Pending.textColor(p) : active ? p.text : p.textMuted)
                        .underline(pending, pattern: .dot, color: T.Pending.underlineColor(p))
                        .frame(height: T.Size.iconHit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(offline || loading)
                .opacity(offline || loading ? T.Opacity.disabled : 1)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Source")
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            if let err = model.error {
                Text(err).typeStyle(T.TypeScale.body).foregroundStyle(p.danger)
                    .accessibilityAddTraits(.updatesFrequently)
                    .onAppear { NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                                                     userInfo: [.announcement: err, .priority: NSAccessibilityPriorityLevel.high.rawValue]) }
            } else {
                Text("\(model.deviceName) · \(model.modelName)").typeStyle(T.TypeScale.label)
                    .foregroundStyle(p.textMuted).lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: T.Space.s2)
            if offline {
                Button("Retry", action: model.retry).typeStyle(T.TypeScale.label)
                    .buttonStyle(HitButtonStyle(width: nil))
            } else if switching != nil {
                Text("Switching…").typeStyle(T.TypeScale.label).foregroundStyle(p.textMuted)
            }
        }
    }
}

/// The tick ruler: a minor tick every `space.1`, a major every 10 minors; ticks below the level in `color.text`.
struct RulerView: View {
    let volume: Int
    let showLevel: Bool
    let loading: Bool
    let enabled: Bool
    var snapshot = false
    let set: (Int) -> Void
    @Environment(\.palette) private var p
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = (CGFloat(volume) / 100 * w).rounded()
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, size in
                    let n = Int(size.width / T.Space.s1)
                    for i in 0...n {
                        let tx = CGFloat(i) * T.Space.s1
                        let major = i % T.Ruler.majorEvery == 0
                        let lit = showLevel && tx < x
                        let h = (lit || major) ? T.Space.s4 : T.Space.s3
                        let c = lit ? T.Ruler.filled(p) : (major ? T.Ruler.major(p) : T.Ruler.minor(p))
                        ctx.fill(Path(CGRect(x: tx, y: size.height - h, width: T.Ruler.tickWidth, height: h)), with: .color(c))
                    }
                    if showLevel {
                        ctx.fill(Path(CGRect(x: min(x, size.width - T.Ruler.tickWidth), y: 0, width: T.Ruler.tickWidth, height: size.height)), with: .color(T.Ruler.filled(p)))
                    }
                }
                if showLevel {
                    let right = x + T.Space.s1 + T.TypeScale.numeric.size * 1.6 > w
                    Text("\(volume)").typeStyle(T.TypeScale.numeric).foregroundStyle(p.text)
                        .fixedSize()
                        .alignmentGuide(.leading) { d in right ? d.width + T.Space.s1 - x : -(x + T.Space.s1) }
                        .alignmentGuide(.bottom) { d in d[.bottom] + T.Space.s5 }
                } else if loading && snapshot {
                    // ImageRenderer can't draw ProgressView; use the mockup's static stand-in ring.
                    ZStack {
                        Circle().stroke(p.line, lineWidth: T.Focus.width)
                        Circle().trim(from: 0, to: 0.25).stroke(p.textMuted, lineWidth: T.Focus.width).rotationEffect(.degrees(-45))
                    }
                    .frame(width: T.Space.s4, height: T.Space.s4)
                    // Sits in the readout's spot above the ruler, matching the mockup.
                    .alignmentGuide(.leading) { _ in -T.Space.s1 }
                    .alignmentGuide(.bottom) { d in d[.bottom] + T.Space.s5 }
                } else if loading {
                    ProgressView().controlSize(.small)
                        .alignmentGuide(.leading) { _ in -T.Space.s1 }
                        .alignmentGuide(.bottom) { d in d[.bottom] + T.Space.s5 }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                guard enabled else { return }
                set(Int((g.location.x / w * 100).rounded()).clamped(0, 100))
            })
        }
        .frame(height: T.Space.s6)
        .focusable(enabled)
        .focused($focused)
        .onKeyPress(.leftArrow) { step(-1) }
        .onKeyPress(.rightArrow) { step(1) }
        .onKeyPress(.downArrow) { step(-1) }
        .onKeyPress(.upArrow) { step(1) }
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue(showLevel ? "\(volume)" : "unavailable")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityAdjustableAction { dir in
            _ = step(dir == .increment ? 1 : -1)
        }
    }

    /// Step size is 1 until MET-6 Q5 (`volumeStep`) is answered live.
    private func step(_ d: Int) -> KeyPress.Result {
        guard enabled else { return .ignored }
        set((volume + d).clamped(0, 100))
        return .handled
    }
}

extension Int { func clamped(_ a: Int, _ b: Int) -> Int { Swift.min(Swift.max(self, a), b) } }
