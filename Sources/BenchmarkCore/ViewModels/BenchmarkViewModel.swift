import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import AVFoundation

@MainActor
public final class BenchmarkViewModel: ObservableObject {
    @Published public var project: BenchmarkProject
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var headerProgress: Double = 1.0
    @Published public var containerProgress: Double = 1.0
    @Published public var rowProgresses: [UUID: Double] = [:]
    @Published public var rowNumberProgresses: [UUID: Double] = [:]
    @Published public var showExportSheet: Bool = false
    @Published public var showSettingsSheet: Bool = false
    @Published public var cacheSizeFormatted: String = "計算中..."
    @Published public var cacheActionMessage: String? = nil
    
    private var timer: AnyCancellable?
    private let fps: Double = 60.0
    
    public init() {
        self.project = BenchmarkViewModel.createSampleProject()
        self.resetAnimation()
        self.refreshCacheSize()
    }
    
    // MARK: - Cache Management
    public func refreshCacheSize() {
        let bytes = CacheService.shared.calculateCacheSize()
        self.cacheSizeFormatted = CacheService.shared.formatBytes(bytes)
    }
    
    public func clearCache() {
        let result = CacheService.shared.clearCache()
        self.refreshCacheSize()
        self.cacheActionMessage = result.message
    }
    
    // MARK: - Animation Timeline Calculation
    public var totalDuration: Double {
        let itemsCount = project.items.count
        let lastItemStart = 0.2 + Double(max(0, itemsCount - 1)) * project.animationConfig.staggeredDelay
        let animDuration = project.animationConfig.duration
        let hold = project.animationConfig.holdDuration
        let chartDuration = lastItemStart + animDuration + hold
        
        // 若用戶匯入長於動畫的影片時，且開啟背景繼續播放：背景繼續播放直到影片結束
        if project.backgroundMode == .customMedia,
           project.customVideoConfig.extendPlaybackUntilVideoEnds,
           let path = project.customMediaFilePath,
           FileManager.default.fileExists(atPath: path) {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            if ["mp4", "mov", "m4v"].contains(ext) {
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                if !durationSeconds.isNaN && durationSeconds > 0 {
                    let startT = project.customVideoConfig.trimStartTime
                    let endT = project.customVideoConfig.trimEndTime > startT ? project.customVideoConfig.trimEndTime : durationSeconds
                    let videoLen = max(0.1, endT - startT)
                    if videoLen > chartDuration {
                        return videoLen
                    }
                }
            }
        }
        
        return chartDuration
    }
    
