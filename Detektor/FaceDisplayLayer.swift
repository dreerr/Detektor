import Foundation
import AVFoundation
import Cocoa

enum PlayingState {
    case empty, playing, live
}

class FaceDisplayLayer: NSObject {
    var layer: CALayer
    var liveLayer: CALayer?
    var playerLayer: AVPlayerLayer
    var parent: FaceDisplay
    var player = AVPlayer()
    var isPlaying = true
    var state = PlayingState.empty

    init(layer: CALayer, facePlayer: FaceDisplay) {
        self.layer = layer
        self.parent = facePlayer
        #if DETEKTOR
        self.layer.contentsScale = 3.0
        #endif
        self.playerLayer = AVPlayerLayer(player: player)
        super.init()
        
        // Setup players and layers
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.frame = layer.bounds
        playerLayer.removeAllAnimations()
        layer.removeAllAnimations()
        layer.addSublayer(playerLayer)
        
        // Mirror layer
        layer.transform = CATransform3DMakeScale(-1, 1, 1)
        
        // Play next item available
        self.insertNextPlayerItem()
    }
    
    func insertNextPlayerItem() {
        parent.restoreAsset(player.currentItem?.asset as? AVURLAsset)
        if let asset = parent.getNextAsset()  {
            let item = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: item)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didPlayToEndTime(notification:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: item)
            player.play()
            state = .playing
        } else {
            player.replaceCurrentItem(with:nil)
            state = .empty
        }
    }

    @objc func didPlayToEndTime(notification:Notification) {
        DispatchQueue.main.async {
            self.insertNextPlayerItem()
        }
    }

    func switchLive(_ live:CALayer) {
        // Connect a CALayer to display live preview
        if live != liveLayer {
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
            state = .live
        }
    }
    
    func switchPlay() {
        if !isPlaying { // state != .live
            // Disconnect live preview and contiune playing items
            layer.sublayers?.forEach({ (layer) in layer.removeFromSuperlayer()})
            layer.addSublayer(playerLayer)
            playerLayer.frame = layer.bounds
            if player.currentItem == nil {
                insertNextPlayerItem()
            } else {
                player.play()
            }
            DispatchQueue.main.async {
                self.layer.setNeedsDisplay()
                self.layer.setNeedsLayout()
            }
        }
    }
}
