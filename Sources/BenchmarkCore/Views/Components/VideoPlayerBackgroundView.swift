import SwiftUI
import AVKit
import AppKit

public struct CustomMediaBackgroundView: View {
    public var filePath: String?
    public var videoConfig: CustomVideoConfig
    
    public init(filePath: String?, videoConfig: CustomVideoConfig = CustomVideoConfig()) {
        self.filePath = filePath
        self.videoConfig = videoConfig
    }
    
    public var body: some View {
        Group {
            if let path = filePath, FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                let ext = url.pathExtension.lowercased()
                let contentMode: ContentMode = (videoConfig.contentMode == "fit") ? .fit : .fill
                
                if ["mp4", "mov", "m4v"].contains(ext) {
                    PlayerRepresentable(url: url, config: videoConfig)
                        .aspectRatio(contentMode: contentMode)
                } else if let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    Color.black
                }
            } else {
                Color.black
            }
        }
    }
}

struct PlayerRepresentable: NSViewRepresentable {
    let url: URL
    let config: CustomVideoConfig
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        let player = AVPlayer(url: url)
        context.coordinator.player = player
        playerView.player = player
        playerView.controlsStyle = .none
        player.isMuted = true
        
        let startSec = config.trimStartTime
        let endSec = config.trimEndTime
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        context.coordinator.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let current = CMTimeGetSeconds(time)
            if endSec > startSec && current >= endSec {
                player.seek(to: CMTime(seconds: startSec, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        
        if startSec > 0 {
            player.seek(to: CMTime(seconds: startSec, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var player: AVPlayer?
        var timeObserver: Any?
        
        deinit {
            if let p = player, let obs = timeObserver {
                p.removeTimeObserver(obs)
            }
        }
    }
}