    // MARK: - Playback Controls
    public func playAnimation() {
        stopTimer()
        currentTime = 0.0
        isPlaying = true
        updateProgresses(for: 0.0)
        
        let interval = 1.0 / fps
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.currentTime += interval
                self.updateProgresses(for: self.currentTime)
                
                if self.currentTime >= self.totalDuration {
                    self.currentTime = self.totalDuration
                    self.isPlaying = false
                    self.stopTimer()
                    self.setFinalState()
                }
            }
    }
    
    public func resetAnimation() {
        stopTimer()
        isPlaying = false
        currentTime = totalDuration
        setFinalState()
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func updateProgresses(for time: Double) {
        // 1. Header fade-in + slight slide up
        headerProgress = AnimationCurves.progress(
            at: time,
            start: 0.0,
            duration: 0.4,
            style: .easeOut
        )
        
        // 2. Container glass fade-in
        containerProgress = AnimationCurves.progress(
            at: time,
            start: 0.08,
            duration: 0.4,
            style: .easeOut
        )
        
        // 3. Staggered Row animations
        var newRowProgresses: [UUID: Double] = [:]
        var newNumberProgresses: [UUID: Double] = [:]
        for (i, item) in project.items.enumerated() {
            let itemStart = 0.18 + Double(i) * project.animationConfig.staggeredDelay
            // Bar progress with spring / burst overshoot physics
            let p = AnimationCurves.progress(
                at: time,
                start: itemStart,
                duration: project.animationConfig.duration,
                style: project.animationConfig.style,
                damping: project.animationConfig.springDamping,
                response: project.animationConfig.springResponse
            )
            newRowProgresses[item.id] = p
            
            // Strictly monotonic number counter progress (never dips or rolls backwards)
            let np = AnimationCurves.numberCounterProgress(
                at: time,
                start: itemStart,
                duration: project.animationConfig.duration
            )
            newNumberProgresses[item.id] = np
        }
        self.rowProgresses = newRowProgresses
        self.rowNumberProgresses = newNumberProgresses
    }
    
    private func setFinalState() {
        headerProgress = 1.0
        containerProgress = 1.0
        var fullProgresses: [UUID: Double] = [:]
        for item in project.items {
            fullProgresses[item.id] = 1.0
        }
        self.rowProgresses = fullProgresses
        self.rowNumberProgresses = fullProgresses
    }
    
    // MARK: - Save / Load Project JSON
    public func openSaveDialog() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.title = l10n("儲存基準測試專案檔", "Save Benchmark Project File")
        panel.nameFieldStringValue = "BenchmarkProject.json"
        
        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            self.saveProject(to: url)
        }
    }
    
    public func saveProject(to url: URL) {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(project)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save project: \(error)")
            let alert = NSAlert()
            alert.messageText = l10n("儲存專案失敗", "Save Project Failed")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    public func openLoadDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .plainText, .data]
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = l10n("開啟基準測試專案檔", "Open Benchmark Project File")
        
        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            self.loadProject(from: url)
        }
    }
    
    public func loadProject(from url: URL) {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode(BenchmarkProject.self, from: data)
            self.project = loaded
            self.resetAnimation()
        } catch {
            print("Failed to load project: \(error)")
            let alert = NSAlert()
            alert.messageText = l10n("開啟專案檔失敗", "Failed to Open Project")
            alert.informativeText = "\(url.lastPathComponent)：\(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    public func loadSampleProject() {
        self.project = BenchmarkViewModel.createSampleProject()
        self.resetAnimation()
    }
    
    // MARK: - Default Sample Project
    public static func createSampleProject() -> BenchmarkProject {
        let dimPower = BenchmarkDimension(
            name: "SoC功耗 (W)",
            unit: "W",
            maxValue: 100.0,
            decimalPlaces: 1,
            isBlankPlaceholder: false
        )
        let dimNoise = BenchmarkDimension(
            name: "噪音 (dB)",
            unit: "dB",
            maxValue: 60.0,
            decimalPlaces: 0,
            isBlankPlaceholder: false
        )
        
        let item1 = BenchmarkItem(
            title: "產品 A",
            subtitle: "規格 A",
            themePalette: .purple,
            values: [
                dimPower.id.uuidString: 87.0,
                dimNoise.id.uuidString: 48.0
            ],
            annotationText: "8400 rpm / 9072 rpm"
        )
        
        let item2 = BenchmarkItem(
            title: "產品 B",
            subtitle: "規格 B",
            themePalette: .blue,
            values: [
                dimPower.id.uuidString: 92.5,
                dimNoise.id.uuidString: 52.0
            ],
            annotationText: "7800 rpm / 8400 rpm"
        )
        
        return BenchmarkProject(
            version: "1.0",
            header: HeaderConfig(
                mainTitle: "Cinebench R23 + 3Dmark SNL 解熱測試",
                subtitle: "高電量模式 + 風扇滿轉",
                iconSymbol: "cpu.fill"
            ),
            dimensions: [dimPower, dimNoise],
            items: [item1, item2],
            chartType: .horizontalBar,
            backgroundMode: .transparent,
            container: ContainerConfig(
                glassMode: .dark,
                cornerRadius: 22.0,
                showHighlightBorder: true,
                showTopAnnotations: true
            ),
            animationConfig: AnimationConfig(
                style: .spring,
                duration: 1.6,
                springDamping: 0.75,
                springResponse: 0.8,
                staggeredDelay: 0.08
            ),
            export: ExportConfig(
                format: .mov,
                codec: .proRes4444,
                resolution: .p1080,
                fps: 60,
                bitrateMbps: 25.0,
                holdDuration: 2.0,
                enableFastOptimization: true
            )
        )
    }
}
