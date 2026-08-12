import Foundation

enum AppInfo {
    /// Shown in the sidebar footer. Read from the bundle when running as an
    /// installed app; `swift run` produces a bare executable with no
    /// Info.plist, so keep `developmentVersion` in step with Support/Info.plist.
    static let displayName = "Story Stamper"
    static let developmentVersion = "1.3.0"

    static var version: String {
        let bundled = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return bundled ?? developmentVersion
    }
}
