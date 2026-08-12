import SwiftUI

/// Sheet shown while an export runs, and after it finishes or fails.
struct ExportStatusView: View {
    @Bindable var project: StoryProject
    /// Ticks once a second purely so the remaining-time estimate stays fresh
    /// between FFmpeg's progress updates.
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: Spacing.large) {
            switch project.exportPhase {
            case .idle:
                EmptyView()

            case .exporting(let progress):
                Text("Exporting Video")
                    .font(.appRegularBold)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: Metrics.progressWidth)
                    // FFmpeg reports about twice a second; interpolating
                    // between updates keeps the bar from stepping.
                    .animation(.linear(duration: 0.6), value: progress)

                Text(statusLine(progress: progress))
                    .font(.appSmallDigits)
                    .foregroundStyle(.secondary)

                Button("Cancel") {
                    project.cancelExport()
                }

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: IconSize.status))
                    .foregroundStyle(.green)
                Text("Export complete")
                    .font(.appRegularBold)
                HStack(spacing: Spacing.medium) {
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
                    .font(.system(size: IconSize.status))
                    .foregroundStyle(.orange)
                Text("Export failed")
                    .font(.appRegularBold)
                Text(message)
                    .font(.appRegular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Metrics.progressWidth)
                    .textSelection(.enabled)
                Button("Close") {
                    project.finishExport()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xLarge)
        .frame(minWidth: Metrics.sheetMinWidth)
        .onReceive(clock) { now = $0 }
    }

    /// Percentage plus a remaining-time estimate once there is enough data to
    /// make one honest. The tail of an export is the container rewrite for
    /// faststart, which reports no progress, so it gets its own label.
    private func statusLine(progress: Double) -> String {
        let percent = Int(progress * 100)
        guard progress < 0.995 else { return "Finishing up…" }
        guard let started = project.exportStartedAt, progress > 0.03 else {
            return "\(percent)%"
        }
        let elapsed = now.timeIntervalSince(started)
        guard elapsed > 1 else { return "\(percent)%" }
        let remaining = elapsed / progress - elapsed
        guard remaining.isFinite, remaining > 0 else { return "\(percent)%" }
        return "\(percent)% — about \(formatted(remaining)) remaining"
    }

    private func formatted(_ seconds: Double) -> String {
        if seconds < 10 { return "a few seconds" }
        if seconds < 90 { return "\(Int((seconds / 5).rounded()) * 5) seconds" }
        let minutes = Int((seconds / 60).rounded())
        return minutes == 1 ? "a minute" : "\(minutes) minutes"
    }
}
