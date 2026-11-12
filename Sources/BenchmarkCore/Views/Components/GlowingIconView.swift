import SwiftUI
import AppKit

public struct GlowingIconView: View {
    public var symbol: String
    public var customImageBase64: String?
    public var size: CGFloat = 58.0
    public var colorMode: IconColorMode = .gradient
    public var color1: Color = Color(hex: "#A855F7")
    public var color2: Color = Color(hex: "#6366F1")
    public var fillBox: Bool = false
    
    public init(
        symbol: String,
        customImageBase64: String? = nil,
        size: CGFloat = 58.0,
        colorMode: IconColorMode = .gradient,
        color1: Color = Color(hex: "#A855F7"),
        color2: Color = Color(hex: "#6366F1"),
        fillBox: Bool = false
    ) {
        self.symbol = symbol
        self.customImageBase64 = customImageBase64
        self.size = size
        self.colorMode = colorMode
        self.color1 = color1
        self.color2 = color2
        self.fillBox = fillBox
    }
    
    public init(
        symbol: String,
        customImageBase64: String? = nil,
        size: CGFloat = 58.0,
        accentColor: Color = Color(hex: "#A855F7"),
        fillBox: Bool = false
    ) {
        self.symbol = symbol
        self.customImageBase64 = customImageBase64
        self.size = size
        self.colorMode = .monochrome
        self.color1 = accentColor
        self.color2 = accentColor
        self.fillBox = fillBox
    }
    
    public var body: some View {
        let isSingle = (colorMode == .monochrome)
        
        ZStack {
            // Ambient Neon Glow behind the icon
            if isSingle {
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(color1.opacity(0.38))
                    .blur(radius: size * 0.25)
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(
                        LinearGradient(
                            colors: [color1.opacity(0.4), color2.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: size * 0.25)
                    .frame(width: size, height: size)
            }
            
            // Icon container background
            RoundedRectangle(cornerRadius: size * 0.26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.2).opacity(0.8),
                            Color(white: 0.1).opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Subtle glossy gradient border
                    RoundedRectangle(cornerRadius: size * 0.26)
                        .stroke(
                            LinearGradient(
                                colors: isSingle
                                    ? [color1.opacity(0.85), Color.white.opacity(0.3), Color.white.opacity(0.05)]
                                    : [color1.opacity(0.85), color2.opacity(0.8), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
            
            // Icon graphic: Custom uploaded image or SF Symbol
            if let customImageBase64 = customImageBase64,
               let data = Data(base64Encoded: customImageBase64),
               let nsImage = NSImage(data: data) {
                if fillBox {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.26))
                } else {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size * 0.68, height: size * 0.68)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
                }
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.52, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isSingle ? [.white, color1] : [color1, color2],
                            startPoint: isSingle ? .top : .topLeading,
                            endPoint: isSingle ? .bottom : .bottomTrailing
                        )
                    )
            }
        }
    }
}
