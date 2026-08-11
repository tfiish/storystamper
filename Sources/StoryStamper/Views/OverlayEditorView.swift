import SwiftUI

/// The right pane: video details, story text, style controls, placement, and
/// the export button.
struct OverlayEditorView: View {
    @Bindable var project: StoryProject

    var body: some View {
        VStack(spacing: 0) {
            Form {
                videoSection
                textSection
                styleSection
                backgroundSection
                positionSection
                previewSection
            }
            .formStyle(.grouped)

            exportFooter
        }
        .frame(width: 320)
    }

    // MARK: - Sections

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
            TextEditor(text: $project.storyText)
                .font(.body)
                .frame(minHeight: 72)
                .scrollContentBackground(.hidden)
        }
    }

    private var styleSection: some View {
        Section("Text Style") {
            Picker("Font", selection: $project.style.font) {
                ForEach(FontChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }

            LabeledContent("Size") {
                HStack(spacing: 8) {
                    Slider(value: $project.style.fontSize, in: 24...160)
                    Text("\(Int(project.style.fontSize))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 28, alignment: .trailing)
                }
            }

            Picker("Alignment", selection: $project.style.alignment) {
                ForEach(TextAlignmentChoice.allCases) { choice in
                    Image(systemName: choice.symbolName).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            ColorPicker(
                "Text Color",
                selection: colorBinding(\.textColor),
                supportsOpacity: false
            )
        }
    }

    private var backgroundSection: some View {
        Section("Background") {
            Picker("Style", selection: $project.style.backgroundMode) {
                ForEach(BackgroundMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if project.style.backgroundMode != .none {
                ColorPicker(
                    "Color",
                    selection: colorBinding(\.backgroundColor),
                    supportsOpacity: false
                )

                if project.style.backgroundMode == .semiTransparent {
                    LabeledContent("Opacity") {
                        HStack(spacing: 8) {
                            Slider(value: $project.style.backgroundOpacity, in: 0.1...0.9)
                            Text("\(Int(project.style.backgroundOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }

                LabeledContent("Padding") {
                    HStack(spacing: 8) {
                        Slider(value: $project.style.padding, in: 0...64)
                        Text("\(Int(project.style.padding))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var positionSection: some View {
        Section("Position") {
            HStack {
                Button("Top") { project.applyQuickPosition(.top) }
                Button("Center") { project.applyQuickPosition(.center) }
                Button("Bottom") { project.applyQuickPosition(.bottom) }
            }
            .frame(maxWidth: .infinity)
            .disabled(project.video == nil)

            Text("Drag the text on the preview to fine-tune.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private var exportFooter: some View {
        VStack(spacing: 6) {
            Button {
                project.beginExport()
            } label: {
                Text("Export Story Video")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!project.canExport)

            if project.video == nil {
                footerHint("Load a video to export.")
            } else if project.overlay == nil {
                footerHint("Enter story text to export.")
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func footerHint(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Bridges an RGBAColor property to the Color value ColorPicker expects.
    private func colorBinding(_ keyPath: WritableKeyPath<OverlayStyle, RGBAColor>) -> Binding<Color> {
        Binding(
            get: { project.style[keyPath: keyPath].color },
            set: { project.style[keyPath: keyPath] = RGBAColor(color: $0) }
        )
    }
}
