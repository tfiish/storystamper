import SwiftUI
import UniformTypeIdentifiers

/// The center pane: drop zone, video preview with draggable overlays,
/// safe-area guides, and transport controls.
struct VideoPreviewView: View {
    @Bindable var project: StoryProject
    @State private var isDropTargeted = false
    @State private var dragStartCenter: CGPoint?
    @State private var snappedToCenterX = false
    @State private var snappedToCenterY = false
    /// Whether the preview holds keyboard focus, which is what makes the
    /// arrow keys nudge the selected block.
    @FocusState private var previewFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                if project.video != nil {
                    previewCanvas
                } else {
                    dropPrompt
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: Radius.medium)
                        .strokeBorder(Color.accentColor, lineWidth: BorderWidth.strong)
                        .padding(Spacing.small)
                }
            }
            .focusable(project.video != nil)
            .focused($previewFocused)
            .focusEffectDisabled()
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow], phases: [.down, .repeat]) { press in
                nudge(press)
            }
            .accessibilityLabel("Video preview")
            .accessibilityHint("Arrow keys move the selected block. Hold Shift to move farther.")

            if project.video != nil {
                TransportBar(project: project)
            }
        }
    }

    // MARK: - Keyboard placement

    /// Arrow keys are the non-mouse route to positioning, and the precise one:
    /// a fine step is about four pixels on a 1080-wide frame.
    private func nudge(_ press: KeyPress) -> KeyPress.Result {
        guard project.video != nil else { return .ignored }
        let step = press.modifiers.contains(.shift) ? Interaction.nudgeCoarse : Interaction.nudgeFine
        switch press.key {
        case .upArrow: project.nudgeSelectedBlock(dx: 0, dy: -step)
        case .downArrow: project.nudgeSelectedBlock(dx: 0, dy: step)
        case .leftArrow: project.nudgeSelectedBlock(dx: -step, dy: 0)
        case .rightArrow: project.nudgeSelectedBlock(dx: step, dy: 0)
        default: return .ignored
        }
        return .handled
    }

    // MARK: - Empty state

    private var dropPrompt: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "film.stack")
                .font(.system(size: IconSize.emptyState, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Drag a video here")
                .font(.appTitle)
            Text("MP4, MOV, or M4V")
                .font(.appRegular)
                .foregroundStyle(.secondary)
            Button("Open Video") {
                project.chooseVideo()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Preview

    private var previewCanvas: some View {
        GeometryReader { geometry in
            if let video = project.video {
                let videoRect = fittedRect(for: video.displaySize, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    PlayerLayerView(player: project.player)
                        .frame(width: videoRect.width, height: videoRect.height)
                        .offset(x: videoRect.minX, y: videoRect.minY)

                    if project.showSafeArea {
                        SafeAreaGuides(videoRect: videoRect)
                    }

                    ForEach(Array(project.blocks.enumerated()), id: \.element.id) { index, block in
                        if let overlay = project.overlay(for: block) {
                            overlayView(overlay, blockIndex: index, video: video, videoRect: videoRect)
                        }
                    }

                    CenterGuides(
                        videoRect: videoRect,
                        showVertical: snappedToCenterX,
                        showHorizontal: snappedToCenterY
                    )

                    clearButton(videoRect: videoRect)
                }
            }
        }
        // The content inset. The drop-target ring is deliberately tighter
        // (`Spacing.small`), because it marks the pane that accepts the file
        // rather than the canvas inside it—so it reads as sitting outside the
        // content, not as a second frame around it.
        .padding(Spacing.medium)
    }

    /// Aspect-fit rect for the video inside the available space; every overlay
    /// coordinate conversion goes through this same rect.
    private func fittedRect(for videoSize: CGSize, in container: CGSize) -> CGRect {
        guard videoSize.width > 0, videoSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / videoSize.width, container.height / videoSize.height)
        let size = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func clearButton(videoRect: CGRect) -> some View {
        // Inset from the video's corner by one spacing step, expressed from
        // the button's own size so the gap stays right if either changes.
        let inset = Metrics.overlayButton / 2 + Spacing.small
        return IconButton(
            systemName: "xmark",
            label: "Unload video and clear story text",
            glyphSize: IconSize.small,
            glyphWeight: .bold,
            style: .scrim
        ) {
            project.requestClearVideo()
        }
        .position(x: videoRect.maxX - inset, y: videoRect.minY + inset)
    }

    private func overlayView(_ overlay: RenderedOverlay, blockIndex: Int, video: VideoInfo, videoRect: CGRect) -> some View {
        let scale = videoRect.width / video.displaySize.width
        let displaySize = CGSize(width: overlay.pixelSize.width * scale, height: overlay.pixelSize.height * scale)
        let center = OverlayRenderer.clampedCenter(
            project.blocks[blockIndex].center,
            blockSize: overlay.pixelSize,
            videoSize: video.displaySize
        )
        // The ring marks what the controls—and the arrow keys—are about to
        // act on, so it matters once there is a second block, and whenever the
        // preview has keyboard focus.
        let isTarget = blockIndex == min(project.selectedIndex, project.blocks.count - 1)
        let isSelected = isTarget && (project.blocks.count > 1 || previewFocused)

        return Image(decorative: overlay.cgImage, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: displaySize.width, height: displaySize.height)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.small)
                        .strokeBorder(
                            Color.accentColor.opacity(Opacity.ring),
                            style: StrokeStyle(lineWidth: BorderWidth.emphasis, dash: Stroke.selectionDash)
                        )
                        .padding(-Spacing.tight)
                }
            }
            .position(
                x: videoRect.minX + center.x * videoRect.width,
                y: videoRect.minY + center.y * videoRect.height
            )
            .onTapGesture {
                select(blockIndex)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartCenter == nil {
                            dragStartCenter = project.blocks[blockIndex].center
                            select(blockIndex)
                        }
                        guard let start = dragStartCenter, videoRect.width > 0, videoRect.height > 0 else { return }

                        var proposed = CGPoint(
                            x: start.x + value.translation.width / videoRect.width,
                            y: start.y + value.translation.height / videoRect.height
                        )

                        // Snap each axis independently to the midline, using a
                        // threshold expressed in screen points.
                        let snapX = abs(proposed.x - 0.5) * videoRect.width < Interaction.snapTolerance
                        let snapY = abs(proposed.y - 0.5) * videoRect.height < Interaction.snapTolerance
                        if snapX { proposed.x = 0.5 }
                        if snapY { proposed.y = 0.5 }
                        if snapX != snappedToCenterX { snappedToCenterX = snapX }
                        if snapY != snappedToCenterY { snappedToCenterY = snapY }

                        project.blocks[blockIndex].center = OverlayRenderer.clampedCenter(
                            proposed,
                            blockSize: overlay.pixelSize,
                            videoSize: video.displaySize
                        )
                    }
                    .onEnded { _ in
                        dragStartCenter = nil
                        snappedToCenterX = false
                        snappedToCenterY = false
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Block \(blockIndex + 1)")
            .accessibilityValue(project.blocks[blockIndex].text)
            .accessibilityAddTraits(isTarget ? [.isSelected] : [])
    }

    /// Selecting a block also takes keyboard focus, so the arrow keys act on
    /// whatever was just clicked without a separate focusing step.
    private func select(_ blockIndex: Int) {
        project.selectedIndex = blockIndex
        previewFocused = true
    }

    // MARK: - Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let dropped = item as? URL {
                url = dropped
            }
            guard let url else { return }
            Task { @MainActor in
                // loadVideo owns the file-type rule, so the drop path and the
                // open panel cannot disagree about what is acceptable.
                project.loadVideo(from: url)
            }
        }
        return true
    }
}

