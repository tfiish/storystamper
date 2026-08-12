import CoreGraphics
import Foundation

/// Persists presentation settings between launches. Story text and video
/// choice are intentionally not remembered.
enum SettingsStore {
    private static let styleKey = "overlayStyle.v1"
    private static let safeAreaKey = "showSafeArea.v1"
    private static let confirmDestructiveKey = "confirmDestructive.v1"
    private static let appearanceKey = "appearance.v1"
    private static let styleSidebarWidthKey = "styleSidebarWidth.v1"

    static func loadStyle() -> OverlayStyle {
        guard let data = UserDefaults.standard.data(forKey: styleKey),
              let style = try? JSONDecoder().decode(OverlayStyle.self, from: data) else {
            return OverlayStyle()
        }
        return style
    }

    static func save(_ style: OverlayStyle) {
        if let data = try? JSONEncoder().encode(style) {
            UserDefaults.standard.set(data, forKey: styleKey)
        }
    }

    static func loadShowSafeArea() -> Bool {
        UserDefaults.standard.object(forKey: safeAreaKey) as? Bool ?? true
    }

    static func save(showSafeArea: Bool) {
        UserDefaults.standard.set(showSafeArea, forKey: safeAreaKey)
    }

    /// Whether destructive actions ask first. Turned off by the "Don't ask me
    /// again" checkbox, and turned back on from Settings.
    static func loadConfirmDestructive() -> Bool {
        UserDefaults.standard.object(forKey: confirmDestructiveKey) as? Bool ?? true
    }

    static func save(confirmDestructive: Bool) {
        UserDefaults.standard.set(confirmDestructive, forKey: confirmDestructiveKey)
    }

    static func loadAppearance() -> AppearanceChoice {
        guard let raw = UserDefaults.standard.string(forKey: appearanceKey),
              let choice = AppearanceChoice(rawValue: raw) else { return .system }
        return choice
    }

    static func save(appearance: AppearanceChoice) {
        UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
    }

    /// Clamped on the way out as well as on the way in, so a width saved by a
    /// build with different bounds can never reopen out of range.
    static func loadStyleSidebarWidth() -> CGFloat {
        guard let stored = UserDefaults.standard.object(forKey: styleSidebarWidthKey) as? Double else {
            return Metrics.styleSidebarWidth
        }
        return min(max(CGFloat(stored), Metrics.minStyleSidebarWidth), Metrics.maxStyleSidebarWidth)
    }

    static func save(styleSidebarWidth: CGFloat) {
        UserDefaults.standard.set(Double(styleSidebarWidth), forKey: styleSidebarWidthKey)
    }
}
