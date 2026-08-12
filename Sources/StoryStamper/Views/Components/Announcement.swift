import AppKit
import SwiftUI

/// Says something out loud once, when a view appears.
///
/// The app's two asynchronous outcomes—an export finishing, and anything
/// failing—arrive by swapping the contents of a sheet that is already on
/// screen. Nothing moves, nothing takes focus, and VoiceOver has no reason to
/// suspect that the thing it described a moment ago is now a different thing.
/// An announcement is the only way to say so.
///
/// Posted at `.high` priority because both outcomes end a wait the person
/// deliberately started, and one of them is an error.
private struct AnnouncementModifier: ViewModifier {
    let message: String

    func body(content: Content) -> some View {
        content.onAppear {
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: message,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
    }
}

extension View {
    /// Announces `message` to assistive software when this view appears.
    func announced(_ message: String) -> some View {
        modifier(AnnouncementModifier(message: message))
    }
}
