import SwiftUI
import AppKit

public struct ProjectSection: View {
    public var onSave: () -> Void
    public var onLoad: () -> Void
    public var onLoadSample: () -> Void
    
    public init(
        onSave: @escaping () -> Void,
        onLoad: @escaping () -> Void,
        onLoadSample: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onLoad = onLoad
        self.onLoadSample = onLoadSample
    }
    
    public var body: some View {
        SidebarSectionCard(title: l10n("專案設定檔 (JSON)", "Project JSON File"), systemImage: "doc.text") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: onSave) {
                        Label(l10n("儲存專案 (.json)", "Save (.json)"), systemImage: "square.and.arrow.down")
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: onLoad) {
                        Label(l10n("開啟專案", "Open Project"), systemImage: "folder")
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: onLoadSample) {
                    Label(l10n("載入官方範例 (Cinebench 解熱測試)", "Load Sample Project"), systemImage: "sparkle")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
