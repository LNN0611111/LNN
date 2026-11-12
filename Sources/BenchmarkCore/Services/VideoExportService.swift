import Foundation
import AVFoundation
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import VideoToolbox
import AppKit

@MainActor
public final class VideoExportService {
    public static let shared = VideoExportService()
    
    private var isCancelled: Bool = false
    
    private init() {}
    
    public enum ExportError: LocalizedError {
        case writerInitializationFailed(String)
        case inputNotReady
        case pixelBufferCreationFailed
        case renderFailed(Int)
        case cancelled
        
        public var errorDescription: String? {
            switch self {
            case .writerInitializationFailed(let msg): return l10n("影片編碼器初始化失敗: \(msg)", "Encoder initialization failed: \(msg)")
            case .inputNotReady: return l10n("編碼管道未就緒", "Encoding pipeline not ready")
            case .pixelBufferCreationFailed: return l10n("無法建立畫面緩衝區", "Failed to create pixel buffer")
            case .renderFailed(let f): return l10n("第 \(f) 幀渲染失敗", "Frame \(f) render failed")
            case .cancelled: return l10n("匯出已被使用者取消", "Export cancelled by user")
            }
        }
    }
    
    /// User initiated cancellation
    public func cancelExport() {
        isCancelled = true
    }
    
