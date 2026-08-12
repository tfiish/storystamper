import Foundation

/// Everything an export writes before it is finished lives under one root, so
/// a cancel, a failure, a quit, or a crash can all be swept the same way—and
/// so a half-encoded file never appears at the destination the user picked.
///
/// Sweeping is deliberately never on the critical path. A killed 4K export can
/// leave gigabytes here, and deleting that much on the main thread at launch
/// or at quit is exactly the kind of stall rule zero exists to prevent. So
/// quitting only *renames* the root, which is instant, and the next launch
/// deletes the leftovers in the background.
enum ExportScratch {
    private static let directoryName = "StoryStamper"
    private static let orphanPrefix = "StoryStamper-orphan-"

    static let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(directoryName, isDirectory: true)

    /// A fresh directory for one export's overlay PNG and staged output.
    static func makeSession() throws -> URL {
        let session = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        return session
    }

    /// Renames the root out of the way. A rename within one volume is a
    /// constant-time metadata change however much is inside, which is what
    /// makes it safe to call while the app is quitting.
    static func discard() {
        let manager = FileManager.default
        guard manager.fileExists(atPath: root.path) else { return }
        let orphan = manager.temporaryDirectory
            .appendingPathComponent(orphanPrefix + UUID().uuidString, isDirectory: true)
        try? manager.moveItem(at: root, to: orphan)
    }

    /// Deletes the root and anything `discard()` renamed aside, including
    /// debris from a previous crash. Call this off the main thread at launch;
    /// nothing waits on it.
    static func sweep() {
        let manager = FileManager.default
        try? manager.removeItem(at: root)

        let temp = manager.temporaryDirectory
        let contents = (try? manager.contentsOfDirectory(atPath: temp.path)) ?? []
        for name in contents where name.hasPrefix(orphanPrefix) {
            try? manager.removeItem(at: temp.appendingPathComponent(name, isDirectory: true))
        }
    }
}
