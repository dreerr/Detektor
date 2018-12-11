import Foundation
import Cocoa

class CALayerStretch: CALayer {
    let content = CALayer()
    var observer: NSKeyValueObservation?
    var stretchRatio : CGFloat = 1.0 {
        didSet {
            if stretchRatio > 1.0 {
                self.sublayerTransform = CATransform3DMakeScale(stretchRatio, 1.0, 1.0)
                self.layoutBounds()
            }
        }
    }
    override init() {
        super.init()
        self.removeAllAnimations()
        self.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        content.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.addSublayer(content)
        layoutBounds()
        observer = observe(\.bounds, changeHandler: { _,_ in self.layoutBounds() })
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func layoutBounds() {
        if stretchRatio >= 1.0 {
            content.frame = self.bounds
            content.frame =  NSRect(origin: self.bounds.origin, size: CGSize(width: self.bounds.width/stretchRatio, height: self.bounds.height))
            content.frame.origin.x = (self.bounds.width - self.bounds.width/stretchRatio)/2
            content.layoutSublayers()
        }
    }
}
