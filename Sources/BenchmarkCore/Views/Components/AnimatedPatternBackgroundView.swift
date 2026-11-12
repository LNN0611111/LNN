import SwiftUI
import AppKit

public struct AnimatedPatternBackgroundView: View {
    public var config: AnimatedPatternConfig
    public var isExportMode: Bool
    public var currentTime: Double
    
    public init(config: AnimatedPatternConfig, isExportMode: Bool = false, currentTime: Double = 0.0) {
        self.config = config
        self.isExportMode = isExportMode
        self.currentTime = currentTime
    }
    
    public var body: some View {
        if isExportMode {
            PatternCanvasView(config: config, time: currentTime)
        } else {
            // 預覽採用 30 FPS 間隔調度，杜絕 120Hz 高刷螢幕下 WindowServer 與主線程 CPU 飢餓卡頓
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                PatternCanvasView(config: config, time: t)
            }
        }
    }
}

public struct PatternCanvasView: View {
    public var config: AnimatedPatternConfig
    public var time: Double
    
    public init(config: AnimatedPatternConfig, time: Double) {
        self.config = config
        self.time = time
    }
    
    public var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            // 1. 底色繪製
            let bgColor = Color(hex: config.backgroundColorHex)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bgColor))
            
            // 2. 構建重複的圖標與文字
            let iconColor = Color(hex: config.iconColorHex)
            let textColor = Color(hex: config.textColorHex)
            let font = Font.system(size: CGFloat(config.fontSize), weight: config.isBold ? .bold : .medium)
            
            let combinedText: Text
            switch config.contentMode {
            case .iconAndText:
                let iconPart: Text
                if let b64 = config.customIconBase64,
                   let data = Data(base64Encoded: b64),
                   let nsImg = NSImage(data: data) {
                    let targetH = CGFloat(config.fontSize) * 1.08
                    let aspect = nsImg.size.width / max(nsImg.size.height, 1)
                    let targetW = targetH * aspect
                    nsImg.size = CGSize(width: targetW, height: targetH)
                    iconPart = Text(Image(nsImage: nsImg))
                } else {
                    let sym = config.sfSymbol.isEmpty ? "cpu" : config.sfSymbol
                    iconPart = Text(Image(systemName: sym)).foregroundColor(iconColor)
                }
                let textPart = Text(config.text.isEmpty ? " " : config.text).foregroundColor(textColor)
                combinedText = Text("\(iconPart)  \(textPart)").font(font)
                
            case .textOnly:
                combinedText = Text(config.text.isEmpty ? " " : config.text)
                    .foregroundColor(textColor)
                    .font(font)
                
            case .iconOnly:
                if let b64 = config.customIconBase64,
                   let data = Data(base64Encoded: b64),
                   let nsImg = NSImage(data: data) {
                    let targetH = CGFloat(config.fontSize) * 1.5
                    let aspect = nsImg.size.width / max(nsImg.size.height, 1)
                    let targetW = targetH * aspect
                    nsImg.size = CGSize(width: targetW, height: targetH)
                    combinedText = Text(Image(nsImage: nsImg)).font(font)
                } else {
                    let sym = config.sfSymbol.isEmpty ? "cpu" : config.sfSymbol
                    combinedText = Text(Image(systemName: sym)).foregroundColor(iconColor).font(font)
                }
            }
            
            // 3. 一次性解析單元幾何大小
            let resolved = context.resolve(combinedText)
            let itemSize = resolved.measure(in: size)
            let safeWidth = max(24.0, itemSize.width)
            let safeHeight = max(14.0, itemSize.height)
            
            let cellWidth = safeWidth + CGFloat(max(10.0, config.itemSpacing))
            let cellHeight = safeHeight + CGFloat(max(8.0, config.rowSpacing))
            
            // 4. 動態位移計算（基於方向與速度進行連續平滑滾動）
            let vec = config.scrollDirection.vector
            let shiftX = CGFloat(vec.dx * config.speed * time)
            let shiftY = CGFloat(vec.dy * config.speed * time)
            
            var modX = shiftX.truncatingRemainder(dividingBy: cellWidth)
            if modX < 0 { modX += cellWidth }
            
            let verticalPeriod = config.staggeredOffset ? (2.0 * cellHeight) : cellHeight
            var modY = shiftY.truncatingRemainder(dividingBy: verticalPeriod)
            if modY < 0 { modY += verticalPeriod }
            
            // 5. 緊密旋轉涵蓋範疇計算 (Tight Bounding Box，效能提升 24 倍)
            let rad = abs(config.rotationAngle * .pi / 180.0)
            let halfSpanW = (size.width * cos(rad) + size.height * sin(rad)) / 2.0
            let halfSpanH = (size.width * sin(rad) + size.height * cos(rad)) / 2.0
            
            let xCount = Int(ceil(halfSpanW / cellWidth)) + 1
            let yCount = Int(ceil(halfSpanH / cellHeight)) + 1
            
            var rotContext = context
            rotContext.opacity = min(1.0, max(0.05, config.opacity))
            rotContext.translateBy(x: size.width / 2, y: size.height / 2)
            rotContext.rotate(by: Angle(degrees: config.rotationAngle))
            
            // 6. 循環繪製整片交錯重複圖騰（高效輕量級）
            for r in -yCount...yCount {
                let rowY = CGFloat(r) * cellHeight + modY
                let isOdd = abs(r) % 2 == 1
                let rowOffset = (config.staggeredOffset && isOdd) ? (cellWidth / 2) : 0.0
                
                for c in -xCount...xCount {
                    let itemX = CGFloat(c) * cellWidth + rowOffset + modX
                    rotContext.draw(resolved, at: CGPoint(x: itemX, y: rowY), anchor: .center)
                }
            }
        }
    }
}
