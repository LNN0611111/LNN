import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = BenchmarkViewModel()
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            SidebarView(
                project: $viewModel.project,
                isPlaying: viewModel.isPlaying,
                onPlay: { viewModel.playAnimation() },
                onReset: { viewModel.resetAnimation() },
                onSaveProject: { viewModel.openSaveDialog() },
                onLoadProject: { viewModel.openLoadDialog() },
                onLoadSample: { viewModel.loadSampleProject() }
            )
            .frame(minWidth: 340, idealWidth: 380, maxWidth: 500)
            
            CanvasPreviewView(
                project: viewModel.project,
                headerProgress: viewModel.headerProgress,
                containerProgress: viewModel.containerProgress,
                rowProgresses: viewModel.rowProgresses,
                numberProgresses: viewModel.rowNumberProgresses,
                isPlaying: viewModel.isPlaying,
                currentTime: viewModel.currentTime,
                totalDuration: viewModel.totalDuration,
                onPlay: { viewModel.playAnimation() },
                onReset: { viewModel.resetAnimation() },
                onExport: { viewModel.showExportSheet = true }
            )
            .frame(minWidth: 640)
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            ExportModalView(
                exportConfig: $viewModel.project.export,
                project: viewModel.project,
                isPresented: $viewModel.showExportSheet
            )
        }
        .sheet(isPresented: $viewModel.showSettingsSheet) {
            SettingsModalView(
                project: $viewModel.project,
                isPresented: $viewModel.showSettingsSheet
            )
        }
        .frame(minWidth: 1080, minHeight: 680)
        .onOpenURL { url in
            viewModel.loadProject(from: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenBenchmarkProjectFile"))) { notif in
            if let url = notif.object as? URL {
                viewModel.loadProject(from: url)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension.lowercased() == "json" || url.pathExtension.lowercased() == "benchmark" {
                    DispatchQueue.main.async {
                        viewModel.loadProject(from: url)
                    }
                }
            }
            return true
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { viewModel.playAnimation() }) {
                    Label(viewModel.isPlaying ? l10n("重播", "Replay") : l10n("播放", "Play"), systemImage: "play.fill")
                }
                .help(l10n("播放進場動畫", "Play animation"))
                
                Button(action: { viewModel.resetAnimation() }) {
                    Label(l10n("重置", "Reset"), systemImage: "arrow.counterclockwise")
                }
                .help(l10n("重置動畫狀態", "Reset animation"))
                
                Divider()
                
                Button(action: { viewModel.openSaveDialog() }) {
                    Label(l10n("儲存", "Save"), systemImage: "square.and.arrow.down")
                }
                .help(l10n("儲存專案檔 (.json)", "Save project JSON"))
                
                Button(action: { viewModel.openLoadDialog() }) {
                    Label(l10n("開啟", "Open"), systemImage: "folder")
                }
                .help(l10n("讀取專案檔 (.json)", "Load project JSON"))
                
                Divider()
                
                Button(action: { viewModel.showExportSheet = true }) {
                    Label(l10n("匯出", "Export"), systemImage: "square.and.arrow.up")
                }
                .help(l10n("匯出影片或圖檔 (MOV, MP4, PNG)", "Export video or snapshots"))
                
                Divider()
                
                Button(action: { viewModel.showSettingsSheet = true }) {
                    Label(l10n("設定", "Settings"), systemImage: "gearshape.fill")
                }
                .help(l10n("偏好設定 (字體、圖表模式、語言、清除快取)", "Settings (Fonts, Chart Style, Language, Cache)"))
            }
        }
    }
}
