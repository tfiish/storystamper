import Foundation

/// Where an export is in its lifecycle. Drives the export sheet.
///
/// There is no failure case: a failed export is a `StoryFailure` like any
/// other, so the app has one error type rather than one per subsystem.
enum ExportPhase: Equatable {
    case idle
    case exporting(progress: Double)
    case completed(URL)
}
