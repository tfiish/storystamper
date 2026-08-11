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

    var body: some Scene {
        WindowGroup("Story Stamper") {
            ContentView()
        }
        .defaultSize(width: 1080, height: 720)
    }
}

/// When launched from `swift run` (a bare executable, not an .app bundle), the
/// process starts as a background app; promote it so the window fronts.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
