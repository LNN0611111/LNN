# Visualized Benchmark

> **Visualized Benchmark** 是一款專為科技評測、硬體解熱與性能對比打造的高效能原生 macOS SwiftUI 動態圖表與影片生成工具。

支援即時預覽、彈簧阻尼動畫（Spring Physics）、同步滾動數值計數器（Number Counter Animation）、文字與圖片動態平移底紋、晶瑩通透毛玻璃容器、綠幕與去背透明通道，並具備 15 核心 Apple Silicon 並行批次渲染引擎，可極速匯出 **ProRes 4444 (Alpha)**、**H.264 MP4** 影片與超高畫質序列圖檔。

---

## 🌟 核心特色

- **雙圖表呈現架構**：
  - **橫向長條圖 (Horizontal Bar Chart)**：支援 5 位數以上大數值自適應微縮槽位、單行防截斷保護、留空疊加圖層佈局。
  - **縱向分組比例圖 (Vertical Grouped Bar)**：支援自訂 100% 基準產品、自動比例換算、貼齊 0% 底線與 100% 虛線。
- **全新高通透毛玻璃容器**：
  - 專屬「毛玻璃通透度」自訂調節滑桿（5% ~ 98% 自由調整）。
  - 離屏渲染色彩硬鎖定，保證匯出影片與編輯器內預覽色彩 100% 一致，絕不泛白變灰。
- **極速全核心並行批次渲染引擎**：
  - 滿載調用 Apple Silicon 效能核與效率核（`DispatchQueue.concurrentPerform`），搭配 Metal 硬體光柵化加速。
  - 結尾定格時段採用零拷貝（Zero-Copy Settle Cache），1080p 60fps 影片極速匯出。
- **豐富的自訂視覺與動畫**：
  - 動態「文字/圖片平移」多方向平鋪背景（支援 1:1, 16:9, 4:3, 3:2, 9:16 等自訂比例裁剪與等比縮放）。
  - 獨立外框開關且文字零位移佈局、平鋪字體大小微調、自訂色盤與色碼、綠幕去背防穿孔。
- **內建系統快取清理引擎**：
  - 側邊欄「快取與效能」支援一鍵掃描與深度清理暫存與殘留檔案。

---

## 🛠 系統需求與環境

- **macOS**：macOS 13.0 (Ventura) 或更高版本
- **架構**：Apple Silicon (M1 / M2 / M3 / M4 系列) 或 Intel Mac
- **開發環境**：Swift 5.9+, Xcode 15+

---

## 🚀 快速開始

### 編譯並運行
```bash
# 下載或 Clone 專案
git clone https://github.com/LNN0611111/LNN.git
cd LNN

# 快速啟動
./run.sh

# 或使用 Swift PM 編譯
swift run BenchmarkAnimator
```

### 發行版打包 (Release Build)
```bash
swift build -c release
```

---

## 📄 License

MIT License
