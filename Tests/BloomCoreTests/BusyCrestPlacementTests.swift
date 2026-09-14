import Testing
@testable import BloomCore

/// The busy crest used to run along the strip's rule and vanished with the strip. These are the
/// two places it went instead, and the rule that it is only ever in one of them.
@Suite("Where the busy crest is drawn")
struct BusyCrestPlacementTests {
    private typealias Placement = BusyCrestPlacement<String>

    @Test("a lone tab with an agent running lights the column's top edge")
    func loneBusyTab() {
        let placement = Placement.resolve(
            isStripShown: false, tabs: ["chat"], selected: "chat", isRunning: { $0 == "chat" }
        )
        #expect(placement == .columnTop)
        #expect(placement.showsColumnTop)
        #expect(!placement.showsCrest(under: "chat"))
    }

    @Test("a lone idle tab lights nothing")
    func loneIdleTab() {
        let placement = Placement.resolve(
            isStripShown: false, tabs: ["chat"], selected: "chat", isRunning: { _ in false }
        )
        #expect(placement == .none)
    }

    /// The column shows one tab, so a turn running in a pane of that tab is running in what is on
    /// screen, even though the tab is filed under the other pane.
    @Test("with no strip, a turn in any pane of the visible tab counts")
    func splitWithNoStrip() {
        let placement = Placement.resolve(
            isStripShown: false, tabs: ["chat"], selected: "chat",
            panes: { $0 == "chat" ? ["chat", "second"] : [$0] },
            isRunning: { $0 == "second" }
        )
        #expect(placement == .columnTop)
    }

    @Test("a selection that has not resolved falls back to the only tab")
    func unresolvedSelection() {
        let placement = Placement.resolve(
            isStripShown: false, tabs: ["chat"], selected: nil, isRunning: { _ in true }
        )
        #expect(placement == .columnTop)
        #expect(Placement.resolve(
            isStripShown: false, tabs: ["a", "b"], selected: nil, isRunning: { _ in true }
        ) == .none)
        #expect(Placement.resolve(
            isStripShown: false, tabs: [], selected: nil, isRunning: { _ in true }
        ) == .none)
    }

    /// The whole reason for moving it: two busy tabs show two crests, and an idle tab shows none.
    @Test("with a strip, each busy tab gets its own crest and the top edge stays dark")
    func perTab() {
        let placement = Placement.resolve(
            isStripShown: true, tabs: ["a", "b", "c"], selected: "b",
            isRunning: { $0 != "b" }
        )
        #expect(placement == .tabs(["a", "c"]))
        #expect(!placement.showsColumnTop)
        #expect(placement.showsCrest(under: "a"))
        #expect(!placement.showsCrest(under: "b"))
        #expect(placement.showsCrest(under: "c"))
    }

    @Test("a split tab in the strip is busy when any of its panes is")
    func splitTabInStrip() {
        let placement = Placement.resolve(
            isStripShown: true, tabs: ["a", "b"], selected: "a",
            panes: { $0 == "a" ? ["a", "absorbed"] : [$0] },
            isRunning: { $0 == "absorbed" }
        )
        #expect(placement == .tabs(["a"]))
    }

    @Test("a strip with nothing running is none, never an empty set")
    func idleStrip() {
        let placement = Placement.resolve(
            isStripShown: true, tabs: ["a", "b"], selected: "a", isRunning: { _ in false }
        )
        #expect(placement == .none)
    }

    /// A rename keeps the strip up on a single tab. The crest follows the strip rather than the
    /// tab count, so it moves under the tab while the field is open and never shows twice.
    @Test("the strip decides, not the tab count")
    func followsTheStrip() {
        let shown = Placement.resolve(
            isStripShown: true, tabs: ["chat"], selected: "chat", isRunning: { _ in true }
        )
        #expect(shown == .tabs(["chat"]))
        #expect(!shown.showsColumnTop)
    }
}
