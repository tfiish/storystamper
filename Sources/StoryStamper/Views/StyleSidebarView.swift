import SwiftUI

/// Right sidebar: how the text looks and where it sits, plus the export
/// action. All controls edit the selected block.
struct StyleSidebarView: View {
    @Bindable var project: StoryProject

    var body: some View {
        VStack(spacing: 0) {
            Form {
                textSection
                styleSection
                backgroundSection
            }
            .formStyle(.grouped)

            exportFooter
        }
        .frame(width: 300)
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
                .font(.appRegular)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)

            HStack {
                if project.canAddBlock {
                    Button("Add Text Block") {
                        project.addBlock()
                    }
                }
                if project.blocks.count > 1 {
                    Button("Remove", role: .destructive) {
                        project.removeSelectedBlock()
                    }
                }
            }

            Text("Drag a block on the preview to position it. It snaps to the midlines.")
                .font(.appSmall)
                .foregroundStyle(.secondary)
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
                        .font(.appSmallDigits)
                        .frame(width: 28, alignment: .trailing)
                }
            }

            Picker("Alignment", selection: $project.selectedBlock.style.alignment) {
                ForEach(TextAlignmentChoice.allCases) { choice in
                    Image(systemName: choice.symbolName).tag(choice)
                }
            }
            .pickerStyle(.segmented)

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

                LabeledContent("Opacity") {
                    HStack(spacing: 8) {
                        // 100% produces what used to be the "Solid" mode.
                        Slider(value: $project.selectedBlock.style.backgroundOpacity, in: 0.1...1)
                        Text("\(Int(project.selectedBlock.style.backgroundOpacity * 100))%")
                            .font(.appSmallDigits)
                            .frame(width: 32, alignment: .trailing)
                    }
                }

                LabeledContent("Padding") {
                    HStack(spacing: 8) {
                        Slider(value: $project.selectedBlock.style.padding, in: 0...64)
                        Text("\(Int(project.selectedBlock.style.padding))")
                            .font(.appSmallDigits)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .disabled(!enabled)
        } header: {
            // Label first, checkbox after it.
            HStack(spacing: 6) {
                Text("Text Background")
                Toggle("", isOn: $project.selectedBlock.style.backgroundEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Spacer()
            }
        }
    }

    private var exportFooter: some View {
        VStack(spacing: 6) {
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
        .padding(12)
        .background(.bar)
    }

    private func footerHint(_ message: String) -> some View {
        Text(message)
            .font(.appSmall)
            .foregroundStyle(.tertiary)
    }

    private func styleBinding(_ keyPath: WritableKeyPath<OverlayStyle, RGBAColor>) -> Binding<RGBAColor> {
        Binding(
            get: { project.selectedBlock.style[keyPath: keyPath] },
            set: { project.selectedBlock.style[keyPath: keyPath] = $0 }
        )
    }
}

/// One-click preset swatches followed by the system color picker for anything
/// else. The active preset gets a ring.
private struct ColorRow: View {
    let presets: [(name: String, color: RGBAColor)]
    @Binding var selection: RGBAColor

    var body: some View {
        HStack(spacing: 7) {
            ForEach(presets, id: \.name) { preset in
                Button {
                    selection = preset.color
                } label: {
                    Circle()
                        .fill(preset.color.color)
                        .frame(width: 17, height: 17)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.5))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                .padding(-3)
                                .opacity(selection.matches(preset.color) ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .help(preset.name)
            }

            ColorPicker(
                "",
                selection: Binding(
                    get: { selection.color },
                    set: { selection = RGBAColor(color: $0) }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            // macOS's color panel has no OK button—it applies as you pick—so
            // say that rather than leave people hunting for one.
            .help("Custom color. Changes apply as you pick; close the panel when you are done.")
        }
    }
}
