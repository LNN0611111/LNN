import SwiftUI

public struct AnimationSection: View {
    @Binding public var animation: AnimationConfig
    public var isPlaying: Bool
    public var onPlay: () -> Void
    public var onReset: () -> Void
    
    public init(
        animation: Binding<AnimationConfig>,
        isPlaying: Bool,
        onPlay: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self._animation = animation
        self.isPlaying = isPlaying
        self.onPlay = onPlay
        self.onReset = onReset
    }
    
    public var body: some View {
        SidebarSectionCard(title: l10n("動畫控制與物理參數", "Animation Controls"), systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                // Play / Reset Actions
                HStack(spacing: 10) {
                    Button(action: onPlay) {
                        Label(isPlaying ? l10n("重新播放", "Replay") : l10n("播放進場動畫", "Play"), systemImage: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#2563EB"))
                    
                    Button(action: onReset) {
                        Label(l10n("重置", "Reset"), systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
                
                // Animation Style (Includes 衝出動畫)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n("進場動畫風格", "Animation Style"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $animation.style) {
                        ForEach(AnimationStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .labelsHidden()
                }
                
                // Duration Slider
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(l10n("動畫持續時間", "Animation Duration"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: l10n("%.2f 秒", "%.2f s"), animation.duration))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $animation.duration, in: 0.5...4.0, step: 0.1)
                }
                
                // Spring Damping Slider
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(l10n("彈簧阻尼 (Spring Damping)", "Spring Damping"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f", animation.springDamping))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $animation.springDamping, in: 0.3...1.0, step: 0.05)
                }
                
                // Spring Response Slider
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(l10n("彈簧反應速度 (Response)", "Spring Response"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f", animation.springResponse))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $animation.springResponse, in: 0.3...1.5, step: 0.05)
                }
                
                // Staggered Delay
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(l10n("各列排程延遲 (Staggered Delay)", "Staggered Delay"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: l10n("%.2f 秒", "%.2f s"), animation.staggeredDelay))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $animation.staggeredDelay, in: 0.0...0.3, step: 0.02)
                }
                
                // Hold Duration (選填時間，預設 2.0 秒)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l10n("動畫結尾定格保留時間 (Hold)", "Hold Duration"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        TextField("", value: $animation.holdDuration, format: .number.precision(.fractionLength(1...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 58)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                        
                        Text(l10n("秒", "s"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#10B981"))
                    }
                    
                    Slider(value: $animation.holdDuration, in: 0.0...10.0, step: 0.25)
                    
                    // 常用預設時間快捷按鈕
                    HStack(spacing: 5) {
                        ForEach([0.5, 1.0, 2.0, 3.0, 5.0], id: \.self) { sec in
                            let isSelected = abs(animation.holdDuration - sec) < 0.05
                            Button(action: {
                                animation.holdDuration = sec
                            }) {
                                Text(sec == 2.0 ? l10n("2.0s (預設)", "2.0s (Def)") : String(format: "%.1fs", sec))
                                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(isSelected ? Color(hex: "#10B981") : Color.white.opacity(0.06))
                                    .foregroundColor(isSelected ? .white : Color(white: 0.8))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