    /// Export benchmark video or snapshot with Apple Silicon M-Chip hardware optimizations
    public func export(
        project: BenchmarkProject,
        outputURL: URL,
        onProgress: @escaping (Double, String) -> Void
    ) async throws {
        isCancelled = false
        let exportConfig = project.export
        let resolution = exportConfig.resolution.size(for: project.aspectRatio)
        let width = Int(resolution.width)
        let height = Int(resolution.height)
        let fps = exportConfig.fps
        
        // Apple Silicon M-Chip Multi-Core Scheduler Elevation:
        // Set thread priority to QOS_CLASS_USER_INTERACTIVE to mobilize all cores (Super-cores, P-cores, and E-cores)
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        
        // Remove existing file if exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Calculate animation timeline
        let itemsCount = project.items.count
        let lastItemStart = 0.2 + Double(max(0, itemsCount - 1)) * project.animationConfig.staggeredDelay
        let animDuration = project.animationConfig.duration
        let holdDuration = max(0.0, exportConfig.holdDuration)
        let animationEndTime = lastItemStart + animDuration
        var totalDuration = animationEndTime + holdDuration
        
        // 若用戶匯入長於動畫的自訂背景影片，且開啟接續播放：計算並延長匯出長度
        var isCustomVideoBackground = false
        var videoImageGenerator: AVAssetImageGenerator? = nil
        
        if project.backgroundMode == .customMedia,
           let path = project.customMediaFilePath,
           FileManager.default.fileExists(atPath: path) {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            if ["mp4", "mov", "m4v"].contains(ext) {
                isCustomVideoBackground = true
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                let gen = AVAssetImageGenerator(asset: asset)
                gen.appliesPreferredTrackTransform = true
                gen.requestedTimeToleranceBefore = .zero
                gen.requestedTimeToleranceAfter = .zero
                videoImageGenerator = gen
                
                if project.customVideoConfig.extendPlaybackUntilVideoEnds {
                    let durationSeconds = CMTimeGetSeconds(asset.duration)
                    if !durationSeconds.isNaN && durationSeconds > 0 {
                        let startT = project.customVideoConfig.trimStartTime
                        let endT = project.customVideoConfig.trimEndTime > startT ? project.customVideoConfig.trimEndTime : durationSeconds
                        let videoLen = max(0.1, endT - startT)
                        if videoLen > totalDuration {
                            totalDuration = videoLen
                        }
                    }
                }
            }
        }
        
        let isAnimatedBackground = isCustomVideoBackground || (project.backgroundMode == .animatedPattern)
        
        let totalFrames = max(1, Int(ceil(totalDuration * Double(fps))))
        
        // MARK: - Handle Single PNG Snapshot
        if exportConfig.format == .pngSnapshot {
            onProgress(0.5, l10n("正在渲染高畫質靜態圖檔 (\(width) × \(height))...", "Rendering high quality snapshot (\(width) × \(height))..."))
            let cgImage = try renderFrame(at: totalDuration, project: project, size: resolution)
            try savePNG(cgImage: cgImage, to: outputURL)
            onProgress(1.0, l10n("圖檔已成功儲存！", "Snapshot successfully saved!"))
            return
        }
        
        // MARK: - Handle PNG Image Sequence
        if exportConfig.format == .pngSequence {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            var lastSettledImage: CGImage? = nil
            
            for f in 0..<totalFrames {
                if isCancelled {
                    throw ExportError.cancelled
                }
                
                let time = Double(f) / Double(fps)
                let cgImage: CGImage
                
                if exportConfig.enableFastOptimization && !isAnimatedBackground, time >= animationEndTime, let cached = lastSettledImage {
                    cgImage = cached
                } else {
                    cgImage = try renderFrame(at: time, project: project, size: resolution)
                    if time >= animationEndTime && !isAnimatedBackground {
                        lastSettledImage = cgImage
                    }
                }
                
                let frameFileName = String(format: "frame_%04d.png", f + 1)
                let frameURL = outputURL.appendingPathComponent(frameFileName)
                try savePNG(cgImage: cgImage, to: frameURL)
                
                let progress = Double(f + 1) / Double(totalFrames)
                onProgress(progress, l10n("正在導出序列幀: \(f + 1)/\(totalFrames)", "Exporting frame sequence: \(f + 1)/\(totalFrames)"))
                
                // Keep UI responsive during sequence export
                while let event = NSApp.nextEvent(matching: .any, until: .distantPast, inMode: .default, dequeue: true) {
                    NSApp.sendEvent(event)
                }
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
            onProgress(1.0, l10n("PNG 序列幀已成功匯出！", "PNG sequence successfully exported!"))
            return
        }
        
        // MARK: - Handle MOV / MP4 Video Export (Apple Silicon Hardware Accelerated)
        var effectiveFormat = exportConfig.format
        var effectiveCodec = exportConfig.codec
        
        // Safety Auto-Healing: Ensure codec and container compatibility
        if effectiveFormat == .mp4 {
            if effectiveCodec.requiresMOVContainer {
                effectiveFormat = .mov
            } else if effectiveCodec == .hevcWithAlpha {
                if project.backgroundMode == .transparent {
                    effectiveFormat = .mov
                } else {
                    effectiveCodec = .h264
                }
            }
        }
        
        var actualOutputURL = outputURL
        let targetExt = effectiveFormat.fileExtension
        if actualOutputURL.pathExtension.lowercased() != targetExt.lowercased() {
            actualOutputURL = actualOutputURL.deletingPathExtension().appendingPathExtension(targetExt)
        }
        
        try? FileManager.default.removeItem(at: actualOutputURL)
        
        let fileType: AVFileType = (effectiveFormat == .mp4) ? .mp4 : .mov
        guard let writer = try? AVAssetWriter(outputURL: actualOutputURL, fileType: fileType) else {
            throw ExportError.writerInitializationFailed(l10n("無法建立 AVAssetWriter，請檢查輸出路徑與權限", "Unable to create AVAssetWriter. Check path and permissions."))
        }
        
        // Configure Video Compression Settings
        var videoSettings: [String: Any] = [
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        switch effectiveCodec {
        case .proRes4444:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.proRes4444
        case .proRes422:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.proRes422
        case .hevcWithAlpha:
            if fileType == .mov {
                videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevcWithAlpha
            } else {
                videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevc
            }
        case .h264:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.h264
            let bitrate = max(5_000_000, Int(exportConfig.bitrateMbps * 1_000_000))
            let compressionProps: [String: Any] = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                kVTCompressionPropertyKey_H264EntropyMode as String: kVTH264EntropyMode_CABAC,
                kVTCompressionPropertyKey_RealTime as String: false
            ]
            videoSettings[AVVideoCompressionPropertiesKey] = compressionProps
        }
        
        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            throw ExportError.writerInitializationFailed(l10n("編碼器不支援此輸出設定或解析度 (\(width)x\(height))", "Codec does not support output settings (\(width)x\(height))"))
        }
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        // Apple Silicon M-Chip Hardware Optimization:
        // Use IOSurface and Metal compatibility for direct DMA transfer to Apple Silicon Media Engine
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        guard writer.canAdd(writerInput) else {
            throw ExportError.writerInitializationFailed(l10n("無法添加 Video Input 至編碼器 (請確認 \(effectiveCodec.rawValue) 是否支援 \(fileType.rawValue) 容器)", "Cannot add Video Input to encoder for \(effectiveCodec.rawValue) in \(fileType.rawValue)"))
        }
        writer.add(writerInput)
        
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: resolution),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(
            rootView: makeExportView(project: project, time: 0, size: resolution)
        )
        hostingView.frame = CGRect(origin: .zero, size: resolution)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        
        // Fast optimization & Multi-Core Parallel Batch Pipeline
        let activeCores = ProcessInfo.processInfo.activeProcessorCount
        let batchSize = min(16, max(4, activeCores))
        
