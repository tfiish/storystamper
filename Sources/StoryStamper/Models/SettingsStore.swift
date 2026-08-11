import Foundation

/// Persists presentation settings between launches. Story text and video
/// choice are intentionally not remembered.
enum SettingsStore {
    private static let styleKey = "overlayStyle.v1"
    private static let safeAreaKey = "showSafeArea.v1"

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
}
