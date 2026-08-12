import AppKit
import SwiftUI

/// The menu bar. Everything the app can do has a menu item, which is what
/// makes those actions discoverable, keyboard-reachable, and visible to
/// assistive software—none of which a button in a sidebar gives you on its
/// own. SwiftUI supplies the standard Edit menu around these.
struct StoryCommands: Commands {
    @Bindable var project: StoryProject

    var body: some Commands {
        // The app menu's About opened the system panel while the sidebar
        // opened ours; now both open the same sheet.
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppInfo.displayName)") { project.infoSheet = .about }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings") { project.infoSheet = .settings }
                .keyboardShortcut(",", modifiers: .command)
        }

        // A one-window utility has no New, so Open takes its place.
        //
        // No trailing ellipsis, here or anywhere else. The platform
        // convention would put one on every command that opens a panel, and
        // this app deliberately does not: there are five of them, they are
        // the most-used commands in a utility with barely a dozen, and a
        // screen of trailing dots reads as noise rather than as a promise.
        CommandGroup(replacing: .newItem) {
            Button(project.video == nil ? "Open Video" : "Replace Video") {
                project.chooseVideo()
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(after: .newItem) {
            Divider()
            Button("Export Video") { project.beginExport() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!project.canExport)
        }

        CommandMenu("Text") {
            Button("Add Block") { project.addBlock() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!project.canAddBlock)

            // Not Command-Delete: that is delete-to-beginning-of-line in any
            // text view, and a menu key equivalent beats the responder chain,
            // so it would eat the shortcut while you were typing a caption.
            Button("Remove Block") { project.requestRemoveSelectedBlock() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(project.blocks.count < 2)

            // No shortcut, for the same reason: bare Delete does this on the
            // preview, where it can be had only while the preview has focus.
            Button("Clear Text") { project.clearSelectedText() }
                .disabled(!project.canClearText)

            Divider()

            ForEach(Array(project.blocks.enumerated()), id: \.element.id) { index, _ in
                Button("Select Block \(index + 1)") { project.selectedIndex = index }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }

        CommandMenu("Video") {
            // No shortcut: the space bar already does this from the transport
            // bar, where it can stand down while the text field has focus. A
            // menu key equivalent could not.
            Button(project.isPlaying ? "Pause" : "Play") { project.togglePlayback() }
                .disabled(project.video == nil)

            Divider()

            Button("Clear Video") { project.requestClearVideo() }
                .disabled(project.video == nil)
        }

        CommandGroup(after: .sidebar) {
            // Not Command-G, which is Find Next everywhere else on the system.
            Toggle("Area Guides", isOn: $project.showSafeArea)
                .keyboardShortcut("a", modifiers: [.command, .shift])

            Picker("Theme", selection: $project.appearance) {
                ForEach(AppearanceChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
        }

        CommandGroup(replacing: .help) {
            if let url = AppInfo.repositoryURL {
                Button("\(AppInfo.displayName) Help") { NSWorkspace.shared.open(url) }
            }
        }
    }
}
