import Foundation
import AVFoundation
import Cocoa

enum PlayingState {
    case empty, playing, live
}

class FaceLayer: CALayer {
    var liveLayer: CALayer?
    var playerLayer: AVPlayerLayer?
    var player = AVPlayer()
    var state = PlayingState.empty
    var dispatcher: FaceDispatcher? {
        didSet {
            insertNextPlayerItem()
        }
    }
    
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
        #if DEBUG
        self.playerLayer?.opacity = 0.3
        #endif
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
        guard live != self.liveLayer else { debug("live layer already on!"); return }
        DispatchQueue.main.async {
            debug("switch to live")
            self.state = .live
            self.liveLayer = live
            self.player.pause()
            self.liveLayer!.frame = self.bounds
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.sublayers = []
            self.addSublayer(self.liveLayer!)
            CATransaction.commit()
        }
    }
    
    func switchPlay(_ completion:@escaping () -> Void) {
        guard liveLayer?.superlayer == self else { debug("superlayer is not self!"); return }
        
        DispatchQueue.main.async {
            debug("switch to play")
            if self.player.currentItem == nil {
                self.insertNextPlayerItem()
            } else {
                self.player.play()
            }
            CATransaction.begin()
            CATransaction.setCompletionBlock({ completion() })
            CATransaction.setDisableActions(true)
            self.sublayers = []
            self.addSublayer(self.playerLayer!)
            CATransaction.commit()
        }
    }
}
