import SwiftUI
import AppKit
import BenchmarkCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 當使用者關閉視窗時，徹底結束應用程式程序，杜絕無視窗背景殭屍行程導致下次打不開程式
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 當使用者在 Dock 或 Finder 重新點擊時，確保視窗浮現至最前台
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
                return true
            }
        }
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // 支援點擊 .json 專案檔或 Open With 直接於本程式中開啟
        for url in urls {
            NotificationCenter.default.post(name: NSNotification.Name("OpenBenchmarkProjectFile"), object: url)
        }
    }
}

@main
struct BenchmarkAnimatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        if CommandLine.arguments.contains("--verify") {
            NSApplication.shared.setActivationPolicy(.accessory)
            DispatchQueue.main.async {
                Task { @MainActor in
                    await runBenchmarkVerification()
                    exit(0)
                }
            }
            NSApplication.shared.run()
        }
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    var body: some Scene {
        WindowGroup("Visualized Benchmark") {
            ContentView()
                .navigationTitle("Visualized Benchmark")
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 800)
    }
}