        var frameIndex = 0
        var cachedRep: NSBitmapImageRep? = nil
        var lastSettledCGImage: CGImage? = nil
        var lastSettledPixelBuffer: CVPixelBuffer? = nil
        
        while frameIndex < totalFrames {
            if isCancelled {
                writer.cancelWriting()
                window.contentView = nil
                window.orderOut(nil)
                try? FileManager.default.removeItem(at: actualOutputURL)
                throw ExportError.cancelled
            }
            
            if writer.status == .failed || writer.status == .cancelled {
                throw writer.error ?? ExportError.writerInitializationFailed("編碼器執行中發生錯誤 (status: \(writer.status.rawValue))")
            }
            
            let currentBatchCount = min(batchSize, totalFrames - frameIndex)
            let firstFrameTime = Double(frameIndex) / Double(fps)
            
            // 快顯路徑：若整個批次均處於定格時段且非動態平移背景，直接調用零拷貝/極速緩衝區複用
            if exportConfig.enableFastOptimization && !isAnimatedBackground && firstFrameTime >= animationEndTime, let settledPB = lastSettledPixelBuffer {
                for b in 0..<currentBatchCount {
                    let f = frameIndex + b
                    let pts = CMTime(value: Int64(f), timescale: Int32(fps))
                    
                    var waitCount = 0
                    while !writerInput.isReadyForMoreMediaData {
                        if isCancelled { throw ExportError.cancelled }
                        try await Task.sleep(nanoseconds: 2_000_000)
                        waitCount += 1
                        if waitCount > 2000 {
                            throw writer.error ?? ExportError.writerInitializationFailed("編碼器逾時未就緒 (Frame \(f))")
                        }
                    }
                    
                    if let cloned = self.clonePixelBuffer(settledPB, pool: adaptor.pixelBufferPool, width: width, height: height) {
                        let ok = adaptor.append(cloned, withPresentationTime: pts)
                        if !ok {
                            throw writer.error ?? ExportError.writerInitializationFailed("寫入快取影格失敗 (Frame \(f))")
                        }
                    }
                }
                
                frameIndex += currentBatchCount
                let progress = Double(frameIndex) / Double(totalFrames)
                let progressPercent = Int(progress * 100)
                onProgress(progress, l10n("影片編碼中: \(progressPercent)%", "Encoding video: \(progressPercent)%"))
                
                while let event = NSApp.nextEvent(matching: .any, until: .distantPast, inMode: .default, dequeue: true) {
                    NSApp.sendEvent(event)
                }
                continue
            }
            
            // 階段一：逐幀畫面生成（優先調用 macOS 13+ ImageRenderer 硬體著色，失敗則回退至 HostingView）
            var batchImages = [CGImage?](repeating: nil, count: currentBatchCount)
            var batchTimes = [Double](repeating: 0.0, count: currentBatchCount)
            var batchPTS = [CMTime](repeating: .zero, count: currentBatchCount)
            
            for b in 0..<currentBatchCount {
                let f = frameIndex + b
                let time = Double(f) / Double(fps)
                let pts = CMTime(value: Int64(f), timescale: Int32(fps))
                batchTimes[b] = time
                batchPTS[b] = pts
                
                if exportConfig.enableFastOptimization && !isAnimatedBackground && time >= animationEndTime, let cached = lastSettledCGImage {
                    batchImages[b] = cached
                } else {
                    var currentVideoFrame: CGImage? = nil
                    if let gen = videoImageGenerator {
                        let targetSec = project.customVideoConfig.trimStartTime + time
                        let cmT = CMTime(seconds: targetSec, preferredTimescale: 600)
                        currentVideoFrame = try? gen.copyCGImage(at: cmT, actualTime: nil)
                    }
                    
                    let exportView = makeExportView(project: project, time: time, size: resolution, videoFrame: currentVideoFrame)
                    var renderedImg: CGImage? = nil
                    
                    if #available(macOS 13.0, *) {
                        let renderer = ImageRenderer(content: exportView)
                        renderer.scale = 1.0
                        renderedImg = renderer.cgImage
                    }
                    
                    if renderedImg == nil {
                        hostingView.rootView = exportView
                        hostingView.layoutSubtreeIfNeeded()
                        if cachedRep == nil {
                            cachedRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
                        }
                        if let rep = cachedRep {
                            hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
                            renderedImg = rep.cgImage
                        }
                    }
                    
                    guard let finalImg = renderedImg else {
                        throw ExportError.renderFailed(f)
                    }
                    
                    if time >= animationEndTime && lastSettledCGImage == nil && !isAnimatedBackground {
                        lastSettledCGImage = finalImg
                    }
                    batchImages[b] = finalImg
                }
            }
            
