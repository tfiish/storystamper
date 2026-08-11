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
                .frame(minHeight: 72)
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

    private var styleSection: some View {
        Section("Text Style") {
            Picker("Font", selection: $project.selectedBlock.style.font) {
                ForEach(FontChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }

            LabeledContent("Size") {
                HStack(spacing: 8) {
                    Slider(value: $project.selectedBlock.style.fontSize, in: 24...160)
                    Text("\(Int(project.selectedBlock.style.fontSize))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 28, alignment: .trailing)
                }
            }

            Picker("Alignment", selection: $project.selectedBlock.style.alignment) {
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
            Picker("Style", selection: $project.selectedBlock.style.backgroundMode) {
                ForEach(BackgroundMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if project.selectedBlock.style.backgroundMode != .none {
                ColorPicker(
                    "Color",
                    selection: colorBinding(\.backgroundColor),
                    supportsOpacity: false
                )

                if project.selectedBlock.style.backgroundMode == .semiTransparent {
                    LabeledContent("Opacity") {
                        HStack(spacing: 8) {
                            Slider(value: $project.selectedBlock.style.backgroundOpacity, in: 0.1...0.9)
                            Text("\(Int(project.selectedBlock.style.backgroundOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }

                LabeledContent("Padding") {
                    HStack(spacing: 8) {
                        Slider(value: $project.selectedBlock.style.padding, in: 0...64)
                        Text("\(Int(project.selectedBlock.style.padding))")
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

            Text("Drag a text block on the preview to fine-tune. Position buttons move the selected block.")
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
            } else if project.placedOverlays.isEmpty {
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

    /// Bridges an RGBAColor property of the selected block's style to the
    /// Color value ColorPicker expects.
    private func colorBinding(_ keyPath: WritableKeyPath<OverlayStyle, RGBAColor>) -> Binding<Color> {
        Binding(
            get: { project.selectedBlock.style[keyPath: keyPath].color },
            set: { project.selectedBlock.style[keyPath: keyPath] = RGBAColor(color: $0) }
        )
    }
}
