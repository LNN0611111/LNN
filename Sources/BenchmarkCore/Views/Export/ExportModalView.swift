import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public final class ExportViewModel: ObservableObject {
    @Published public var isExporting: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var exportedFileURL: URL?
    @Published public var errorMessage: String?
    
    public init() {}
}

public struct ExportModalView: View {
    @Binding public var exportConfig: ExportConfig
    public var project: BenchmarkProject
    @Binding public var isPresented: Bool
    
    @StateObject private var exportVM = ExportViewModel()
    
    public init(
        exportConfig: Binding<ExportConfig>,
        project: BenchmarkProject,
        isPresented: Binding<Bool>
    ) {
        self._exportConfig = exportConfig
        self.project = project
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                Label(l10n("匯出高畫質影片與圖檔", "Export High Quality Video & Images"), systemImage: "arrow.up.forward.square.fill")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(exportVM.isExporting)
            }
            
            Divider()
            
            if exportVM.isExporting {
                // Exporting progress view
                VStack(spacing: 20) {
                    ProgressView(value: exportVM.progress, total: 1.0)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text(exportVM.statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(exportVM.progress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: cancelExport) {
                            Label(l10n("取消匯出", "Cancel Export"), systemImage: "stop.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.vertical, 24)
            } else if let fileURL = exportVM.exportedFileURL {
                // Success view
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text(l10n("匯出成功！", "Export Successful!"))
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(fileURL.lastPathComponent)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(l10n("在 Finder 中顯示", "Reveal in Finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        Button(l10n("完成", "Done")) {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Options Form
                VStack(alignment: .leading, spacing: 14) {
                    if let err = exportVM.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // 1. Export Format
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n("1. 匯出檔案類型", "1. Export Format"))
                            .font(.system(size: 12, weight: .bold))
                        
                        Picker("", selection: $exportConfig.format) {
                            ForEach(ExportFormat.allCases) { fmt in
                                Text(fmt.rawValue).tag(fmt)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: exportConfig.format) { newFormat in
                            validateFormatAndCodec(format: newFormat)
                        }
                    }
                    
                    // 2. Video Codec (when format is video)
                    if exportConfig.format == .mov || exportConfig.format == .mp4 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(l10n("2. 採取的編碼器", "2. Video Codec"))
                                    .font(.system(size: 12, weight: .bold))
                                if exportConfig.format == .mov && project.backgroundMode == .transparent {
                                    Text(l10n("(建議 ProRes 4444 獲得完美去背透明通道)", "(ProRes 4444 recommended for transparent alpha)"))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: "#A855F7"))
                                } else if exportConfig.format == .mp4 {
                                    Text(l10n("(MP4 格式支援 H.264；ProRes 需使用 MOV 格式)", "(MP4 supports H.264; ProRes requires MOV)"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            let codecs: [ExportCodec] = (exportConfig.format == .mp4)
                                ? [.h264]
                                : ExportCodec.allCases
                                
                            Picker("", selection: $exportConfig.codec) {
                                ForEach(codecs) { c in
                                    Text(c.rawValue).tag(c)
                                }
                            }
                            .pickerStyle(.radioGroup)
                        }
                    }
                    
                    // 3. Resolution & Bitrate
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(l10n("3. 影像畫質 (解析度)", "3. Resolution"))
                                    .font(.system(size: 12, weight: .bold))
                                Text(l10n("比例: \(project.aspectRatio.displayName)", "Ratio: \(project.aspectRatio.displayName)"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Picker("", selection: $exportConfig.resolution) {
                                ForEach(ExportResolution.allCases) { res in
                                    let sz = res.size(for: project.aspectRatio)
                                    Text("\(res.rawValue) (\(Int(sz.width)) × \(Int(sz.height)))").tag(res)
                                }
                            }
                            .labelsHidden()
                        }
                        
                        if exportConfig.codec == .h264 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l10n("影像碼率 (Bitrate)", "Bitrate"))
                                    .font(.system(size: 12, weight: .bold))
                                Picker("", selection: $exportConfig.bitrateMbps) {
                                    Text(l10n("50 Mbps (超高)", "50 Mbps (Ultra)")).tag(50.0)
                                    Text(l10n("25 Mbps (高畫質)", "25 Mbps (High)")).tag(25.0)
                                    Text(l10n("12 Mbps (標準)", "12 Mbps (Standard)")).tag(12.0)
                                }
                                .labelsHidden()
                            }
                        }
                    }
                    
                    // 4. Framerate & Hold
                    if exportConfig.format != .pngSnapshot {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l10n("4. 影片幀率", "4. Frame Rate"))
                                    .font(.system(size: 12, weight: .bold))
                                Picker("", selection: $exportConfig.fps) {
                                    Text(l10n("60 FPS (極致流暢)", "60 FPS (Smooth)")).tag(60)
                                    Text(l10n("30 FPS (標準)", "30 FPS (Standard)")).tag(30)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(l10n("結尾定格展示時間", "Hold Duration"))
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                    TextField("", value: $exportConfig.holdDuration, format: .number.precision(.fractionLength(1...2)))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 52)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .multilineTextAlignment(.trailing)
                                    Text(l10n("秒", "s"))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 4) {
                                    ForEach([0.5, 1.0, 2.0, 3.0, 5.0], id: \.self) { sec in
                                        let isSelected = abs(exportConfig.holdDuration - sec) < 0.05
                                        Button(action: {
                                            exportConfig.holdDuration = sec
                                        }) {
                                            Text(sec == 2.0 ? l10n("2.0s (預設)", "2.0s (Def)") : String(format: "%.1fs", sec))
                                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(isSelected ? Color(hex: "#7C3AED") : Color.white.opacity(0.06))
                                                .foregroundColor(isSelected ? .white : Color(white: 0.7))
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        Toggle(l10n("啟用極速匯出優化 (定格影格去重、記憶體池化加速)", "Enable Fast Optimization (Hold de-duplication, memory pooling)"), isOn: $exportConfig.enableFastOptimization)
                            .font(.system(size: 11))
                            .padding(.top, 2)
                    }
                }
                
                Divider()
                
                // Bottom Action
                HStack {
                    Spacer()
                    Button(l10n("取消", "Cancel")) {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: startExport) {
                        Label(l10n("選擇匯出位置並開始匯出", "Choose Location & Start Export"), systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#7C3AED"))
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(Color(white: 0.12))
        .onAppear {
            validateFormatAndCodec(format: exportConfig.format)
            if exportConfig.holdDuration <= 0 {
                exportConfig.holdDuration = project.animationConfig.holdDuration > 0 ? project.animationConfig.holdDuration : 2.0
            }
        }
    }
    
    private func validateFormatAndCodec(format: ExportFormat) {
        if format == .mp4 && exportConfig.codec.requiresMOVContainer {
            exportConfig.codec = .h264
        }
    }
    
    private func cancelExport() {
        VideoExportService.shared.cancelExport()
        exportVM.isExporting = false
        exportVM.errorMessage = l10n("匯出已取消", "Export cancelled")
    }
    
    private func startExport() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = l10n("選擇檔案匯出位置", "Choose Export Destination")
        
        var effectiveFormat = exportConfig.format
        if effectiveFormat == .mp4 && exportConfig.codec.requiresMOVContainer {
            effectiveFormat = .mov
        }
        
        var ext = effectiveFormat.fileExtension
        if effectiveFormat == .pngSequence {
            ext = "zip"
        }
        
        let ratioClean = project.aspectRatio.displayName.replacingOccurrences(of: ":", with: "_")
        panel.nameFieldStringValue = "Benchmark_\(ratioClean).\(ext)"
        
        switch effectiveFormat {
        case .mov:
            panel.allowedContentTypes = [UTType.quickTimeMovie]
        case .mp4:
            panel.allowedContentTypes = [UTType.mpeg4Movie]
        case .pngSnapshot:
            panel.allowedContentTypes = [UTType.png]
        case .pngSequence:
            panel.allowedContentTypes = [UTType.zip]
        }
        
        panel.begin { response in
            guard response == .OK, let targetURL = panel.url else { return }
            
            self.exportVM.isExporting = true
            self.exportVM.errorMessage = nil
            self.exportVM.progress = 0.0
            self.exportVM.statusMessage = l10n("正在初始化編碼器...", "Initializing encoder...")
            
            Task {
                do {
                    var updatedProject = self.project
                    updatedProject.export = self.exportConfig
                    if self.exportConfig.codec.requiresMOVContainer && updatedProject.export.format == .mp4 {
                        updatedProject.export.format = .mov
                    }
                    
                    try await VideoExportService.shared.export(
                        project: updatedProject,
                        outputURL: targetURL
                    ) { prog, status in
                        self.exportVM.progress = prog
                        self.exportVM.statusMessage = status
                    }
                    
                    self.exportVM.isExporting = false
                    self.exportVM.exportedFileURL = targetURL
                } catch {
                    self.exportVM.isExporting = false
                    self.exportVM.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
