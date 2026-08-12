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

    var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The single source of truth for the app: loaded video, playback state, text
/// blocks, selection, and export lifecycle.
@MainActor
@Observable
final class StoryProject {
    /// One window, one project. The app delegate needs to see this state to
    /// guard quitting, so it lives here rather than inside a view's `@State`.
    static let shared = StoryProject()

    static let maxBlocks = 3

    // MARK: - Video

    private(set) var video: VideoInfo?
    let player = AVPlayer()
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    var loadError: VideoInfo.ProbeError?

    // MARK: - Text blocks

    var blocks: [OverlayBlock] {
        didSet { handleBlocksChange() }
    }

    /// Index of the block the controls panel edits. Read through
    /// `safeSelectedIndex` so a stale value can never crash after removal.
    var selectedIndex = 0

    /// True while the story text field has keyboard focus, so the transport
    /// bar can give up the space bar rather than swallow it mid-sentence.
    var isEditingText = false

    var showSafeArea = SettingsStore.loadShowSafeArea() {
        didSet { SettingsStore.save(showSafeArea: showSafeArea) }
    }

    var confirmDestructiveActions = SettingsStore.loadConfirmDestructive() {
        didSet { SettingsStore.save(confirmDestructive: confirmDestructiveActions) }
    }

    var appearance = SettingsStore.loadAppearance() {
        didSet {
            SettingsStore.save(appearance: appearance)
            appearance.apply()
        }
    }

    /// Width of the style sidebar, dragged by the splitter beside it. Saved on
    /// drag end rather than on every frame.
    var styleSidebarWidth = SettingsStore.loadStyleSidebarWidth()

    func persistStyleSidebarWidth() {
        SettingsStore.save(styleSidebarWidth: styleSidebarWidth)
    }

    /// The destructive action waiting on a confirmation sheet, if any.
    var pendingConfirmation: ConfirmationRequest?

    private struct CachedRender {
        let signature: Int
        let overlay: RenderedOverlay?
    }

    /// Rendered bitmaps keyed by block id, re-rendered only when a block's
    /// text or style actually changes—drags never trigger a re-render. The
    /// signature is a per-process hash, which is fine because it is only ever
    /// compared against another signature from the same run.
    private var renderCache: [UUID: CachedRender] = [:]
    private var lastSavedStyle: OverlayStyle

    // MARK: - Export

    var exportPhase: ExportPhase = .idle
    /// When the current export began, used to estimate time remaining.
    private(set) var exportStartedAt: Date?
    private var exportTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    static let allowedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    /// The same rule as `allowedExtensions`, in the form the open panel wants,
    /// so a file the panel offers is never one the drop handler would reject.
    static let allowedContentTypes: [UTType] = {
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie]
        if let m4v = UTType("com.apple.m4v-video") { types.append(m4v) }
        return types
    }()

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

    /// Text blocks only make sense against a loaded video, since placement is
    /// relative to its frame.
    var canAddBlock: Bool {
        video != nil && blocks.count < Self.maxBlocks
    }

    var hasStoryText: Bool {
        blocks.contains(where: \.hasText)
    }

    /// Adds a block inheriting the current block's style, dropped into
    /// whichever third of the frame sits farthest from the existing blocks.
    func addBlock() {
        guard canAddBlock else { return }
        let slots: [Double] = [0.2, 0.5, 0.8]
        let taken = blocks.map(\.center.y)
        let distance: (Double) -> Double = { slot in
            taken.map { abs($0 - slot) }.min() ?? 1
        }
        let vertical = slots.max { distance($0) < distance($1) } ?? 0.5
        blocks.append(OverlayBlock(style: selectedBlock.style, center: CGPoint(x: 0.5, y: vertical)))
        selectedIndex = blocks.count - 1
    }

    private func removeSelectedBlock() {
        guard blocks.count > 1 else { return }
        blocks.remove(at: safeSelectedIndex)
        selectedIndex = 0
    }

    /// Moves the selected block by a step in normalized coordinates, clamped
    /// the same way a drag is, so the keyboard and the mouse cannot put a
    /// block anywhere the other could not.
    func nudgeSelectedBlock(dx: CGFloat, dy: CGFloat) {
        guard let video else { return }
        let index = safeSelectedIndex
        guard let overlay = overlay(for: blocks[index]) else { return }
        let current = blocks[index].center
        blocks[index].center = OverlayRenderer.clampedCenter(
            CGPoint(x: current.x + dx, y: current.y + dy),
            blockSize: overlay.pixelSize,
            videoSize: video.displaySize
        )
    }

    /// What persists between launches is the style of the block you last
    /// *edited*, not block 1 and not whichever block is selected—changing the
    /// selection does not touch `blocks`, so it does not reach this method. It
    /// is worth knowing that with three differently styled blocks, the one
    /// that survives a relaunch is the one you last touched a control for.
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

    // MARK: - Destructive actions

    /// Every path that throws away typed text goes through one of these two
    /// requests, so the confirmation can never be bypassed by adding a caller.
    func requestClearVideo() {
        guard confirmDestructiveActions, hasStoryText else {
            clearVideo()
            return
        }
        pendingConfirmation = ConfirmationRequest(action: .clearVideo)
    }

    func requestRemoveSelectedBlock() {
        guard blocks.count > 1 else { return }
        guard confirmDestructiveActions, blocks[safeSelectedIndex].hasText else {
            removeSelectedBlock()
            return
        }
        pendingConfirmation = ConfirmationRequest(action: .removeBlock)
    }

    func cancelConfirmation() {
        pendingConfirmation = nil
    }

    func resolveConfirmation(suppressFuture: Bool) {
        guard let request = pendingConfirmation else { return }
        pendingConfirmation = nil
        if suppressFuture {
            confirmDestructiveActions = false
        }
        switch request.action {
        case .clearVideo: clearVideo()
        case .removeBlock: removeSelectedBlock()
        }
    }

    // MARK: - Loading

    func loadVideo(from url: URL) {
        guard Self.isAcceptableVideo(url: url) else {
            loadError = .unsupportedType
            return
        }
        loadTask?.cancel()
        loadTask = Task {
            do {
                let info = try await VideoInfo.probe(url: url)
                // A second drop landing while this probe ran wins; this one
                // must not overwrite it on the way out.
                try Task.checkCancellation()
                video = info
                player.replaceCurrentItem(with: AVPlayerItem(asset: AVURLAsset(url: url)))
                currentTime = 0
                isPlaying = false
                installLoopObserver()
                refreshOverlays()
            } catch is CancellationError {
                // Superseded by a newer load; leave the newer one alone.
            } catch let error as VideoInfo.ProbeError {
                loadError = error
            } catch {
                loadError = .unreadable(error.localizedDescription)
            }
        }
    }

    static func isAcceptableVideo(url: URL) -> Bool {
        allowedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Unloads the video and returns to the drop screen, clearing the story
    /// text back to a single empty block. Styling carries over, since those
    /// settings are meant to persist.
    private func clearVideo() {
        pause()
        loadTask?.cancel()
        loadTask = nil
        player.replaceCurrentItem(with: nil)
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        video = nil
        currentTime = 0
        // Setting `blocks` after `video` is already nil clears the render
        // cache through `handleBlocksChange`.
        blocks = [OverlayBlock(style: selectedBlock.style)]
        selectedIndex = 0
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

    var isExporting: Bool {
        if case .exporting = exportPhase { return true }
        return false
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
        panel.title = "Export Video"
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
        exportTask = nil
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
