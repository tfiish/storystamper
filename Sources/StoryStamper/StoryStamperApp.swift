import AppKit
import SwiftUI

/// Entry point. A plain enum main so the binary can also run a headless smoke
/// export (see SmokeTest.swift) without launching the UI.
@main
enum StoryStamperMain {
    static func main() {
        if CommandLine.arguments.contains("--smoke-export") {
            SmokeTest.run(arguments: CommandLine.arguments)
        } else {
            StoryStamperApp.main()
        }
    }
}

struct StoryStamperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Bindable private var project = StoryProject.shared

    /// A single `Window` rather than a `WindowGroup`: this is a one-document
    /// utility, and a second window would fight the first over the shared
    /// style preferences.
    var body: some Scene {
        Window("Story Stamper", id: "main") {
            MainWindowView()
        }
        .defaultSize(width: Metrics.defaultWindowWidth, height: Metrics.defaultWindowHeight)
        .commands { StoryCommands(project: project) }
    }
}

/// When launched from `swift run` (a bare executable, not an .app bundle), the
/// process starts as a background app; promote it so the window fronts.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        StoryProject.shared.appearance.apply()
        // Debris from a previous crash or force quit can be gigabytes, so it
        // is cleared off the main thread. Nothing here waits on it, and a new
        // export creates its own session directory regardless.
        Task.detached(priority: .utility) {
            ExportScratch.sweep()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Quitting with work in progress asks first. Closing the window routes
    /// here too, because closing the last window terminates the app.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let project = StoryProject.shared

        if project.isExporting {
            guard confirm(
                title: "Quit while an export is running?",
                message: "The export will be cancelled, and the partly encoded file discarded. Nothing will be written to the destination you chose.",
                confirmTitle: "Cancel Export and Quit"
            ) else {
                restoreWindowIfClosed()
                return .terminateCancel
            }
            project.cancelExport()
        } else if project.video != nil {
            guard confirm(
                title: "Quit Story Stamper?",
                message: project.hasStoryText
                    ? "The loaded video and your story text will be discarded. Your font, colors, background, and padding are kept."
                    : "The loaded video will be discarded. Your font, colors, background, and padding are kept.",
                confirmTitle: "Quit"
            ) else {
                restoreWindowIfClosed()
                return .terminateCancel
            }
        }

        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // A rename, not a delete: quitting must not wait on the file system.
        // The next launch clears what this leaves behind.
        ExportScratch.discard()
    }

    private func confirm(title: String, message: String, confirmTitle: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Command-W closes the window before AppKit asks whether to terminate, so
    /// a declined quit would otherwise leave a running app with nothing on
    /// screen. Put the window back.
    private func restoreWindowIfClosed() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }), !window.isVisible else { return }
        window.makeKeyAndOrderFront(nil)
    }
}
