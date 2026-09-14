import Foundation

/// The figure a busy name is drawn with: a soft band of lighter house blue passing through the
/// glyphs from the leading edge to the trailing one, over and over.
///
/// It replaced a crest drawn under each busy tab and along the column's top edge, which the owner
/// reported did not read as part of the tab and read as a hard blue line without one. The name is
/// what says which tab is working, so the name is what moves now. See `BusySignalPlacement` for
/// where it is drawn and `BusyShimmerModifier` for how.
///
/// Every number here is the owner's chosen mockup, restated so it can be tested: a gradient three
/// times the text's width, the text's own ink from 0 to 40 per cent and from 60 to 100, the lit
/// colour at 50, slid from fully before the text to fully past it in 2.4 seconds, linearly.
public enum BusyShimmer {
    /// One crossing.
    ///
    /// **Not on the window's heartbeat, and knowingly.** `BusyPulse` keeps its marks in whole
    /// multiples of `BusyDot.period`, 1.5 seconds, so they close on one frame. 2.4 is the mockup's
    /// number and the one the owner chose by looking at it. The shimmers keep step with each other,
    /// which is the property that matters on a strip (see `phase(at:)`); they do not keep step with
    /// the sidebar's dots, which are in a different column.
    public static let period: TimeInterval = 2.4

    /// How long the gradient is, in widths of the text it fills.
    public static let span = 3.0
    /// Where along the gradient the lit colour peaks.
    public static let bandCentre = 0.5
    /// From the peak to where the text's own ink takes over again, along the gradient.
    public static let bandHalfWidth = 0.1

    /// How often the band is redrawn while it moves.
    ///
    /// **Thirty, not the display's rate, because this band is driven by SwiftUI and not by Core
    /// Animation**, and a SwiftUI frame is a main thread wake that re-renders the hosting view's
    /// display list. `ActivityRule` records what that cost at 120Hz. The band is soft enough to
    /// take it: each frame moves it `stepShareOfRamp` of the distance its edge fades over, under a
    /// tenth whatever the text's width, because the band's size and its travel both scale with that
    /// width. A step a tenth of a gradient ramp is not a step anybody can see.
    public static let frameRate = 30.0

    /// How long the band takes to arrive and to leave.
    ///
    /// A turn ends at any moment, including with the band halfway through a word, and a light that
    /// vanishes between two frames is a pop. A band fading out while it keeps moving is a signal
    /// going out. Long enough to read as a fade, short enough not to claim work that has stopped.
    public static let fade: TimeInterval = 0.4

    /// How far a busy name's ink leans towards the lit colour when Reduce Motion is on.
    ///
    /// Tinted rather than plain, because the tab's pulsing dot is gone and the shimmer was the only
    /// thing left saying a tab is busy: plain text would leave a sighted reader who asked for less
    /// motion with no signal at all, and the accessibility value only reaches VoiceOver. Four
    /// tenths is a lean a glance notices, and `PaletteContrastTests` holds it to the text floor.
    public static let stillShare = 0.4

    /// Where in its crossing the band is at an instant, from 0 to 1.
    ///
    /// Taken from an absolute clock rather than from when a view appeared, so every busy name in the
    /// window is at the same point in its crossing, and a tab rebuilt mid drag or a strip that
    /// arrives mid turn lands in stride rather than starting its band over.
    public static func phase(at time: TimeInterval) -> Double {
        let fraction = time.truncatingRemainder(dividingBy: period) / period
        return fraction < 0 ? fraction + 1 : fraction
    }

    /// Where the gradient starts and ends at a phase, in widths of the text from its leading edge.
    ///
    /// The mockup's `background-position` running from 100 per cent to 0 on a background three
    /// widths long, written as the two ends a `LinearGradient` is given: the start slides from two
    /// widths before the text to the text's leading edge.
    public static func gradientSpan(atPhase phase: Double) -> ClosedRange<Double> {
        let start = -(span - 1) * (1 - phase)
        return start...(start + span)
    }

    /// Where the lit colour peaks at a phase, in widths of the text from its leading edge.
    public static func bandCentre(atPhase phase: Double) -> Double {
        gradientSpan(atPhase: phase).lowerBound + bandCentre * span
    }

    /// How far the band's edge fades over, in widths of the text.
    public static var rampWidth: Double { bandHalfWidth * span }

    /// How much of `rampWidth` the band moves in one frame at `frameRate`.
    public static var stepShareOfRamp: Double {
        (span - 1) / period / frameRate / rampWidth
    }

    // MARK: Arriving and leaving

    /// How strongly the band is drawn, moving from one strength to another from an instant on.
    ///
    /// Reversible from anywhere: a turn that ends while its band is still arriving leaves from the
    /// strength it had reached, rather than jumping to full and fading from there.
    public struct Fade: Equatable, Sendable {
        public let from: Double
        public let to: Double
        public let startedAt: TimeInterval

        public init(from: Double, to: Double, startedAt: TimeInterval) {
            self.from = from
            self.to = to
            self.startedAt = startedAt
        }

        /// A band that was already there when the view appeared, at full strength from the start.
        ///
        /// A tab that comes into a strip mid turn is not a turn starting, so it does not fade in.
        public static func present(at time: TimeInterval) -> Fade {
            Fade(from: 1, to: 1, startedAt: time)
        }

        /// The fade that begins when work starts or stops, from wherever `current` had got to.
        public static func toward(isActive: Bool, from current: Fade?, at time: TimeInterval) -> Fade {
            Fade(from: current?.strength(at: time) ?? 0, to: isActive ? 1 : 0, startedAt: time)
        }

        public func strength(at time: TimeInterval) -> Double {
            let progress = min(max((time - startedAt) / BusyShimmer.fade, 0), 1)
            return from + (to - from) * progress
        }

        /// When nothing is left to draw and the band, and its clock, can be taken away.
        public var endsAt: TimeInterval { startedAt + BusyShimmer.fade }

        public var isLeaving: Bool { to == 0 }
    }
}
