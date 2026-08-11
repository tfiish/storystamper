import SwiftUI

/// Sheet shown while an export runs, and after it finishes or fails.
struct ExportStatusView: View {
    @Bindable var project: StoryProject

    var body: some View {
        VStack(spacing: 16) {
            switch project.exportPhase {
            case .idle:
                EmptyView()

            case .exporting(let progress):
                Text("Exporting Story Video")
                    .font(.headline)
                ProgressView(value: progress)
                    .frame(width: 260)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Cancel") {
                    project.cancelExport()
                }

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text("Export complete")
                    .font(.headline)
                HStack(spacing: 12) {
                    Button("Reveal in Finder") {
                        project.revealExportInFinder()
                    }
                    Button("Done") {
                        project.finishExport()
                    }
                    .keyboardShortcut(.defaultAction)
                }

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("Export failed")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .textSelection(.enabled)
                Button("Close") {
                    project.finishExport()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 340)
    }
}
