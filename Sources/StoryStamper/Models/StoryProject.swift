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

/// The single source of truth for the app: loaded video, playback state, story
/// text, style, overlay placement, and export lifecycle.
@MainActor
@Observable
final class StoryProject {
    // MARK: - Video

    private(set) var video: VideoInfo?
    let player = AVPlayer()
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    var loadErrorMessage: String?

    // MARK: - Overlay

    var storyText = "" {
        didSet { refreshOverlay() }
    }

    var style = SettingsStore.loadStyle() {
        didSet {
            SettingsStore.save(style)
            refreshOverlay()
        }
    }

    /// Overlay block center in normalized video coordinates (0...1 on each
    /// axis), so window resizes never move the exported position.
    var overlayCenter = CGPoint(x: 0.5, y: 0.5)

    var showSafeArea = SettingsStore.loadShowSafeArea() {
        didSet { SettingsStore.save(showSafeArea: showSafeArea) }
    }

    /// The rendered text block, refreshed on every text or style change.
    private(set) var overlay: RenderedOverlay?

    // MARK: - Export

    var exportPhase: ExportPhase = .idle
    private var exportTask: Task<Void, Never>?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    static let allowedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    init() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
            }
        }
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
                refreshOverlay()
            } catch {
                loadErrorMessage = error.localizedDescription
            }
        }
    }

    static func isAcceptableVideo(url: URL) -> Bool {
        allowedExtensions.contains(url.pathExtension.lowercased())
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

    // MARK: - Overlay placement

    private func refreshOverlay() {
        guard let video else {
            overlay = nil
            return
        }
        overlay = OverlayRenderer.renderBlock(text: storyText, style: style, videoSize: video.displaySize)
    }

    enum QuickPosition {
        case top, center, bottom
    }

    /// Horizontally centered placement with a safe-area-friendly margin.
    func applyQuickPosition(_ position: QuickPosition) {
        guard let video else { return }
        let height = video.displaySize.height
        let blockHalf = (overlay?.pixelSize.height ?? 0) / 2 / height
        let y: Double
        switch position {
        case .top: y = 0.14 + blockHalf
        case .center: y = 0.5
        case .bottom: y = 0.86 - blockHalf
        }
        overlayCenter = OverlayRenderer.clampedCenter(
            CGPoint(x: 0.5, y: y),
            blockSize: overlay?.pixelSize ?? .zero,
            videoSize: video.displaySize
        )
    }

    // MARK: - Export

    var canExport: Bool {
        video != nil && overlay != nil && exportTask == nil
    }

    /// Prompts for a destination, then runs the export off the main actor.
    func beginExport() {
        guard let video, let overlay else { return }
        pause()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = video.url.deletingPathExtension().lastPathComponent + "-story.mp4"
        panel.title = "Export Story Video"
        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        let center = overlayCenter
        exportPhase = .exporting(progress: 0)
        exportTask = Task {
            do {
                try await VideoExporter.export(
                    videoInfo: video,
                    block: overlay,
                    normalizedCenter: center,
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
