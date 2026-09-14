import Foundation

/// Where the busy crest is drawn in a column of tabs: nowhere, along the column's top edge, or
/// under particular tabs.
///
/// # Why it moved off the strip's rule
///
/// The crest used to light the rule that closes off the tab strip, full width, whenever the
/// workspace had a turn running. Two things broke that. The strip stopped being drawn for a lone
/// tab (`TabStripVisibility`), and the rule went with it, so the most common window, one
/// conversation, showed no busy signal at all. And with several tabs, one line across all of them
/// could say that something was working but never which.
///
/// So there are two places, and never both. **No strip**: the crest runs along the top of the
/// column, where the strip's rule used to be. **A strip**: each busy tab gets a short crest of its
/// own along the bottom of its slot, and nothing runs full width. The single answer is what stops
/// the two overlapping while the strip appears or goes: the column asks this once and hands the
/// same value to the strip.
///
/// # What counts as busy
///
/// A tab is busy when anything in any of its panes is running, not only the content it is filed
/// under. A split tab is one entry in the strip standing for every pane in it, and a turn running
/// in its second pane is running in that tab; marking only the root would leave a working split
/// looking idle. With no strip that is the visible tab, which is the only tab there is.
///
/// What "running" means for one content is the caller's, and it is exactly what the tab's dot used
/// to be driven by: a chat's agent mid turn (including a CLI agent linked to it in a terminal, and
/// its subagents), and a run script's command. A plain terminal never counts; nothing polls it.
public enum BusyCrestPlacement<Tab: Hashable & Sendable>: Equatable, Sendable {
    /// Nothing is running, or nothing is showing.
    case none
    /// The column's top edge, full width.
    case columnTop
    /// One crest under each of these tabs. Never empty; an empty set is `none`.
    case tabs(Set<Tab>)

    /// - Parameters:
    ///   - isStripShown: whether the column draws its strip, which is `TabStripVisibility`'s.
    ///   - tabs: the strip's entries, in any order.
    ///   - selected: the tab the column is showing.
    ///   - panes: what each pane of a tab shows. A tab nobody split is one pane showing itself.
    ///   - isRunning: whether one content is running.
    public static func resolve(
        isStripShown: Bool,
        tabs: [Tab],
        selected: Tab?,
        panes: (Tab) -> [Tab] = { [$0] },
        isRunning: (Tab) -> Bool
    ) -> Self {
        func isBusy(_ tab: Tab) -> Bool {
            panes(tab).contains(where: isRunning)
        }

        guard isStripShown else {
            // The visible tab, falling back to the only one when the selection has not resolved
            // yet. More than one tab with no strip is a state `TabStripVisibility` never answers,
            // and guessing which of them is on screen would light the edge for the wrong one.
            let visible = selected.flatMap { tabs.contains($0) ? $0 : nil }
                ?? (tabs.count == 1 ? tabs.first : nil)
            guard let visible, isBusy(visible) else { return .none }
            return .columnTop
        }

        let busy = Set(tabs.filter(isBusy))
        return busy.isEmpty ? .none : .tabs(busy)
    }

    /// Whether the column's top edge carries the crest.
    public var showsColumnTop: Bool {
        self == .columnTop
    }

    /// Whether this tab's slot carries a crest.
    public func showsCrest(under tab: Tab) -> Bool {
        guard case .tabs(let busy) = self else { return false }
        return busy.contains(tab)
    }
}
