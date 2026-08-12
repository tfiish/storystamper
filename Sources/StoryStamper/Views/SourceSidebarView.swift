import SwiftUI

/// Left sidebar: what is being stamped—the video, the words, and the preview
/// guides. Styling lives opposite in `StyleSidebarView`.
struct SourceSidebarView: View {
    @Bindable var project: StoryProject
    @State private var showingAbout = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                videoSection
                previewSection
            }
            .formStyle(.grouped)

            footer
        }
        .frame(width: Metrics.sidebarWidth)
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.medium) {
            Button("About") { showingAbout = true }
                .controlSize(.small)
            Text("\(AppInfo.displayName) v\(AppInfo.version)")
                .font(.appSmall)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.small)
        .padding(.bottom, Spacing.medium)
    }

    private var videoSection: some View {
        Section("Video") {
            if let video = project.video {
                LabeledContent("File") {
                    Text(video.filename)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .help(video.url.path)
                }
                LabeledContent("Size") {
                    Text("\(Int(video.displaySize.width)) × \(Int(video.displaySize.height))")
                }
                if video.nominalFrameRate > 0 {
                    LabeledContent("Frame rate") {
                        Text(String(format: "%.5g fps", video.nominalFrameRate))
                    }
                }
                Button("Replace Video…") {
                    chooseVideo(for: project)
                }
            } else {
                Text("No video loaded")
                    .foregroundStyle(.secondary)
                Button("Choose Video…") {
                    chooseVideo(for: project)
                }
            }
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            Toggle("Show story-safe areas", isOn: $project.showSafeArea)
            Text("Approximates where Instagram's UI covers a Story on the top and bottom.")
                .font(.appSmall)
                .foregroundStyle(.secondary)
        }
    }
}
