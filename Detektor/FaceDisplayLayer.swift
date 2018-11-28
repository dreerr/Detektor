import Foundation
import AVFoundation
import Cocoa

class FaceDisplayLayer: NSObject {
    var layer: CALayer
    var liveLayer: CALayer?
    var playerLayer: AVPlayerLayer
    var parent: FaceDisplay
    var player = AVQueuePlayer() // Maybe only AVPlayer?
    var isPlaying = true

    init(layer: CALayer, facePlayer: FaceDisplay) {
        self.layer = layer
        self.parent = facePlayer
        self.playerLayer = AVPlayerLayer(player: player)
        super.init()
        
        // Setup players and layers
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.frame = layer.bounds
        playerLayer.removeAllAnimations()
        layer.removeAllAnimations()
        layer.addSublayer(playerLayer)
        
        // Play next item available
        self.insertNextPlayerItem()
    }
    
    func insertNextPlayerItem() {
        // Insert item on the playlist and start playing
        if let item = self.parent.getNextPlayerItem() {
            self.player.insert(item, after: nil)
            self.player.play()
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didPlayToEndTime(notification:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: item)
        }
    }
    @objc func didPlayToEndTime(notification:Notification) {
        DispatchQueue.main.async {
            self.insertNextPlayerItem()
        }
    }
    
    var timeRemaining : CMTime {
        // returns remaining time in the player
        if let item = player.currentItem {
            return item.duration - item.currentTime()
        } else {
            return CMTime(seconds: 0, preferredTimescale: 600)
        }
    }

    func switchLive(_ live:CALayer) {
        // Connect a CALayer to display live preview
        layer.sublayers?.forEach({ (layer) in layer.removeFromSuperlayer()})
        liveLayer = live
        player.pause()
        liveLayer!.frame = layer.bounds
        layer.addSublayer(liveLayer!)
        DispatchQueue.main.async {
            self.layer.setNeedsDisplay()
            self.layer.setNeedsLayout()
        }
        isPlaying = false
    }
    
    func switchPlay() {
        if !isPlaying {
            // Disconnect live preview and contiune playing items
            layer.sublayers?.forEach({ (layer) in layer.removeFromSuperlayer()})
            layer.addSublayer(playerLayer)
            player.play()
            DispatchQueue.main.async {
                self.layer.setNeedsDisplay()
                self.layer.setNeedsLayout()
            }
        }
    }
}
