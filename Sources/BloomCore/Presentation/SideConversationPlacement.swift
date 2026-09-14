import CoreGraphics

/// Where the side conversation card is drawn inside its chat pane, and where its tail meets it.
///
/// The card is dressed as a popover hanging off the side conversation button in the composer
/// footer, but it is an overlay in the pane rather than a real popover (`ChatPaneView` says why),
/// so nothing in the system positions it or points its arrow. That is a rectangle worked out by
/// hand, and the cases where it goes wrong are a pane dragged narrow or short, which is exactly
/// where nobody checks one by eye. So it is worked out here, where the suite can.
///
/// SwiftUI's coordinate space throughout: the origin is the pane's top leading corner and y grows
/// downwards. `frame` includes the tail, so a view can be sized and placed with it directly.
public struct SideConversationPlacement: Equatable, Sendable {
    /// The card, tail included, in the pane's space.
    public var frame: CGRect
    /// Where the tail's tip is, measured from the card's leading edge. Nil when there is no button
    /// to point at, and then the card has no tail and `frame` is the body alone.
    public var tailX: CGFloat?

    /// The largest the card gets. It shrinks to fit a smaller pane rather than overflowing it.
    public static let maximumSize = CGSize(width: 560, height: 520)
    /// What the card keeps from the pane's edges.
    public static let margin: CGFloat = 12
    /// The tail, which is about the size of the arrow a system popover on macOS 26 draws.
    public static let tailSize = CGSize(width: 20, height: 9)
    /// How much transcript has to be showing above the composer before the card sits above the
    /// composer rather than over it. Below this, keeping clear of the composer would leave a card
    /// too short to read, and covering the main composer is the smaller loss: the side
    /// conversation has a composer of its own.
    public static let roomyHeight: CGFloat = 360
    /// Between the tail's tip and the button, when the card has had to come down over the composer.
    static let buttonGap: CGFloat = 2
    /// Between the card and the composer when there is no button to hang off.
    static let composerGap: CGFloat = 8

    public init(frame: CGRect, tailX: CGFloat?) {
        self.frame = frame
        self.tailX = tailX
    }

    /// - Parameters:
    ///   - pane: The chat pane's size.
    ///   - anchor: The side conversation button's frame in the pane's space, or nil when the
    ///     footer is not showing it.
    ///   - clearance: What the floating composer takes off the bottom of the pane, margins
    ///     included. See `ComposerRoom`.
    ///   - cornerRadius: The card's corner radius, which the tail is kept clear of.
    public init(pane: CGSize, anchor: CGRect?, clearance: CGFloat, cornerRadius: CGFloat) {
        let width = max(0, min(Self.maximumSize.width, pane.width - 2 * Self.margin))
        let isRoomy = pane.height - clearance >= Self.roomyHeight

        guard let anchor else {
            // What the card did before it had a button to point at: bottom trailing, above the
            // composer when there is room for that. Kept for the frame where the footer has not
            // reported the button yet, so the card never has nowhere to be.
            let bottom = isRoomy ? clearance + Self.composerGap : Self.composerGap
            let height = max(0, min(Self.maximumSize.height, pane.height - bottom - Self.margin))
            self.init(
                frame: CGRect(
                    x: pane.width - Self.margin - width,
                    y: pane.height - bottom - height,
                    width: width,
                    height: height
                ),
                tailX: nil
            )
            return
        }

        // Where the tip is. Above the composer when there is room, so the main composer stays
        // visible and usable, with the tail pointing down the column the button is in; otherwise
        // just above the button itself, as a popover would be. Never below the button, which a
        // clearance not measured yet (nought, on the first pass) would otherwise put it.
        let aboveButton = anchor.minY - Self.buttonGap
        let tip = isRoomy ? min(pane.height - clearance, aboveButton) : aboveButton
        let bodyBottom = tip - Self.tailSize.height
        let bodyHeight = max(0, min(Self.maximumSize.height, bodyBottom - Self.margin))

        // Centred on the button, then pulled back inside the pane. The button is at the trailing
        // end of a footer, so on any pane narrower than about twice the card this clamp is what
        // decides where the card goes, and the tail below is what keeps it pointing at the button.
        let latest = max(Self.margin, pane.width - Self.margin - width)
        let x = min(max(anchor.midX - width / 2, Self.margin), latest)

        // The tail follows the button across the card, but stops short of the rounded corners: a
        // tail that starts inside a corner's curve leaves a notch in the outline.
        let inset = cornerRadius + Self.tailSize.width / 2
        let tailX = inset <= width - inset
            ? min(max(anchor.midX - x, inset), width - inset)
            : width / 2

        self.init(
            frame: CGRect(
                x: x,
                y: bodyBottom - bodyHeight,
                width: width,
                height: bodyHeight + Self.tailSize.height
            ),
            tailX: tailX
        )
    }
}
