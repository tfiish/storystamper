import SwiftUI

/// Left sidebar: what is being stamped—the video, and how the app presents
/// itself while you work. Styling lives opposite in `StyleSidebarView`.
struct SourceSidebarView: View {
    @Bindable var project: StoryProject

    var body: some View {
        VStack(spacing: 0) {
            Form {
                videoSection
                previewSection
                themeSection
            }
            .formStyle(.grouped)

            footer
        }
        .frame(width: Metrics.sourceSidebarWidth)
        .sheet(item: $project.infoSheet) { sheet in
            switch sheet {
            case .about: AboutView()
            case .settings: SettingsView(project: project)
            }
        }
    }

    private var footer: some View {
        BarStrip {
            VStack(spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    Button("Settings") { project.infoSheet = .settings }
                        .controlSize(.small)
                    Button("About") { project.infoSheet = .about }
                        .controlSize(.small)
                }
                Text("\(AppInfo.displayName) v\(AppInfo.version)")
                    .font(.appSmall)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var videoSection: some View {
        Section("Video") {
            if let video = project.video {
                // Stacked rather than label-and-value rows, because at this
                // width a two-column row would truncate both halves.
                VStack(alignment: .leading, spacing: Spacing.hair) {
                    Text(video.filename)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .help(video.url.path)
                    Text(summary(for: video))
                        .font(.appSmall)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Replace Video") {
                    project.chooseVideo()
                }
            } else {
                // No button here: the drop prompt filling the pane alongside
                // this already carries the call to action, and two differently
                // styled Choose Video buttons on screen at once read as two
                // different things.
                Text("No video loaded")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Dimensions, length, and frame rate on one line—the three things worth
    /// glancing at, in the order you would ask for them.
    private func summary(for video: VideoInfo) -> String {
        var parts = [
            "\(Int(video.displaySize.width)) × \(Int(video.displaySize.height))",
            video.durationText,
        ]
        if video.nominalFrameRate > 0 {
            parts.append(String(format: "%.5g fps", video.nominalFrameRate))
        }
        return parts.joined(separator: " · ")
    }

    private var previewSection: some View {
        Section("Preview") {
            Toggle("Area Guides", isOn: $project.showSafeArea)
            Text("Shows approximately where Instagram's UI covers the top and bottom of a story.")
                .font(.appSmall)
                .foregroundStyle(.secondary)
        }
    }

    /// Its own section, not a row under Preview: this changes the whole app,
    /// including the open, save, and color panels, rather than anything about
    /// the preview.
    private var themeSection: some View {
        Section("Theme") {
            GlyphPicker(
                title: "Theme",
                selection: $project.appearance,
                items: AppearanceChoice.allCases,
                name: { $0.displayName }
            ) { choice in
                Image(systemName: choice.symbolName)
            }
        }
    }
}
