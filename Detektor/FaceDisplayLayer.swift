import Foundation
import AVFoundation
import Cocoa

enum PlayingState {
    case empty, playing, live
}

class FaceDisplayLayer: CALayer {
    var liveLayer: CALayer?
    var playerLayer: AVPlayerLayer?
    var dispatcher: FaceDispatcher? {
        didSet {
            insertNextPlayerItem()
        }
    }
    var player = AVPlayer()
    var isPlaying = true
    var state = PlayingState.empty
    
    override init() {
        super.init()
        setup()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        self.backgroundColor = NSColor.red.cgColor
        #if DETEKTOR
        self.contentsScale = 3.0
        #endif
        
        // Setup player
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.frame = self.bounds
        playerLayer.removeAllAnimations()
        self.addSublayer(playerLayer)
        self.playerLayer = playerLayer
        
        self.removeAllAnimations()
        self.transform = CATransform3DMakeScale(-1, 1, 1) // Mirror layer
    }
    
    
    func insertNextPlayerItem() {
        if player.currentItem != nil {
            print("returning item \(player.currentItem)")
            dispatcher?.restoreAsset(player.currentItem?.asset as? AVURLAsset) // Return current item to queue
        }
        if let asset = dispatcher?.getNextAsset() {
            print("playing item \(asset)")
            let item = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: item)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didPlayToEndTime(notification:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: item)
            player.play()
            playerLayer?.frame = self.bounds
            
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
            liveLayer = live
            player.pause()
            liveLayer!.frame = self.bounds
            self.addSublayer(liveLayer!)
            DispatchQueue.main.async {
                self.setNeedsDisplay()
                self.setNeedsLayout()
            }
            isPlaying = false
            state = .live
        }
    }
    
    func switchPlay() {
        if state != .playing {
            liveLayer?.removeFromSuperlayer()
            if player.currentItem == nil {
                insertNextPlayerItem()
            } else {
                player.play()
            }
            DispatchQueue.main.async {
                self.setNeedsDisplay()
                self.setNeedsLayout()
            }
        }
    }
}
