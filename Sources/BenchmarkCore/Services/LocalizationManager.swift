import SwiftUI
import Combine
import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case traditionalChinese = "繁體中文 (Traditional Chinese)"
    case english = "English"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .traditionalChinese: return "繁中"
        case .english: return "EN"
        }
    }
}

public final class LocalizationManager: ObservableObject, @unchecked Sendable {
    public static let shared = LocalizationManager()
    
    private let lock = NSLock()
    private var _currentLanguage: AppLanguage = .traditionalChinese
    
    public var currentLanguage: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentLanguage
        }
        set {
            lock.lock()
            _currentLanguage = newValue
            lock.unlock()
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }
    
    private init() {}
    
    /// Returns localized string based on current language
    public func localized(_ zh: String, _ en: String) -> String {
        switch currentLanguage {
        case .traditionalChinese:
            return zh
        case .english:
            return en
        }
    }
}

/// Global helper for localization (thread-safe, callable from any context)
public func l10n(_ zh: String, _ en: String) -> String {
    LocalizationManager.shared.localized(zh, en)
}
