import SwiftUI

/// Sheet shown while an export runs, and after it finishes. A failed export
/// leaves this view entirely and comes back as a `FailureSheet`, so there is
/// one place errors are presented rather than one per subsystem.
struct ExportStatusView: View {
    @Bindable var project: StoryProject

    var body: some View {
        VStack(spacing: Spacing.large) {
            switch project.exportPhase {
            case .idle:
                EmptyView()

            case .exporting(let progress):
                // Split out so its once-a-second clock exists only while an
                // export is running, rather than ticking through the finished
                // and failed states where nothing reads it.
                ExportProgressView(project: project, progress: progress)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: IconSize.status))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Export Complete")
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
            }
        }
        .padding(Spacing.xLarge)
        .frame(minWidth: Metrics.sheetMinWidth)
    }
}

/// The running half of the export sheet. Owns the clock, so the clock lives
/// exactly as long as the progress readout that depends on it.
private struct ExportProgressView: View {
    @Bindable var project: StoryProject
    let progress: Double

    /// Ticks once a second purely so the remaining-time estimate stays fresh
    /// between FFmpeg's progress updates.
    @State private var now = Date()
    private let clock = Timer.publish(every: Motion.clock, on: .main, in: .common).autoconnect()

    var body: some View {
        // A VStack rather than a Group, because modifiers on a Group are
        // applied to each child—`onReceive` there would open four
        // subscriptions to the same clock instead of one.
        VStack(spacing: Spacing.large) {
            Text("Exporting Video")
                .font(.appRegularBold)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: Metrics.progressWidth)
                // FFmpeg reports about twice a second; interpolating between
                // updates keeps the bar from stepping.
                .animation(.linear(duration: Motion.progress), value: progress)

            Text(statusLine)
                .font(.appSmallDigits)
                .foregroundStyle(.secondary)

            Button("Cancel") {
                project.cancelExport()
            }
            .keyboardShortcut(.cancelAction)
        }
        .onReceive(clock) { now = $0 }
    }

    /// Percentage plus a remaining-time estimate once there is enough data to
    /// make one honest. The tail of an export is the container rewrite for
    /// faststart, which reports no progress, so it gets its own label.
    private var statusLine: String {
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
        // Buckets stop at 55 so the step above them is always "a minute"
        // rather than "60 seconds", and the label never leaps a granularity:
        // the old boundary turned an extra tenth of a second at 89.9s into
        // "90 seconds" and then "2 minutes".
        if seconds < 60 { return "\(min(Int((seconds / 5).rounded()) * 5, 55)) seconds" }
        if seconds < 90 { return "a minute" }
        return "\(Int((seconds / 60).rounded())) minutes"
    }
}
