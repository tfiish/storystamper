import AppKit
import AVFoundation
import Foundation
import Observation
import UniformTypeIdentifiers

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

    /// The one thing that went wrong, waiting to be shown. Loading and
    /// exporting both land here—see `StoryFailure`.
    var failure: StoryFailure?

    // MARK: - Text blocks

    var blocks: [OverlayBlock] {
        didSet { handleBlocksChange(from: oldValue) }
    }

    /// Index of the block the controls panel edits. Read through
    /// `safeSelectedIndex` so a stale value can never crash after removal.
    var selectedIndex = 0 {
        didSet { persistSelectedStyle() }
    }

    /// True while the story text field has keyboard focus, so the transport
    /// bar can give up the space bar rather than swallow it mid-sentence.
    var isEditingText = false

    var showSafeArea = SettingsStore.loadShowSafeArea() {
        didSet { SettingsStore.save(showSafeArea: showSafeArea) }
    }

    var appearance = SettingsStore.loadAppearance() {
        didSet {
            SettingsStore.save(appearance: appearance)
            appearance.apply()
        }
    }

    var exportResolution = SettingsStore.loadExportResolution() {
        didSet { SettingsStore.save(exportResolution: exportResolution) }
    }

    /// Width of the style sidebar, dragged by the splitter beside it. Saved on
    /// drag end rather than on every frame.
    var styleSidebarWidth = SettingsStore.loadStyleSidebarWidth()

    func persistStyleSidebarWidth() {
        SettingsStore.save(styleSidebarWidth: styleSidebarWidth)
    }

    /// Which informational sheet is showing, if any.
    var infoSheet: InfoSheet?

    private struct CachedRender {
        let signature: Int
        let overlay: RenderedOverlay?
    }

    /// Rendered bitmaps keyed by block id, re-rendered only when a block's
    /// text or style actually changes—drags never trigger a re-render. The
    /// signature is a per-process hash, which is fine because it is only ever
    /// compared against another signature from the same run.
    private var renderCache: [UUID: CachedRender] = [:]
    /// One in-flight render per block, so a burst of keystrokes or a slider
    /// drag replaces its predecessor instead of queueing behind it.
    private var renderTasks: [UUID: Task<Void, Never>] = [:]
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

    /// Undoes what `init` set up. Nothing leaks today, because the app holds
    /// one shared project for its whole life—but that is a fact about the app,
    /// not about this class, and an object that only behaves while it is never
    /// released is a trap laid for the next caller.
    ///
    /// `isolated deinit` is what makes this possible: the class is
    /// `@MainActor`, and an ordinary deinit is nonisolated, so it could not
    /// touch the player or the task table at all.
    isolated deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        cancelRenders()
        undoGroupCloser?.cancel()
        exportTask?.cancel()
        loadTask?.cancel()
    }

    // MARK: - Undo

    /// The window's undo manager, handed over by `MainWindowView`, which is
    /// where `@Environment(\.undoManager)` can see it. Not observed: nothing
    /// on screen is drawn from it.
    @ObservationIgnored weak var undoManager: UndoManager?

    /// A burst of edits of one kind on one block is a single undo step, so
    /// dragging the Size slider is one Command-Z rather than ninety.
    private enum UndoGroup: Equatable {
        case style(UUID)
        case placement(UUID)
    }

    private var openUndoGroup: UndoGroup?
    private var undoGroupCloser: Task<Void, Never>?
    /// True while an undo or a redo is being applied, so putting state back
    /// does not register itself as a fresh edit.
    private var isRestoring = false

    /// Everything an undo step has to put back. A value type, so holding one
    /// cannot keep a half-torn-down player or render alive.
    private struct Snapshot: Sendable {
        let video: VideoInfo?
        let blocks: [OverlayBlock]
        let selectedIndex: Int
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(video: video, blocks: blocks, selectedIndex: selectedIndex)
    }

    /// Names the current state and puts it on the stack, for an action that is
    /// about to change it.
    private func registerUndo(_ actionName: String) {
        guard !isRestoring else { return }
        closeUndoGroup()
        pushUndo(actionName, snapshot: currentSnapshot())
    }

    /// Registering an undo *while undoing* is what gives us redo: AppKit puts
    /// anything registered during an undo onto the redo stack instead, so one
    /// mutually recursive registration covers both directions.
    private func pushUndo(_ actionName: String, snapshot: Snapshot) {
        guard let undoManager else { return }
        undoManager.setActionName(actionName)
        undoManager.registerUndo(withTarget: self) { project in
            MainActor.assumeIsolated {
                let inverse = project.currentSnapshot()
                project.restore(snapshot)
                project.pushUndo(actionName, snapshot: inverse)
            }
        }
    }

    private func restore(_ snapshot: Snapshot) {
        isRestoring = true
        defer { isRestoring = false }
        closeUndoGroup()

        if snapshot.video?.url != video?.url {
            if let restored = snapshot.video {
                adopt(restored)
            } else {
                clearVideo()
            }
        }
        // Assigning `blocks` re-renders through `handleBlocksChange`, so the
        // preview catches up without a second pass here.
        blocks = snapshot.blocks
        selectedIndex = min(max(snapshot.selectedIndex, 0), blocks.count - 1)
    }

    /// Classifies what an edit actually changed, so the right thing lands on
    /// the stack. Structural changes register themselves at the call site,
    /// where the action has a name; typing is deliberately left alone, because
    /// the text editor keeps its own undo and two stacks over one field is
    /// worse than one.
    private func registerUndoForEdit(from oldBlocks: [OverlayBlock]) {
        guard !isRestoring, undoManager != nil else { return }
        // Identity, not just count: clearing a video also swaps the single
        // block for a fresh one, and that step is registered by its own name.
        guard oldBlocks.map(\.id) == blocks.map(\.id) else { return }

        var group: UndoGroup?
        var actionName = ""
        for (old, new) in zip(oldBlocks, blocks) where old != new {
            if old.style != new.style {
                group = .style(new.id)
                actionName = "Text Style"
            } else if old.center != new.center {
                group = .placement(new.id)
                actionName = "Move Block"
            } else {
                closeUndoGroup()
                return
            }
        }

        guard let group else { return }
        if openUndoGroup != group {
            pushUndo(actionName, snapshot: Snapshot(video: video, blocks: oldBlocks, selectedIndex: selectedIndex))
            openUndoGroup = group
        }
        scheduleUndoGroupClose()
    }

    /// A group stays open until the edits stop. Restarting the timer per edit
    /// mirrors `scheduleRender`, and costs the same: one task, replaced.
    private func scheduleUndoGroupClose() {
        undoGroupCloser?.cancel()
        undoGroupCloser = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Motion.undoCoalesce))
            guard !Task.isCancelled else { return }
            self?.openUndoGroup = nil
        }
    }

    private func closeUndoGroup() {
        undoGroupCloser?.cancel()
        undoGroupCloser = nil
        openUndoGroup = nil
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
        registerUndo("Add Block")
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
        registerUndo("Remove Block")
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

    private func handleBlocksChange(from oldBlocks: [OverlayBlock]) {
        registerUndoForEdit(from: oldBlocks)
        refreshOverlays()
        persistSelectedStyle()
    }

    /// What carries to the next launch is the *selected* block's style, which
    /// is a rule that can be stated in one sentence. Selection changes reach
    /// this too, so switching blocks and quitting keeps what is on screen
    /// rather than what was last typed into.
    private func persistSelectedStyle() {
        let style = selectedBlock.style
        guard style != lastSavedStyle else { return }
        SettingsStore.save(style)
        lastSavedStyle = style
    }

    /// Rasterizing a block is proportional to the video's resolution—on 4K
    /// footage it is a bitmap several thousand pixels wide—so it happens off
    /// the main actor and after a short coalescing delay. Typing a caption and
    /// dragging a slider are the two hottest paths in the app, and neither can
    /// afford to block on drawing text.
    private func refreshOverlays() {
        guard let video else {
            cancelRenders()
            renderCache = [:]
            return
        }

        let live = Set(blocks.map(\.id))
        for (id, task) in renderTasks where !live.contains(id) {
            task.cancel()
            renderTasks[id] = nil
        }

        var kept: [UUID: CachedRender] = [:]
        for block in blocks {
            let signature = signature(for: block, videoSize: video.displaySize)
            if let cached = renderCache[block.id], cached.signature == signature {
                kept[block.id] = cached
                continue
            }
            // Hold the previous bitmap while the new one is drawn, so the
            // preview never blinks empty between keystrokes.
            kept[block.id] = renderCache[block.id]
            scheduleRender(block, signature: signature, videoSize: video.displaySize)
        }
        renderCache = kept
    }

    private func signature(for block: OverlayBlock, videoSize: CGSize) -> Int {
        var hasher = Hasher()
        hasher.combine(block.text)
        hasher.combine(block.style)
        hasher.combine(videoSize.width)
        hasher.combine(videoSize.height)
        return hasher.finalize()
    }

    private func scheduleRender(_ block: OverlayBlock, signature: Int, videoSize: CGSize) {
        renderTasks[block.id]?.cancel()
        let id = block.id
        let text = block.text
        let style = block.style
        renderTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Motion.renderCoalesce))
            guard !Task.isCancelled else { return }
            let overlay = await Task.detached(priority: .userInitiated) {
                OverlayRenderer.renderBlock(text: text, style: style, videoSize: videoSize)
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.renderTasks[id] != nil else { return }
                self.renderCache[id] = CachedRender(signature: signature, overlay: overlay)
                self.renderTasks[id] = nil
            }
        }
    }

    private func cancelRenders() {
        renderTasks.values.forEach { $0.cancel() }
        renderTasks = [:]
    }

    // MARK: - Destructive actions

    /// Every path that discards a video or a block goes through one of these
    /// two requests, and the private half of each is where the undo step is
    /// registered. That is why `clearVideo` and `removeSelectedBlock` stay
    /// private: a caller reaching past them would throw away typed text with
    /// no way back.
    ///
    /// There is no confirmation prompt any more, and deliberately so. A
    /// warning and an undo stack are two answers to the same question, and the
    /// prompt was the worse one—it charged a click on the app's most common
    /// path for a mistake that Command-Z now takes back completely.
    func requestClearVideo() {
        guard video != nil else { return }
        clearVideo()
    }

    func requestRemoveSelectedBlock() {
        guard blocks.count > 1 else { return }
        removeSelectedBlock()
    }

    // MARK: - Loading

    /// Prompts for a video. Lives here rather than beside a view because the
    /// drop prompt, both sidebar buttons, and the File menu all reach it.
    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Matches the command that opened it, which is state-dependent: the
        // drop screen and the File menu both say Open, the sidebar says
        // Replace. One action, one name, wherever it is reached from.
        panel.title = video == nil ? "Open Video" : "Replace Video"
        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(from: url)
        }
    }

    func loadVideo(from url: URL) {
        guard Self.isAcceptableVideo(url: url) else {
            failure = StoryFailure(loading: .unsupportedType)
            return
        }
        loadTask?.cancel()
        loadTask = Task {
            do {
                let info = try await VideoInfo.probe(url: url)
                // A second drop landing while this probe ran wins; this one
                // must not overwrite it on the way out.
                try Task.checkCancellation()
                adopt(info)
            } catch is CancellationError {
                // Superseded by a newer load; leave the newer one alone.
            } catch let error as VideoInfo.ProbeError {
                failure = StoryFailure(loading: error)
            } catch {
                failure = StoryFailure(loading: .unreadable(error.localizedDescription))
            }
        }
    }

    /// Takes on an already probed video. Undoing a clear comes back through
    /// here rather than through `loadVideo`, because the probe's answer is
    /// state we still hold—making the user wait for it again would be work
    /// done twice for a result that cannot have changed.
    private func adopt(_ info: VideoInfo) {
        pause()
        video = info
        player.replaceCurrentItem(with: AVPlayerItem(asset: AVURLAsset(url: info.url)))
        currentTime = 0
        installLoopObserver()
        refreshOverlays()
    }

    static func isAcceptableVideo(url: URL) -> Bool {
        allowedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Unloads the video and returns to the drop screen, clearing the story
    /// text back to a single empty block. Styling carries over, since those
    /// settings are meant to persist.
    private func clearVideo() {
        registerUndo("Unload Video")
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
        cancelRenders()
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

    /// Deliberately independent of the preview's render cache: whether there
    /// is something to export is a fact about the text, not about whether a
    /// bitmap has finished drawing. The exporter rasterizes its own overlay at
    /// the output resolution anyway.
    var canExport: Bool {
        video != nil && hasStoryText && exportTask == nil
    }

    var isExporting: Bool {
        if case .exporting = exportPhase { return true }
        return false
    }

    /// Prompts for a destination, then runs the export off the main actor.
    func beginExport() {
        guard let video, hasStoryText else { return }
        let blocks = self.blocks
        let resolution = exportResolution
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
                    blocks: blocks,
                    resolution: resolution,
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
                // The sheet showing progress becomes the sheet showing why it
                // stopped, in place—see `MainWindowView`.
                exportPhase = .idle
                failure = StoryFailure(exporting: error)
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
