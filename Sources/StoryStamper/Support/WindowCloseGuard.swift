import AppKit

/// Lets the app veto a window closing.
///
/// Closing the last window terminates this app, so Command-W and the red
/// button are quit requests—but AppKit closes the window first and asks
/// `applicationShouldTerminate` afterwards, so a declined quit used to leave a
/// running app with nothing on screen. `windowShouldClose` runs *before* the
/// close, and it is the only hook that can call it off.
///
/// SwiftUI owns the window's delegate and uses it, so this does not replace
/// it: it stands in front, answers the one message it cares about, and passes
/// everything else through by ObjC forwarding.
@MainActor
final class WindowCloseGuard: NSObject, NSWindowDelegate {
    /// Read from `responds(to:)` and `forwardingTarget(for:)`, which the ObjC
    /// runtime may ask about from anywhere and which therefore cannot hop to
    /// the main actor. Written once, on the main actor, at construction.
    nonisolated(unsafe) private weak var next: NSWindowDelegate?
    private let shouldClose: () -> Bool

    /// A window holds its delegate weakly, so whoever installs the guard has
    /// to keep it alive.
    init(inFrontOf next: NSWindowDelegate?, shouldClose: @escaping () -> Bool) {
        self.next = next
        self.shouldClose = shouldClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        shouldClose()
    }

    // MARK: - Pass-through

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || next?.responds(to: aSelector) == true
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        next
    }
}
