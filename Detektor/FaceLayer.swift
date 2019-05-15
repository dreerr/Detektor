import Foundation
import AVFoundation
import Cocoa

enum PlayingState {
    case empty, playing, live
}

class FaceLayer: CALayer {
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
            dispatcher?.restoreAsset(player.currentItem?.asset as? AVURLAsset) // Return current item to queue
        }
        if let asset = dispatcher?.getNextAsset() {
            let item = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: item)
            let center = NotificationCenter.default
            center.addObserver(self,
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
            isPlaying = false
            state = .live
            liveLayer = live
            player.pause()
            liveLayer!.frame = self.bounds
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.addSublayer(self.liveLayer!)
                CATransaction.commit()
            }
        }
    }
    
    func switchPlay() {
        if state == .live {
            if liveLayer?.superlayer != self { debug("superlayer is not self!") }
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setCompletionBlock({
                    self.liveLayer = nil
                })
                CATransaction.setDisableActions(true)
                self.liveLayer?.removeFromSuperlayer()
                CATransaction.commit()
            }
        }
        if player.currentItem == nil {
            insertNextPlayerItem()
        } else {
            player.play()
        }
        DispatchQueue.main.async {
            self.setNeedsLayout()
        }
    }
}
