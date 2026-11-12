import SwiftUI

public struct HeaderBarView: View {
    public var header: HeaderConfig
    public var primaryAccent: Color
    public var progress: Double // 0.0 to 1.0 for fade-in + slight upward slide
    public var fontFamily: String
    public var typography: TypographyConfig
    public var isLightBackground: Bool
    
    public init(
        header: HeaderConfig,
        primaryAccent: Color = Color(hex: "#A855F7"),
        progress: Double = 1.0,
        fontFamily: String = "System Default",
        typography: TypographyConfig = TypographyConfig(),
        isLightBackground: Bool = false
    ) {
        self.header = header
        self.primaryAccent = primaryAccent
        self.progress = progress
        self.fontFamily = fontFamily
        self.typography = typography
        self.isLightBackground = isLightBackground
    }
    
    public var body: some View {
        let titleColor: Color = header.useCustomTitleColor ? Color(hex: header.titleColorHex) : (isLightBackground ? Color(hex: "#0F172A") : .white)
        let subtitleColor: Color = header.useCustomTitleColor ? Color(hex: header.subtitleColorHex) : (isLightBackground ? Color(hex: "#334155") : Color(white: 0.7))
        
        HStack(spacing: 16) {
            // Glowing Icon (支援用戶自選單色及雙色漸層配色、等比填滿/適應)
            GlowingIconView(
                symbol: header.iconSymbol,
                customImageBase64: header.customIconBase64,
                size: 54,
                colorMode: header.iconColorMode,
                color1: Color(hex: header.iconColor1Hex),
                color2: Color(hex: header.iconColor2Hex),
                fillBox: header.fillIconBox
            )
            
            // Title & Subtitle Stack (固定 54pt 槽位高度，調整字體大小時其餘元素嚴格不動，支援白底高對比度與自訂顏色)
            VStack(alignment: .leading, spacing: 3) {
                Text(header.mainTitle)
                    .font(FontManager.shared.font(
                        family: fontFamily,
                        size: CGFloat(typography.mainTitleSize),
                        weight: .heavy,
                        design: .rounded,
                        isBoldMode: typography.isBoldMode
                    ))
                    .italic()
                    .foregroundColor(titleColor)
                    .shadow(color: isLightBackground ? (header.useCustomTitleColor ? Color.black.opacity(0.15) : Color.white.opacity(0.8)) : Color.black.opacity(0.6), radius: isLightBackground ? 1 : 4, x: 0, y: isLightBackground ? 1 : 2)
                    .lineLimit(1)
                
                if !header.subtitle.isEmpty {
                    Text(header.subtitle)
                        .font(FontManager.shared.font(
                            family: fontFamily,
                            size: CGFloat(typography.subtitleSize),
                            weight: .medium,
                            design: .default,
                            isBoldMode: typography.isBoldMode
                        ))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)
                }
            }
            .frame(height: 54, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .opacity(min(max(progress, 0.0), 1.0))
        .offset(y: (1.0 - min(max(progress, 0.0), 1.0)) * 18.0)
    }
}
