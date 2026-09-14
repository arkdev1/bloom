import SwiftUI
import BloomCore

/// A busy name: its own ink, with a band of lighter house blue passing through the glyphs.
///
/// One modifier for a tab's name and for the window title, so the two are the same figure and
/// cannot drift apart. It owns the text's ink, which is why a caller hands the ink in rather than
/// setting `foregroundStyle` itself: the band is the ink, a gradient of it, not something drawn
/// over it. An overlay masked to a copy of the text was the other way to draw it, and it leaves a
/// rim of the plain ink round every lit glyph, because both copies antialias the same edge pixels.
///
/// # What it costs, and what it does not
///
/// **Nothing, while the name is idle.** No timeline, no animation and no clock exist until a turn
/// starts; the band's `TimelineView` is built when it arrives and taken away the moment it has
/// finished fading out. A strip of ten idle tabs is ten plain `Text`s.
///
/// **While a name is busy, a SwiftUI frame thirty times a second**, and that is a real cost this
/// window has measured before. `ActivityRule` records a SwiftUI-driven rule at 2.96 seconds of CPU
/// every 15 on a 120Hz panel, against 0.13 for the same figure on Core Animation layers, because a
/// SwiftUI frame re-renders the hosting view's display list rather than the mark's. It is capped at
/// thirty rather than left at the display's rate for that reason (`BusyShimmer.frameRate` has the
/// arithmetic for why thirty looks continuous), and nothing in the band changes a size, so no
/// layout above the text is asked anything. Several busy tabs share those frames: they all read one
/// clock and redraw in the same pass.
///
/// The layer version, a `CAGradientLayer` moved by the render server, was not built, and not for
/// want of the argument above. It needs the glyphs as a mask, and a SwiftUI `Text` cannot be a
/// layer's mask: it would have to be rasterised through `ImageRenderer` at the text's measured
/// size, font and scale and kept in step with every rename, truncation and appearance change, and an
/// `NSViewRepresentable` in a tab has to survive the strip's drag lift, which scales the tab. None of
/// that could be seen working without putting a window in front of the owner. If the frames above
/// show up in a trace, that is the next thing to build.
///
/// # Starting, stopping and Reduce Motion
///
/// The band fades in and out over `BusyShimmer.fade` while it keeps moving, so a turn ending with the
/// light halfway through a word is a light going out rather than one that vanishes. A name that is
/// already busy when it appears is lit from its first frame. Under Reduce Motion there is no band and
/// no timeline: the ink leans towards the band's colour instead, for the reason `stillShare` gives.
struct BusyShimmerModifier: ViewModifier {
    var isActive: Bool
    var ink: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The band's fade, or nil when there is no band and so nothing ticking.
    @State private var fade: BusyShimmer.Fade?

    func body(content: Content) -> some View {
        styled(content)
            .onChange(of: isActive, initial: true) { was, active in
                let now = Date.now.timeIntervalSinceReferenceDate
                if was == active {
                    // The initial call. A name that appears busy is not a turn starting.
                    fade = active ? .present(at: now) : nil
                } else {
                    fade = .toward(isActive: active, from: fade, at: now)
                }
            }
            .task(id: fade) { await retire() }
    }

    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        if reduceMotion {
            content.foregroundStyle(isActive ? BusyShimmerStyle.still(ink: ink) : ink)
        } else if let fade {
            TimelineView(.animation(minimumInterval: 1 / BusyShimmer.frameRate)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                content.foregroundStyle(BusyShimmerStyle.band(
                    ink: ink, phase: BusyShimmer.phase(at: now), strength: fade.strength(at: now)
                ))
            }
        } else {
            content.foregroundStyle(ink)
        }
    }

    /// Takes the band, and its timeline, away once it has faded out.
    private func retire() async {
        guard let fade, fade.isLeaving else { return }
        let remaining = fade.endsAt - Date.now.timeIntervalSinceReferenceDate
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
        guard !Task.isCancelled, self.fade == fade else { return }
        self.fade = nil
    }
}

/// The two inks a busy name is drawn in, apart from the clock that moves one of them, so a gallery
/// can photograph a frame of the band without a timeline.
enum BusyShimmerStyle {
    /// The ink with the band at one point in its crossing, at a strength from 0 (plain) to 1.
    ///
    /// Unit points past 0 and 1 are the point: the gradient is three widths of the text long and
    /// slides across it, and a `LinearGradient` holds its end colours beyond its stops, which is the
    /// text's own ink on both sides of the band.
    @MainActor
    static func band(ink: Color, phase: Double, strength: Double) -> LinearGradient {
        let span = BusyShimmer.gradientSpan(atPhase: phase)
        let lit = ink.mix(with: Palette.busyShimmer, by: strength, in: .device)
        let centre = BusyShimmer.bandCentre
        let half = BusyShimmer.bandHalfWidth
        return LinearGradient(
            stops: [
                Gradient.Stop(color: ink, location: centre - half),
                Gradient.Stop(color: lit, location: centre),
                Gradient.Stop(color: ink, location: centre + half),
            ],
            startPoint: UnitPoint(x: span.lowerBound, y: 0.5),
            endPoint: UnitPoint(x: span.upperBound, y: 0.5)
        )
    }

    /// What Reduce Motion draws instead: the ink leaning towards the band's colour, and still.
    @MainActor
    static func still(ink: Color) -> Color {
        ink.mix(with: Palette.busyShimmer, by: BusyShimmer.stillShare, in: .device)
    }
}

extension View {
    /// Draws this text in `ink`, shimmering while `isActive`. See `BusyShimmerModifier`.
    func busyShimmer(_ isActive: Bool, ink: Color) -> some View {
        modifier(BusyShimmerModifier(isActive: isActive, ink: ink))
    }
}