            // 階段二：調用全部 CPU 核心並行轉碼（DispatchQueue.concurrentPerform 滿載所有超大核、大核與效能核）
            var batchPixelBuffers = [CVPixelBuffer?](repeating: nil, count: currentBatchCount)
            let pool = adaptor.pixelBufferPool
            
            DispatchQueue.concurrentPerform(iterations: currentBatchCount) { b in
                guard let img = batchImages[b] else { return }
                batchPixelBuffers[b] = self.pixelBuffer(from: img, width: width, height: height, pool: pool)
            }
            
            // 階段三：按幀序直通 VideoToolbox Media Engine 硬體編碼器
            for b in 0..<currentBatchCount {
                let f = frameIndex + b
                guard let pb = batchPixelBuffers[b] else {
                    throw ExportError.pixelBufferCreationFailed
                }
                
                if batchTimes[b] >= animationEndTime && lastSettledPixelBuffer == nil && !isAnimatedBackground {
                    lastSettledPixelBuffer = pb
                }
                
                var waitCount = 0
                while !writerInput.isReadyForMoreMediaData {
                    if isCancelled { throw ExportError.cancelled }
                    try await Task.sleep(nanoseconds: 2_000_000)
                    waitCount += 1
                    if waitCount > 2000 {
                        throw writer.error ?? ExportError.writerInitializationFailed("編碼器逾時未就緒 (Frame \(f))")
                    }
                }
                
                let ok = adaptor.append(pb, withPresentationTime: batchPTS[b])
                if !ok {
                    throw writer.error ?? ExportError.writerInitializationFailed("寫入影格失敗 (Frame \(f))")
                }
            }
            
            frameIndex += currentBatchCount
            let progress = Double(frameIndex) / Double(totalFrames)
            let progressPercent = Int(progress * 100)
            onProgress(progress, l10n("影片編碼中: \(progressPercent)%", "Encoding video: \(progressPercent)%"))
            
