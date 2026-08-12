import SwiftUI

struct MainWindowView: View {
    @Bindable private var project = StoryProject.shared

    private var exportSheetVisible: Binding<Bool> {
        Binding(
            get: { project.exportPhase != .idle },
            set: { visible in
                if !visible {
                    project.finishExport()
                }
            }
        )
    }

    private var confirmation: Binding<ConfirmationRequest?> {
        Binding(
            get: { project.pendingConfirmation },
            set: { if $0 == nil { project.cancelConfirmation() } }
        )
    }

    var body: some View {
        panes
            .sheet(isPresented: exportSheetVisible) {
                ExportStatusView(project: project)
                    .interactiveDismissDisabled(project.isExporting)
            }
            .alert(
                project.loadError?.alertTitle ?? "Could Not Load Video",
                isPresented: Binding(
                    get: { project.loadError != nil },
                    set: { if !$0 { project.loadError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(project.loadError?.localizedDescription ?? "")
            }
    }

    /// The confirmation sheet hangs off the inner container rather than
    /// alongside the export sheet, because two `.sheet` modifiers on one view
    /// contend for the same presentation slot.
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
        .sheet(item: confirmation) { request in
            ConfirmationSheet(
                request: request,
                onCancel: { project.cancelConfirmation() },
                onConfirm: { suppress in project.resolveConfirmation(suppressFuture: suppress) }
            )
        }
    }
}
