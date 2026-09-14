import AppKit
import SwiftUI
import UniformTypeIdentifiers
import BloomCore

/// The applications the user has added to the "Open in" menus, and the button that adds one.
///
/// This pane exists for the application the catalogue does not list. Every editor, terminal and
/// git client in `EditorCatalog` is already offered the moment it is installed, and none of those
/// need a row here. What had no way in was the git client Bloom had not heard of: the system's own
/// contribution to the menu is the default handler for a file type, and a folder's default handler
/// is Finder, so nothing a user chose could ever reach "Open Worktree in". See `OpenInCustomApps`,
/// which holds the list, and `EditorCatalog.catalogue(adding:)`, which merges it.
///
/// Each row carries a picker for what the application is offered, because that is the one thing
/// a bundle cannot tell us. A git client handed a single file has nothing to do with it, which is
/// the ambiguity `OpenInTarget` exists to avoid, and a wrong guess here would put the application
/// in exactly the menu where clicking it does nothing.
struct OpenInSettingsSection: View {
    @State private var apps = OpenInCustomApps().apps
    @State private var refusal: String?

    var body: some View {
        Section("Open in") {
            ForEach(apps) { app in
                row(app)
            }

            Button("Add Application…") {
                Task { await add() }
            }

            if let refusal {
                Text(refusal).foregroundStyle(Palette.negative)
            }

            Text(
                "Every editor, terminal and git client Bloom knows is already offered once it is installed. "
                + "Add one Bloom does not know and it joins every Open in menu, including Open Worktree in."
            )
            .settingsFootnote()
        }
    }

    private func row(_ app: ExternalApp) -> some View {
        // Located afresh for each draw rather than through `InstalledApps`, which only holds what
        // it could find: an application that was added and since uninstalled still has a row here,
        // and the row is where the user finds out why it is not in the menu.
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
        return HStack(spacing: Metrics.gutter) {
            if let url {
                Image(nsImage: icon(at: url))
            } else {
                Image(systemName: "app.dashed")
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(app.name)
                if url == nil {
                    Text("Not installed").settingsFootnote()
                }
            }
            .lineLimit(1)
            Spacer()
            Picker("Offered for", selection: targets(of: app)) {
                Text("Files and folders").tag(OpenTargets.both)
                Text("Folders only").tag(OpenTargets.folder)
            }
            .labelsHidden()
            .fixedSize()
            Button("Remove") { remove(app) }
        }
    }

    private func targets(of app: ExternalApp) -> Binding<OpenTargets> {
        Binding(
            get: { app.targets },
            set: { targets in
                OpenInCustomApps().setTargets(targets, forBundleID: app.bundleID)
                reload()
            }
        )
    }

    private func add() async {
        refusal = nil
        guard let url = await ApplicationPicker.choose() else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            refusal = "\(url.lastPathComponent) has no bundle identifier, so Bloom cannot open anything with it."
            return
        }
        // Both by default, which is right for an editor and wrong for a git client, and the row's
        // picker is one click either way. The alternative, folders only, would hide a newly added
        // editor from every file's menu, which is the more surprising of the two mistakes.
        let app = ExternalApp(
            bundleID: bundleID,
            name: InstalledApps.name(of: url),
            targets: .both,
            fileName: url.lastPathComponent
        )
        switch OpenInCustomApps().add(app) {
        case .alreadyInCatalogue(let name):
            refusal = "\(name) is already offered in every Open in menu when it is installed."
        case .alreadyAdded:
            refusal = "\(app.name) has already been added."
        case nil:
            break
        }
        reload()
    }

    private func remove(_ app: ExternalApp) {
        refusal = nil
        OpenInCustomApps().remove(bundleID: app.bundleID)
        reload()
    }

    /// Reads the list back and forgets the menu's cache, so the next menu opened shows the change
    /// rather than the list from up to a minute ago. See `InstalledApps.invalidate`.
    private func reload() {
        apps = OpenInCustomApps().apps
        InstalledApps.invalidate()
    }

    /// Sized for the reason `InstalledApps.icon(at:)` gives: an application icon says it is 512
    /// points, and SwiftUI believes it.
    private func icon(at url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let sized = icon.copy() as? NSImage ?? icon
        sized.size = NSSize(width: 16, height: 16)
        return sized
    }
}

/// Asking the user for an application bundle. Wrapped for the reason `ProjectFolderPicker` is:
/// one place decides how the panel is configured.
@MainActor
enum ApplicationPicker {
    /// A sheet rather than an application-modal panel, for the reason `NSSavePanel.present`
    /// gives: `runModal()` would stop every other workspace's transcript from streaming for as
    /// long as the picker is open.
    static func choose() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // A bundle is a folder to the file system and a file to the panel, and it is the panel's
        // reading that lets one be picked whole rather than descended into.
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = "Add"
        panel.message = "Choose an application to offer in the Open in menus."
        guard await panel.present() == .OK, let url = panel.url else { return nil }
        return url
    }
}
