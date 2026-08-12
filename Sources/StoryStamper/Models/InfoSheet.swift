import Foundation

/// The two informational sheets, in one slot. They share a slot because two
/// `.sheet(isPresented:)` modifiers on one view contend for the same
/// presentation, and they live on the project because both the sidebar footer
/// and the menu bar open them.
enum InfoSheet: String, Identifiable {
    case about
    case settings

    var id: String { rawValue }
}
