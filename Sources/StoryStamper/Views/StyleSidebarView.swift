import SwiftUI

/// Right sidebar: how the text looks and where it sits, plus the export
/// action. All controls edit the selected block.
struct StyleSidebarView: View {
    @Bindable var project: StoryProject

    var body: some View {
        VStack(spacing: 0) {
            Form {
                styleSection
                backgroundSection
                positionSection
            }
            .formStyle(.grouped)

            exportFooter
        }
        .frame(width: 300)
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
        Section("Text Background") {
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

            Text("Drag a text block on the preview to fine-tune. It snaps to the midlines.")
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
