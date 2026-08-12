import SwiftUI

struct MainWindowView: View {
    @Bindable private var project = StoryProject.shared
    /// The window's undo manager. Only a view can see it, so this is where it
    /// is handed to the project, which is where the edits happen.
    @Environment(\.undoManager) private var undoManager

    /// One sheet slot for the export and for failures alike. Two `.sheet`
    /// modifiers on one view contend for the same presentation—and beyond
    /// that, an export that fails should turn into the reason in place,
    /// rather than dismissing one sheet and racing another onto the screen.
    private var modalVisible: Binding<Bool> {
        Binding(
            get: { project.failure != nil || project.exportPhase != .idle },
            set: { visible in
                if !visible {
                    project.failure = nil
                    project.finishExport()
                }
            }
        )
    }

    var body: some View {
        panes
            .sheet(isPresented: modalVisible) {
                modalContent
                    .interactiveDismissDisabled(project.isExporting)
            }
            .onChange(of: undoManager, initial: true) { _, manager in
                project.undoManager = manager
            }
    }

    @ViewBuilder
    private var modalContent: some View {
        // Failure wins: it is only ever set as an export leaves the running
        // state, so the sheet already on screen is the one to replace.
        if let failure = project.failure {
            FailureSheet(failure: failure) { project.failure = nil }
        } else {
            ExportStatusView(project: project)
        }
    }

    private var panes: some View {
        HStack(spacing: 0) {
            SourceSidebarView(project: project)
            Divider()
            VideoPreviewView(project: project)
                .frame(minWidth: Metrics.minPreviewWidth, maxWidth: .infinity, maxHeight: .infinity)
            SidebarSplitter(
                width: $project.styleSidebarWidth,
                range: Metrics.styleSidebarRange,
                onCommit: { project.persistStyleSidebarWidth() }
            )
            StyleSidebarView(project: project)
        }
        .frame(minWidth: Metrics.minWindowWidth, minHeight: Metrics.minWindowHeight)
    }
}
