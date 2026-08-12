import Foundation

/// Where an export is in its lifecycle. Drives the export sheet.
enum ExportPhase: Equatable {
    case idle
    case exporting(progress: Double)
    case completed(URL)
    case failed(String)
}
