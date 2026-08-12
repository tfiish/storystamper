import SwiftUI

struct ContentView: View {
    @State private var project = StoryProject()

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

    var body: some View {
        HStack(spacing: 0) {
            SourceSidebarView(project: project)
            Divider()
            VideoPreviewView(project: project)
                .frame(minWidth: Metrics.minPreviewWidth, maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            StyleSidebarView(project: project)
        }
        .frame(minWidth: Metrics.minWindowWidth, minHeight: Metrics.minWindowHeight)
        .sheet(isPresented: exportSheetVisible) {
            ExportStatusView(project: project)
                .interactiveDismissDisabled(isExporting)
        }
        .alert(
            "Could Not Load Video",
            isPresented: Binding(
                get: { project.loadErrorMessage != nil },
                set: { if !$0 { project.loadErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(project.loadErrorMessage ?? "")
        }
    }

    private var isExporting: Bool {
        if case .exporting = project.exportPhase { return true }
        return false
    }
}
