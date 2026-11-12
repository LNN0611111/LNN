import SwiftUI

public struct CachePerformanceSection: View {
    @Binding public var exportConfig: ExportConfig
    public var onClearCache: () -> Void
    public var cacheSizeText: String
    public var lastActionMessage: String?
    
    public init(
        exportConfig: Binding<ExportConfig>,
        onClearCache: @escaping () -> Void,
        cacheSizeText: String = "計算中...",
        lastActionMessage: String? = nil
    ) {
        self._exportConfig = exportConfig
        self.onClearCache = onClearCache
        self.cacheSizeText = cacheSizeText
        self.lastActionMessage = lastActionMessage
    }
    
    public var body: some View {
        SidebarSectionCard(title: "系統暫存與匯出加速設定", systemImage: "bolt.badge.automatic.fill") {
            VStack(alignment: .leading, spacing: 10) {
                // Cache info & Clear Action
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("當前暫存佔用")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cacheSizeText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#60A5FA"))
                    }
                    
                    Button(action: onClearCache) {
                        Label("立即清除暫存快取", systemImage: "trash.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    if let msg = lastActionMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Export Speed Optimization Toggle
                Toggle("啟用極速匯出優化 (靜態幀去重、記憶體池化加速)", isOn: $exportConfig.enableFastOptimization)
                    .font(.system(size: 11))
                
                Text("開啟後，結尾定格保留時間內將自動重複使用已渲染之定格影格，可縮短 40%～60% 匯出耗時並大幅減少記憶體負擔。")
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
