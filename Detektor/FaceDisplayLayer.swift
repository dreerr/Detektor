import Foundation
import AVFoundation
import Cocoa

class FaceDisplayLayer: NSObject {
    var layer: CALayer
    var liveLayer: CALayer?
    var playerLayer: AVPlayerLayer
    var parent: FaceDisplay
    var player = AVPlayer() // Maybe only AVPlayer?
    var isPlaying = true

    init(layer: CALayer, facePlayer: FaceDisplay) {
        self.layer = layer
        self.parent = facePlayer
        self.layer.contentsScale = 3.0
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
        // Insert item on the playlist and start playing
        if let item = parent.getNextPlayerItem()  {
            
            // Reset the item: rewind and remove observer
            item.seek(to: CMTime.zero, completionHandler: nil)
            NotificationCenter.default.removeObserver(self,
                                                      name: .AVPlayerItemDidPlayToEndTime,
                                                      object: item)
            
            if item == player.currentItem {
                print("seek")
                player.seek(to: CMTime.zero)
            } else {
                
                player.replaceCurrentItem(with: item)
            }
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didPlayToEndTime(notification:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: item)

            
            player.play()
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
        }
    }
    
    func switchPlay() {
        if !isPlaying {
            // Disconnect live preview and contiune playing items
            layer.sublayers?.forEach({ (layer) in layer.removeFromSuperlayer()})
            layer.addSublayer(playerLayer)
            playerLayer.frame = layer.bounds
            if player.currentItem == nil {
                insertNextPlayerItem()
            } else {
                player.play()
            }
            isPlaying = true
            DispatchQueue.main.async {
                self.layer.setNeedsDisplay()
                self.layer.setNeedsLayout()
            }
        }
    }
}
