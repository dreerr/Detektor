import Foundation
import Cocoa

class CALayerMatrix: CALayer {
    var cols = 0
    var rows = 0
    var observer: NSKeyValueObservation?
    
    init(withCols cols:Int, rows:Int, layers:[CALayer]) {
        assert(cols*rows == layers.count, "Mismatch in rows*cols and layers.count")
        super.init()
        self.cols = cols
        self.rows = rows
        self.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layers.forEach {$0.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]}
        self.sublayers = layers
        self.backgroundColor = NSColor.black.cgColor
        
        observer = observe(\.bounds, changeHandler: { _,_ in self.layoutSublayers() })
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSublayers() {
        guard let sublayers = sublayers else { return }
        for col in 0..<cols {
            for row in 0..<rows {
                let idx = col*rows+row
                let sublayer = sublayers[idx]
                let b = self.bounds
                let frame = CGRect(x: b.origin.x + b.size.width/CGFloat(cols)*CGFloat(col),
                                   y: b.origin.y + b.size.height/CGFloat(rows)*CGFloat(row),
                                   width: b.size.width/CGFloat(cols),
                                   height: b.size.height/CGFloat(rows))
                sublayer.frame = frame
                sublayer.sublayers?.forEach { $0.frame = sublayer.bounds }
            }
        }
    }
}
