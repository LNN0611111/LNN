import SwiftUI
import CoreText
import Foundation

@MainActor
public final class FontManager: ObservableObject {
    public static let shared = FontManager()
    
    @Published public var availableFontFamilies: [String] = [
        "System Default",
        "PingFang SC",
        "Helvetica Neue",
        "Menlo",
        "Impact",
        "Futura",
        "DIN Alternate",
        "Georgia"
    ]
    
    @Published public var customFontNames: [String] = []
    
    private init() {
        loadCustomFonts()
    }
    
    private func loadCustomFonts() {
        if let saved = UserDefaults.standard.stringArray(forKey: "BenchmarkAnimator_CustomFonts") {
            for fontName in saved {
                if !availableFontFamilies.contains(fontName) {
                    availableFontFamilies.append(fontName)
                    customFontNames.append(fontName)
                }
            }
        }
    }
    
    /// Register a custom font from TTF or OTF file
    public func registerCustomFont(from fileURL: URL) throws -> String {
        let cfURL = fileURL as CFURL
        var error: Unmanaged<CFError>?
        
        let success = CTFontManagerRegisterFontsForURL(cfURL, .process, &error)
        if !success, let err = error?.takeRetainedValue() {
            let desc = CFErrorCopyDescription(err) as String? ?? "未知字體錯誤"
            // If already registered, still retrieve font name
            if !desc.contains("already registered") {
                throw NSError(domain: "FontManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "註冊字體失敗: \(desc)"])
            }
        }
        
        // Extract font name from descriptors
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(cfURL) as? [CTFontDescriptor],
              let first = descriptors.first else {
            let fallbackName = fileURL.deletingPathExtension().lastPathComponent
            addFontName(fallbackName)
            return fallbackName
        }
        
        let fontName = (CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String)
            ?? (CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String)
            ?? fileURL.deletingPathExtension().lastPathComponent
            
        addFontName(fontName)
        return fontName
    }
    
    private func addFontName(_ name: String) {
        if !availableFontFamilies.contains(name) {
            availableFontFamilies.append(name)
        }
        if !customFontNames.contains(name) {
            customFontNames.append(name)
            UserDefaults.standard.set(customFontNames, forKey: "BenchmarkAnimator_CustomFonts")
        }
    }
    
    /// Generate a SwiftUI Font given family name, size, weight, and bold mode
    public func font(
        family: String,
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        isBoldMode: Bool = false
    ) -> Font {
        let effectiveWeight = isBoldMode ? boldModeWeight(for: weight) : weight
        if family.isEmpty || family == "System Default" || family == "系統預設 (San Francisco)" {
            return Font.system(size: size, weight: effectiveWeight, design: design)
        } else {
            return Font.custom(family, size: size).weight(effectiveWeight)
        }
    }
    
    private func boldModeWeight(for weight: Font.Weight) -> Font.Weight {
        switch weight {
        case .ultraLight, .thin, .light:
            return .semibold
        case .regular:
            return .bold
        case .medium:
            return .bold
        case .semibold:
            return .heavy
        case .bold:
            return .black
        case .heavy, .black:
            return .black
        default:
            return .bold
        }
    }
}
