import SwiftUI

/// Left sidebar: what is being stamped—the video, the words, and the preview
/// guides. Styling lives opposite in `StyleSidebarView`.
struct SourceSidebarView: View {
    @Bindable var project: StoryProject

    var body: some View {
        VStack(spacing: 0) {
            Form {
                videoSection
                textSection
                previewSection
            }
            .formStyle(.grouped)

            versionFooter
        }
        .frame(width: 300)
    }

    private var versionFooter: some View {
        HStack {
            Text("\(AppInfo.displayName) v\(AppInfo.version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    private var textSection: some View {
        Section("Story Text") {
            if project.blocks.count > 1 {
                Picker("Block", selection: $project.selectedIndex) {
                    ForEach(0..<project.blocks.count, id: \.self) { index in
                        Text("Block \(index + 1)").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            TextEditor(text: $project.selectedBlock.text)
                .font(.body)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)

            if project.canAddBlock {
                Button("Add Second Block") {
                    project.addBlock()
                }
            } else {
                Button("Remove This Block", role: .destructive) {
                    project.removeSelectedBlock()
                }
            }
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            Toggle("Show Story safe areas", isOn: $project.showSafeArea)
            Text("Approximates where Instagram's UI covers a Story. Never exported.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