// MARK: - Alignment guides

/// Midlines that appear only while a drag is snapped to them.
private struct CenterGuides: View {
    let videoRect: CGRect
    let showVertical: Bool
    let showHorizontal: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showVertical {
                line(width: BorderWidth.hairline, height: videoRect.height)
                    .offset(x: videoRect.midX, y: videoRect.minY)
            }
            if showHorizontal {
                line(width: videoRect.width, height: BorderWidth.hairline)
                    .offset(x: videoRect.minX, y: videoRect.midY)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeOut(duration: Motion.quick), value: showVertical)
        .animation(.easeOut(duration: Motion.quick), value: showHorizontal)
    }

    private func line(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(Opacity.scrim), radius: BorderWidth.hairline)
    }
}

/// Approximate zones where Instagram's own UI covers a Story. Visual guide
/// only—never part of the export.
private struct SafeAreaGuides: View {
    let videoRect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            zone(height: videoRect.height * Instagram.topSafeFraction, edge: .top)
                .offset(x: videoRect.minX, y: videoRect.minY)
            zone(height: videoRect.height * Instagram.bottomSafeFraction, edge: .bottom)
                .offset(x: videoRect.minX, y: videoRect.maxY - videoRect.height * Instagram.bottomSafeFraction)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func zone(height: CGFloat, edge: VerticalEdge) -> some View {
        Rectangle()
            .fill(Color.black.opacity(Opacity.wash))
            .overlay(alignment: edge == .top ? .bottom : .top) {
                Rectangle()
                    .fill(Color.white.opacity(Opacity.rule))
                    .frame(height: BorderWidth.hairline)
            }
            .frame(width: videoRect.width, height: height)
    }
}

// MARK: - Transport controls

private struct TransportBar: View {
    @Bindable var project: StoryProject
    @State private var wasPlayingBeforeScrub = false

    var body: some View {
        BarStrip(horizontalPadding: Spacing.large) {
            HStack(spacing: Spacing.medium) {
                IconButton(
                    systemName: project.isPlaying ? "pause.fill" : "play.fill",
                    label: project.isPlaying ? "Pause" : "Play",
                    // AppKit offers key equivalents to the view tree before
                    // the first responder sees the key, so an unconditional
                    // space shortcut would swallow spaces typed into the
                    // story text.
                    shortcut: project.isEditingText ? nil : KeyboardShortcut(.space, modifiers: [])
                ) {
                    project.togglePlayback()
                }

                Text(VideoInfo.timecode(project.currentTime))
                    .font(.appSmallDigits)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Slider(
                    value: Binding(
                        get: { min(project.currentTime, duration) },
                        set: { project.seek(to: $0) }
                    ),
                    in: 0...duration
                ) { editing in
                    if editing {
                        wasPlayingBeforeScrub = project.isPlaying
                        project.pause()
                    } else if wasPlayingBeforeScrub {
                        project.togglePlayback()
                    }
                }
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(VideoInfo.timecode(project.currentTime)) of \(VideoInfo.timecode(duration))")

                Text(VideoInfo.timecode(duration))
                    .font(.appSmallDigits)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var duration: Double {
        max(project.video?.duration ?? 0, 0.01)
    }
}
