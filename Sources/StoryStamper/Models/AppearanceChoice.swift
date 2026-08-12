import AppKit

/// Light, dark, or whatever the system is doing. Applied to `NSApp` rather
/// than through SwiftUI's `preferredColorScheme` so it reaches the open and
/// save panels, the color panel, and the menu bar too—not just our own views.
enum AppearanceChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var help: String {
        switch self {
        case .system: return "Follow the system appearance"
        case .light: return "Always use the light appearance"
        case .dark: return "Always use the dark appearance"
        }
    }

    private var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    func apply() {
        NSApplication.shared.appearance = nsAppearance
    }
}
