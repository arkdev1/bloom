import SwiftUI
import BloomCore

/// Where the centre column draws its busy crest: the decision is `BusyCrestPlacement`, and this is
/// the store feeding it what a tab holds and what is running.
///
/// Here rather than in the column or the strip, because both of them draw a half of the answer and
/// they must be handed the same one. The column asks once and passes the value to the strip, so the
/// top edge and a tab's slot can never light together while the strip appears or goes.
extension WorkspaceTabsStore {
    func busyCrest(
        in model: WorkspaceModel, entries: [PaneContent], selected: PaneContent?, isStripShown: Bool
    ) -> BusyCrestPlacement<PaneContent> {
        let tools = CenterTabStore.shared.tabs(for: model.workspace.id)
        return BusyCrestPlacement.resolve(
            isStripShown: isStripShown,
            tabs: entries,
            selected: selected,
            panes: { tab in layout(of: tab).panes.map { content(of: $0, in: tab) } },
            isRunning: { content in
                // Exactly what drove the tab's dot before the crest replaced it: a chat's agent
                // (including a CLI agent linked to it, and its subagents), and a run script's
                // command. A plain terminal is never polled and never counts.
                switch content {
                case .chat(let id):
                    model.sessions.first { $0.id == id }.map(model.isRunning) ?? false
                case .tool(let id):
                    tools.first { $0.id == id }.map(RunScriptLauncher.shared.isRunning) ?? false
                }
            }
        )
    }
}
