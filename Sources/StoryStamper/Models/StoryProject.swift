import AppKit
import AVFoundation
import Foundation
import Observation
import UniformTypeIdentifiers

enum ExportPhase: Equatable {
    case idle
    case exporting(progress: Double)
    case completed(URL)
    case failed(String)
}

/// One text overlay: its content, its style, and its center in normalized
/// (0...1) video coordinates.
struct OverlayBlock: Identifiable, Equatable {
    let id: UUID
    var text: String
    var style: OverlayStyle
    var center: CGPoint

    init(id: UUID = UUID(), text: String = "", style: OverlayStyle, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.id = id
        self.text = text
        self.style = style
        self.center = center
    }
}

/// The single source of truth for the app: loaded video, playback state, text
/// blocks, selection, and export lifecycle.
@MainActor
@Observable
final class StoryProject {
    static let maxBlocks = 2

    // MARK: - Video

    private(set) var video: VideoInfo?
    let player = AVPlayer()
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    var loadErrorMessage: String?

    // MARK: - Text blocks

    var blocks: [OverlayBlock] {
        didSet { handleBlocksChange() }
    }

    /// Index of the block the controls panel edits. Read through
    /// `safeSelectedIndex` so a stale value can never crash after removal.
    var selectedIndex = 0

    var showSafeArea = SettingsStore.loadShowSafeArea() {
        didSet { SettingsStore.save(showSafeArea: showSafeArea) }
    }

    private struct CachedRender {
        let signature: Int
        let overlay: RenderedOverlay?
    }

    /// Rendered bitmaps keyed by block id, re-rendered only when a block's
    /// text or style actually changes—drags never trigger a re-render.
    private var renderCache: [UUID: CachedRender] = [:]
    private var lastSavedStyle: OverlayStyle

    // MARK: - Export

    var exportPhase: ExportPhase = .idle
    /// When the current export began, used to estimate time remaining.
    private(set) var exportStartedAt: Date?
    private var exportTask: Task<Void, Never>?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    static let allowedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    init() {
        let style = SettingsStore.loadStyle()
        blocks = [OverlayBlock(style: style)]
        lastSavedStyle = style

        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
            }
        }
    }

    // MARK: - Block management

    private var safeSelectedIndex: Int {
        min(max(selectedIndex, 0), blocks.count - 1)
    }

    var selectedBlock: OverlayBlock {
        get { blocks[safeSelectedIndex] }
        set { blocks[safeSelectedIndex] = newValue }
    }

    func overlay(for block: OverlayBlock) -> RenderedOverlay? {
        renderCache[block.id]?.overlay
    }

    var canAddBlock: Bool {
        blocks.count < Self.maxBlocks
    }

    /// Adds a second block, inheriting the current block's style and landing
    /// in the emptier half of the frame.
    func addBlock() {
        guard canAddBlock else { return }
        let vertical = selectedBlock.center.y <= 0.5 ? 0.75 : 0.25
        blocks.append(OverlayBlock(style: selectedBlock.style, center: CGPoint(x: 0.5, y: vertical)))
        selectedIndex = blocks.count - 1
    }

    func removeSelectedBlock() {
        guard blocks.count > 1 else { return }
        blocks.remove(at: safeSelectedIndex)
        selectedIndex = 0
    }

    private func handleBlocksChange() {
        refreshOverlays()
        let style = selectedBlock.style
        if style != lastSavedStyle {
            SettingsStore.save(style)
            lastSavedStyle = style
        }
    }

    private func refreshOverlays() {
        guard let video else {
            renderCache = [:]
            return
        }
        var newCache: [UUID: CachedRender] = [:]
        for block in blocks {
            var hasher = Hasher()
            hasher.combine(block.text)
            hasher.combine(block.style)
            hasher.combine(video.displaySize.width)
            hasher.combine(video.displaySize.height)
            let signature = hasher.finalize()

            if let cached = renderCache[block.id], cached.signature == signature {
                newCache[block.id] = cached
            } else {
                newCache[block.id] = CachedRender(
                    signature: signature,
                    overlay: OverlayRenderer.renderBlock(text: block.text, style: block.style, videoSize: video.displaySize)
                )
            }
        }
        renderCache = newCache
    }

    // MARK: - Loading

    func loadVideo(from url: URL) {
        Task {
            do {
                let info = try await VideoInfo.probe(url: url)
                video = info
                player.replaceCurrentItem(with: AVPlayerItem(asset: AVURLAsset(url: url)))
                currentTime = 0
                isPlaying = false
                installLoopObserver()
                refreshOverlays()
            } catch {
                loadErrorMessage = error.localizedDescription
            }
        }
    }

    static func isAcceptableVideo(url: URL) -> Bool {
        allowedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Unloads the video and returns to the drop screen. Text blocks and their
    /// styles survive, so the same stamp can be applied to the next video.
    func clearVideo() {
        pause()
        player.replaceCurrentItem(with: nil)
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        video = nil
        currentTime = 0
        renderCache = [:]
    }

    /// Loops playback at the end, matching how a Story behaves in Instagram.
    private func installLoopObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let item = self.player.currentItem else { return }
                item.seek(to: .zero, completionHandler: nil)
                if self.isPlaying {
                    self.player.play()
                }
            }
        }
    }

    // MARK: - Playback

    func togglePlayback() {
        guard video != nil else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }

    // MARK: - Placement

    enum QuickPosition {
        case top, center, bottom
    }

    /// Horizontally centered placement of the selected block with a
    /// safe-area-friendly margin.
    func applyQuickPosition(_ position: QuickPosition) {
        guard let video else { return }
        let blockSize = overlay(for: selectedBlock)?.pixelSize ?? .zero
        let blockHalf = blockSize.height / 2 / video.displaySize.height
        let y: Double
        switch position {
        case .top: y = 0.14 + blockHalf
        case .center: y = 0.5
        case .bottom: y = 0.86 - blockHalf
        }
        selectedBlock.center = OverlayRenderer.clampedCenter(
            CGPoint(x: 0.5, y: y),
            blockSize: blockSize,
            videoSize: video.displaySize
        )
    }

    // MARK: - Export

    /// All non-empty blocks paired with their positions, in draw order.
    var placedOverlays: [PlacedOverlay] {
        blocks.compactMap { block in
            overlay(for: block).map { PlacedOverlay(overlay: $0, center: block.center) }
        }
    }

    var canExport: Bool {
        video != nil && !placedOverlays.isEmpty && exportTask == nil
    }

    /// Prompts for a destination, then runs the export off the main actor.
    func beginExport() {
        guard let video else { return }
        let overlays = placedOverlays
        guard !overlays.isEmpty else { return }
        pause()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = video.url.deletingPathExtension().lastPathComponent + "-story.mp4"
        panel.title = "Export Story Video"
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        exportPhase = .exporting(progress: 0)
        exportStartedAt = Date()
        exportTask = Task {
            do {
                try await VideoExporter.export(
                    videoInfo: video,
                    overlays: overlays,
                    outputURL: outputURL
                ) { progress in
                    Task { @MainActor [weak self] in
                        if case .exporting = self?.exportPhase {
                            self?.exportPhase = .exporting(progress: progress)
                        }
                    }
                }
                exportPhase = .completed(outputURL)
            } catch is CancellationError {
                exportPhase = .idle
            } catch {
                exportPhase = .failed(error.localizedDescription)
            }
            exportTask = nil
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportPhase = .idle
    }

    func finishExport() {
        exportPhase = .idle
    }

    func revealExportInFinder() {
        if case .completed(let url) = exportPhase {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