            // 讓主線程平滑處理 UI 事件，保持視窗 100% 靈活響應
            while let event = NSApp.nextEvent(matching: .any, until: .distantPast, inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
        
        window.contentView = nil
        window.orderOut(nil)
        writerInput.markAsFinished()
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                Task { @MainActor in
                    continuation.resume()
                }
            }
        }
        
        if writer.status == .failed {
            throw writer.error ?? ExportError.writerInitializationFailed("影片完成寫入時發生錯誤")
        }
        
        onProgress(1.0, l10n("影片匯出完成！", "Video export complete!"))
    }
    
    // MARK: - Snapshot & Frame Rendering
    private func renderFrame(at time: Double, project: BenchmarkProject, size: CGSize) throws -> CGImage {
        var videoFrame: CGImage? = nil
        if project.backgroundMode == .customMedia,
           let path = project.customMediaFilePath,
           FileManager.default.fileExists(atPath: path),
           ["mp4", "mov", "m4v"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
            gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
            
            let startT = max(0.0, project.customVideoConfig.trimStartTime)
            let rawDuration = CMTimeGetSeconds(asset.duration)
            let videoMax = (rawDuration.isNaN || rawDuration <= 0) ? 10.0 : rawDuration
            let endT = (project.customVideoConfig.trimEndTime > startT) ? min(project.customVideoConfig.trimEndTime, videoMax) : videoMax
            let effectiveSpan = max(0.1, endT - startT)
            let targetSec = startT + time.truncatingRemainder(dividingBy: effectiveSpan)
            videoFrame = try? gen.copyCGImage(at: CMTime(seconds: targetSec, preferredTimescale: 600), actualTime: nil)
        }
        
        let exportView = makeExportView(project: project, time: time, size: size, videoFrame: videoFrame)
        
        if #available(macOS 13.0, *) {
            let renderer = ImageRenderer(content: exportView)
            renderer.scale = 1.0
            if let img = renderer.cgImage {
                return img
            }
        }
        
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: exportView)
        hostingView.frame = CGRect(origin: .zero, size: size)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw ExportError.renderFailed(0)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        guard let cgImage = rep.cgImage else {
            throw ExportError.renderFailed(0)
        }
        
        window.contentView = nil
        window.orderOut(nil)
        return cgImage
    }
    
    private func makeExportView(project: BenchmarkProject, time: Double, size: CGSize, videoFrame: CGImage? = nil) -> some View {
        let (hp, cp, rp, np) = calculateProgresses(for: time, project: project)
        let refSize = project.aspectRatio.referenceSize
        let scale = size.width / refSize.width
        let isDark = (project.container.glassMode == .dark)
        
        return ZStack {
            CanvasContainerView(
                project: project,
                headerProgress: hp,
                containerProgress: cp,
                rowProgresses: rp,
                numberProgresses: np,
                isExportMode: true,
                customExportVideoFrame: videoFrame,
                currentTime: time
            )
            .frame(width: refSize.width, height: refSize.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .frame(width: size.width, height: size.height)
        .preferredColorScheme(isDark ? .dark : .light)
        .environment(\.colorScheme, isDark ? .dark : .light)
    }
    
    private func calculateProgresses(for time: Double, project: BenchmarkProject) -> (
        headerProgress: Double,
        containerProgress: Double,
        rowProgresses: [UUID: Double],
        numberProgresses: [UUID: Double]
    ) {
        let hp = AnimationCurves.progress(at: time, start: 0.0, duration: 0.4, style: .easeOut)
        let cp = AnimationCurves.progress(at: time, start: 0.08, duration: 0.4, style: .easeOut)
        
        var rp: [UUID: Double] = [:]
        var np: [UUID: Double] = [:]
        
        let anim = project.animationConfig
        let baseDelay = 0.2
        
        for (index, item) in project.items.enumerated() {
            let itemStart = baseDelay + Double(index) * anim.staggeredDelay
            
            // Progress for the physical capsule bar (supports overshoot & bounce)
            let barProg = AnimationCurves.progress(
                at: time,
                start: itemStart,
                duration: anim.duration,
                style: anim.style,
                damping: anim.springDamping,
                response: anim.springResponse
            )
            rp[item.id] = barProg
            
            // Monotonic progress for the rolling number counter (never drops)
            let numProg = AnimationCurves.numberCounterProgress(
                at: time,
                start: itemStart,
                duration: anim.duration
            )
            np[item.id] = numProg
        }
        
        return (hp, cp, rp, np)
    }
    
    // MARK: - PixelBuffer Pool & Hardware Transfer
    private func pixelBuffer(from image: CGImage, width: Int, height: Int, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        if let pool = pool {
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            if status != kCVReturnSuccess {
                pixelBuffer = nil
            }
        }
        
        if pixelBuffer == nil {
            let attrs: [CFString: Any] = [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
                kCVPixelBufferMetalCompatibilityKey: true
            ]
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attrs as CFDictionary,
                &pixelBuffer
            )
            guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }
            pixelBuffer = pb
        }
        
        guard let pb = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        
        guard let contextData = CVPixelBufferGetBaseAddress(pb) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: contextData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pb
    }
    
    // MARK: - Fast Frame Memory Clone for Settle Frames
    private func clonePixelBuffer(_ src: CVPixelBuffer, pool: CVPixelBufferPool?, width: Int, height: Int) -> CVPixelBuffer? {
        var dst: CVPixelBuffer? = nil
        if let pool = pool {
            _ = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &dst)
        }
        if dst == nil {
            let attrs: [CFString: Any] = [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
                kCVPixelBufferMetalCompatibilityKey: true
            ]
            _ = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &dst)
        }
        guard let dstPB = dst else { return nil }
        
        CVPixelBufferLockBaseAddress(src, .readOnly)
        CVPixelBufferLockBaseAddress(dstPB, [])
        defer {
            CVPixelBufferUnlockBaseAddress(src, .readOnly)
            CVPixelBufferUnlockBaseAddress(dstPB, [])
        }
        
        guard let srcBase = CVPixelBufferGetBaseAddress(src),
              let dstBase = CVPixelBufferGetBaseAddress(dstPB) else { return nil }
        
        let srcBpr = CVPixelBufferGetBytesPerRow(src)
        let dstBpr = CVPixelBufferGetBytesPerRow(dstPB)
        let h = CVPixelBufferGetHeight(src)
        
        if srcBpr == dstBpr {
            memcpy(dstBase, srcBase, srcBpr * h)
        } else {
            let copyBytes = min(srcBpr, dstBpr)
            for row in 0..<h {
                memcpy(dstBase.advanced(by: row * dstBpr), srcBase.advanced(by: row * srcBpr), copyBytes)
            }
        }
        return dstPB
    }
    
    private func savePNG(cgImage: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ExportError.renderFailed(0)
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        if !CGImageDestinationFinalize(destination) {
            throw ExportError.renderFailed(0)
        }
    }
}
