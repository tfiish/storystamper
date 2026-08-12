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
            Button("About Story Stamper") { project.infoSheet = .about }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings") { project.infoSheet = .settings }
                .keyboardShortcut(",", modifiers: .command)
        }

        // A one-window utility has no New, so Open takes its place.
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
            Button("Add Text Block") { project.addBlock() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!project.canAddBlock)

            Button("Remove Text Block") { project.requestRemoveSelectedBlock() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(project.blocks.count < 2)

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

            Button("Unload Video") { project.requestClearVideo() }
                .disabled(project.video == nil)
        }

        CommandGroup(after: .sidebar) {
            Toggle("Area Guides", isOn: $project.showSafeArea)
                .keyboardShortcut("g", modifiers: .command)

            Picker("Theme", selection: $project.appearance) {
                ForEach(AppearanceChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
        }

        CommandGroup(replacing: .help) {
            if let url = AppInfo.repositoryURL {
                Button("Story Stamper Help") { NSWorkspace.shared.open(url) }
            }
        }
    }
}
