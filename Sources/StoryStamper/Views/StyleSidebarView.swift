import SwiftUI

/// Right sidebar: how the text looks and where it sits, plus the export
/// action. All controls edit the selected block.
struct StyleSidebarView: View {
    @Bindable var project: StoryProject
    @FocusState private var textEditorFocused: Bool
    @FocusState private var paddingHintFocused: Bool

    /// Roughly what Instagram puts around Story text, in the same 1080-wide
    /// reference units the padding slider uses.
    private static let instagramPadding: Double = 20

    var body: some View {
        VStack(spacing: 0) {
            Form {
                textSection
                styleSection
                backgroundSection
            }
            .formStyle(.grouped)
            // Nothing in here means anything without a video: a block is
            // placed against the video's frame, and no overlay renders until
            // one is loaded. Better to grey the lot than to let someone style
            // an overlay that does not exist.
            .disabled(project.video == nil)

            exportFooter
        }
        .frame(width: project.styleSidebarWidth)
        // The transport bar gives up the space bar while this is true, so a
        // space typed into the story text stays a space.
        .onChange(of: textEditorFocused) { _, focused in
            project.isEditingText = focused
        }
    }

    private var textSection: some View {
        Section("Story Text") {
            if project.blocks.count > 1 {
                Picker("Block", selection: $project.selectedIndex) {
                    ForEach(Array(project.blocks.enumerated()), id: \.element.id) { index, _ in
                        Text("Block \(index + 1)").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            TextEditor(text: $project.selectedBlock.text)
                .font(.appRegular)
                .frame(minHeight: Metrics.textEditorMinHeight)
                .scrollContentBackground(.hidden)
                .focused($textEditorFocused)
                .accessibilityLabel("Story text")

            HStack {
                Button("Add Text Block") {
                    project.addBlock()
                }
                .disabled(!project.canAddBlock)

                Button("Remove", role: .destructive) {
                    project.requestRemoveSelectedBlock()
                }
                .disabled(project.blocks.count < 2)
            }

            Text("Drag or use arrow keys to reposition. Blocks snap to the midlines.")
                .font(.appSmall)
                .foregroundStyle(.secondary)
        }
    }

    private var styleSection: some View {
        Section("Text Style") {
            LabeledContent("Font") {
                GlyphPicker(
                    title: "Font",
                    selection: $project.selectedBlock.style.font,
                    items: FontChoice.allCases,
                    name: { $0.displayName }
                ) { choice in
                    FontSample.image(for: choice)
                }
            }

            SliderRow(
                title: "Size",
                value: $project.selectedBlock.style.fontSize,
                range: 24...160,
                format: { "\(Int($0))" },
                spokenName: "Text size"
            )

            LabeledContent("Alignment") {
                GlyphPicker(
                    title: "Alignment",
                    selection: $project.selectedBlock.style.alignment,
                    items: TextAlignmentChoice.allCases,
                    name: { $0.displayName }
                ) { choice in
                    Image(systemName: choice.symbolName)
                }
            }

            LabeledContent("Color") {
                ColorRow(presets: ColorPreset.text, selection: styleBinding(\.textColor))
            }

            Text("Style changes apply only to the selected Text Block.")
                .font(.appSmall)
                .foregroundStyle(.secondary)
        }
    }

    private var backgroundSection: some View {
        let enabled = project.selectedBlock.style.backgroundEnabled
        return Section {
            // Grouped so unchecking dims only the controls, never the header
            // checkbox that turns them back on. Rows stay visible at a fixed
            // height rather than collapsing.
            Group {
                LabeledContent("Color") {
                    ColorRow(presets: ColorPreset.background, selection: styleBinding(\.backgroundColor))
                }

                SliderRow(
                    title: "Opacity",
                    value: $project.selectedBlock.style.backgroundOpacity,
                    range: 0.1...1,
                    format: { "\(Int($0 * 100))%" },
                    spokenName: "Background opacity",
                    // The slider stops at 10% so "enabled" always means
                    // visible; removing the box entirely is the checkbox's
                    // job, and nothing else says so.
                    help: "Ranges from 10% to 100%. Uncheck Text Background to remove the box entirely."
                )

                SliderRow(
                    title: "Padding",
                    value: $project.selectedBlock.style.padding,
                    range: 0...64,
                    format: { "\(Int($0))" },
                    spokenName: "Background padding"
                )

                paddingHint
            }
            .disabled(!enabled)
        } header: {
            // Label first, checkbox after it.
            HStack(spacing: Spacing.small) {
                Text("Text Background")
                Toggle("Text Background", isOn: $project.selectedBlock.style.backgroundEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Spacer()
            }
        }
    }

    private var paddingHint: some View {
        HStack(spacing: 0) {
            Text("Instagram's native padding is approximately ")
            Button {
                project.selectedBlock.style.padding = Self.instagramPadding
            } label: {
                Text("\(Int(Self.instagramPadding))")
                    .underline()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .focused($paddingHintFocused)
            .focusEffectDisabled()
            .focusHalo(paddingHintFocused, shape: RoundedRectangle(cornerRadius: Radius.small))
            .help("Set padding to \(Int(Self.instagramPadding))")
            .accessibilityLabel("Set padding to \(Int(Self.instagramPadding))")
            Text(".")
        }
        .font(.appSmall)
        .foregroundStyle(.secondary)
    }

    private var exportFooter: some View {
        BarStrip {
            VStack(spacing: Spacing.small) {
                Button {
                    project.beginExport()
                } label: {
                    Text("Export Video")
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
        }
    }

    private func footerHint(_ message: String) -> some View {
        Text(message)
            .font(.appSmall)
            .foregroundStyle(.secondary)
    }

    private func styleBinding(_ keyPath: WritableKeyPath<OverlayStyle, RGBAColor>) -> Binding<RGBAColor> {
        Binding(
            get: { project.selectedBlock.style[keyPath: keyPath] },
            set: { project.selectedBlock.style[keyPath: keyPath] = $0 }
        )
    }
}
