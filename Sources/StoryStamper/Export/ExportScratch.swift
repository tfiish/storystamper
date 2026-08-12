import Foundation

/// Everything an export writes before it is finished lives under one root, so
/// a cancel, a failure, a quit, or a crash can all be swept the same way—and
/// so a half-encoded file never appears at the destination the user picked.
enum ExportScratch {
    static let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoryStamper", isDirectory: true)

    /// A fresh directory for one export's overlay PNG and staged output.
    static func makeSession() throws -> URL {
        let session = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        return session
    }

    /// Synchronous, so it can run from `applicationWillTerminate` where there
    /// is no time left to await anything. Also run at launch, which clears
    /// debris left by a previous force quit or crash.
    static func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }
}
