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
    /// Kept alive here, because the window it guards holds its delegate
    /// weakly. Its presence also marks the guard as already installed.
    private var closeGuard: WindowCloseGuard?
    /// True once a confirmation has been given for the quit now underway, so
    /// the window closing and the app terminating do not ask twice.
    private var quitConfirmed = false

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

        // SwiftUI may not have built the window yet, so try now and again when
        // it first takes key. Whichever gets there first installs the guard.
        installCloseGuard()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// The Command-Q route. Command-W and the red button reach the same
    /// question earlier, through the close guard, and set `quitConfirmed` on
    /// the way past so it is not asked twice.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitConfirmed { return .terminateNow }
        return confirmQuit() ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        // A rename, not a delete: quitting must not wait on the file system.
        // The next launch clears what this leaves behind.
        ExportScratch.discard()
    }

    // MARK: - Quitting

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        installCloseGuard()
    }

    private func installCloseGuard() {
        guard closeGuard == nil,
              let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
        let installed = WindowCloseGuard(inFrontOf: window.delegate) { [weak self] in
            guard let self else { return true }
            guard confirmQuit() else { return false }
            // The window is about to go, and with it the app: remember that
            // the question has already been answered.
            quitConfirmed = true
            return true
        }
        closeGuard = installed
        window.delegate = installed
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    /// Asks before throwing away work in progress, and answers true when there
    /// is nothing to lose. Cancelling a running export is part of saying yes.
    private func confirmQuit() -> Bool {
        let project = StoryProject.shared

        if project.isExporting {
            guard confirm(
                title: "Quit while an export is running?",
                message: "The export will be canceled, and the partly encoded file discarded. Nothing will be written to the destination you chose.",
                confirmTitle: "Cancel Export and Quit"
            ) else {
                return false
            }
            project.cancelExport()
        } else if project.hasStoryText {
            // Gated on typed text, not on a loaded video. Unloading a video is
            // undoable and costs nothing to redo—and the app never remembers
            // which file was open anyway—so asking about one is a click spent
            // guarding something that was never kept. Text is the only thing
            // here that quitting actually destroys.
            return confirm(
                title: "Quit \(AppInfo.displayName)?",
                message: "Your story text will be discarded. Your font, colors, background, and padding are kept.",
                confirmTitle: "Quit"
            )
        }

        return true
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
}
