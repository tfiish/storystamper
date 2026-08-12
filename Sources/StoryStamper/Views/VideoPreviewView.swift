import SwiftUI
import UniformTypeIdentifiers

/// The left pane: drop zone, video preview with draggable overlays, safe-area
/// guides, and transport controls.
struct VideoPreviewView: View {
    @Bindable var project: StoryProject
    @State private var isDropTargeted = false
    @State private var dragStartCenter: CGPoint?
    @State private var snappedToCenterX = false
    @State private var snappedToCenterY = false

    /// How close, in preview points, a drag must come to a midline before it
    /// snaps. Measured on screen so the feel is the same at any window size.
    private let snapDistance: CGFloat = 9

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

            if project.video != nil {
                TransportBar(project: project)
            }
        }
    }

    // MARK: - Empty state

    private var dropPrompt: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "film.stack")
                .font(.system(size: IconSize.emptyState, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drag a video here")
                .font(.appTitle)
            Text("MP4, MOV, or M4V")
                .font(.appRegular)
                .foregroundStyle(.secondary)
            Button("Choose Video…") {
                chooseVideo(for: project)
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
        Button {
            project.clearVideo()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: IconSize.small, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Metrics.overlayButton, height: Metrics.overlayButton)
                .background(Circle().fill(Color.black.opacity(0.55)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: BorderWidth.hairline))
        }
        .buttonStyle(.plain)
        .help("Close this video and choose another")
        .position(x: videoRect.maxX - 20, y: videoRect.minY + 20)
    }

    private func overlayView(_ overlay: RenderedOverlay, blockIndex: Int, video: VideoInfo, videoRect: CGRect) -> some View {
        let scale = videoRect.width / video.displaySize.width
        let displaySize = CGSize(width: overlay.pixelSize.width * scale, height: overlay.pixelSize.height * scale)
        let center = OverlayRenderer.clampedCenter(
            project.blocks[blockIndex].center,
            blockSize: overlay.pixelSize,
            videoSize: video.displaySize
        )
        // The selection ring only matters once a second block exists.
        let isSelected = project.blocks.count > 1 && blockIndex == min(project.selectedIndex, project.blocks.count - 1)

        return Image(decorative: overlay.cgImage, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: displaySize.width, height: displaySize.height)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.small)
                        .strokeBorder(Color.accentColor.opacity(0.8), style: StrokeStyle(lineWidth: BorderWidth.emphasis, dash: [5, 4]))
                        .padding(-Spacing.tight)
                }
            }
            .position(
                x: videoRect.minX + center.x * videoRect.width,
                y: videoRect.minY + center.y * videoRect.height
            )
            .onTapGesture {
                project.selectedIndex = blockIndex
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartCenter == nil {
                            dragStartCenter = center
                            project.selectedIndex = blockIndex
                        }
                        guard let start = dragStartCenter, videoRect.width > 0, videoRect.height > 0 else { return }

                        var proposed = CGPoint(
                            x: start.x + value.translation.width / videoRect.width,
                            y: start.y + value.translation.height / videoRect.height
                        )

                        // Snap each axis independently to the midline, using a
                        // threshold expressed in screen points.
                        let snapX = abs(proposed.x - 0.5) * videoRect.width < snapDistance
                        let snapY = abs(proposed.y - 0.5) * videoRect.height < snapDistance
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
                if StoryProject.isAcceptableVideo(url: url) {
                    project.loadVideo(from: url)
                } else {
                    project.loadErrorMessage = "Please choose an MP4, MOV, or M4V video."
                }
            }
        }
        return true
    }
}

/// Shared open-panel flow, used by the drop prompt, and the Replace Video button.
@MainActor
func chooseVideo(for project: StoryProject) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.title = "Choose Video"
    if panel.runModal() == .OK, let url = panel.url {
        project.loadVideo(from: url)
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
        .animation(.easeOut(duration: 0.1), value: showVertical)
        .animation(.easeOut(duration: 0.1), value: showHorizontal)
    }

    private func line(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.5), radius: BorderWidth.hairline)
    }
}

/// Approximate zones where Instagram's own UI covers a Story. Visual guide
/// only—never part of the export.
private struct SafeAreaGuides: View {
    let videoRect: CGRect
    private let topFraction: CGFloat = 0.13
    private let bottomFraction: CGFloat = 0.16

    var body: some View {
        ZStack(alignment: .topLeading) {
            zone(height: videoRect.height * topFraction, edge: .top)
                .offset(x: videoRect.minX, y: videoRect.minY)
            zone(height: videoRect.height * bottomFraction, edge: .bottom)
                .offset(x: videoRect.minX, y: videoRect.maxY - videoRect.height * bottomFraction)
        }
        .allowsHitTesting(false)
    }

    private func zone(height: CGFloat, edge: VerticalEdge) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.25))
            .overlay(alignment: edge == .top ? .bottom : .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
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
        HStack(spacing: Spacing.medium) {
            Button {
                project.togglePlayback()
            } label: {
                Image(systemName: project.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: IconSize.medium))
                    .frame(width: Metrics.overlayButton)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            Text(timeString(project.currentTime))
                .font(.appSmallDigits)
                .foregroundStyle(.secondary)

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

            Text(timeString(duration))
                .font(.appSmallDigits)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
        .background(.bar)
    }

    private var duration: Double {
        max(project.video?.duration ?? 0, 0.01)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
