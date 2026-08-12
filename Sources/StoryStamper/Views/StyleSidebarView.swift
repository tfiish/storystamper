import SwiftUI

/// Right sidebar: how the text looks and where it sits, plus the export
/// action. All controls edit the selected block.
struct StyleSidebarView: View {
    @Bindable var project: StoryProject
    @FocusState private var textEditorFocused: Bool

    private var noVideo: Bool { project.video == nil }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // Nothing in here means anything without a video: a block is
                // placed against the video's frame, and no overlay renders
                // until one is loaded. Better to grey the lot than to let
                // someone style an overlay that does not exist.
                //
                // Disabled per section rather than on the Form, because
                // disabling the Form disables its scroll view too—so at a
                // short window the greyed-out panel could not be scrolled to
                // see the rest of itself, which reads as broken rather than
                // as unavailable.
                textSection.disabled(noVideo)
                styleSection.disabled(noVideo)
                backgroundSection.disabled(noVideo)
            }
            .formStyle(.grouped)

            exportFooter
        }
        .frame(width: project.styleSidebarWidth)
        // The transport bar gives up the space bar while this is true, so a
        // space typed into the story text stays a space.
        .onChange(of: textEditorFocused) { _, focused in
            project.isEditingText = focused
        }
        // Double-clicking a block on the preview selects it and lands here,
        // so the caret arrives in the field that holds that block's text.
        .onChange(of: project.textFocusRequests) { _, _ in
            textEditorFocused = true
        }
    }

    private var textSection: some View {
        Section("Story Text") {
            // Always present, even at one block: it used to appear when the
            // second block did, shifting every control below it. Disabled
            // controls that stay put beat controls that move.
            Picker("Block", selection: $project.selectedIndex) {
                ForEach(Array(project.blocks.enumerated()), id: \.element.id) { index, _ in
                    Text("Block \(index + 1)").tag(index)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(project.blocks.count < 2)

            TextEditor(text: $project.selectedBlock.text)
                .font(.appRegular)
                .frame(minHeight: Metrics.textEditorMinHeight)
                .scrollContentBackground(.hidden)
                .focused($textEditorFocused)
                .accessibilityLabel("Story text")

            HStack {
                Button("Add Block") {
                    project.addBlock()
                }
                .disabled(!project.canAddBlock)

                Button("Remove Block", role: .destructive) {
                    project.requestRemoveSelectedBlock()
                }
                .disabled(project.blocks.count < 2)
            }

            Text("Drag or use arrow keys to reposition.")
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
                    hint: "Ranges from 10% to 100%. Uncheck Text Background to remove the box entirely."
                )

                SliderRow(
                    title: "Padding",
                    value: $project.selectedBlock.style.padding,
                    range: 0...64,
                    format: { "\(Int($0))" },
                    spokenName: "Background padding"
                )
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
                    // "Open", not "Load": the same verb the drop screen, the
                    // File menu, and the open panel all use for this action.
                    footerHint("Open a video to enable these controls.")
                } else if !project.hasStoryText {
                    footerHint("Enter text to export.")
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
