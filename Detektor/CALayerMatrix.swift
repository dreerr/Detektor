//
//  CALayerMatrix.swift
//  Observers
//
//  Created by Julian on 25.01.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import Foundation
import Cocoa

class CALayerMatrix: CALayer {
    var cols = 0
    var rows = 0
    var observer: NSKeyValueObservation?
    
    init(withCols cols:Int, rows:Int) {
        super.init()
        self.cols = cols
        self.rows = rows
        self.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.backgroundColor = NSColor.gray.cgColor
        
        observer = observe(\.bounds, changeHandler: { _,_ in self.layoutSublayers() })
        matrix(cols: cols, rows: rows)
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func matrix(cols:Int, rows: Int) {
        // Create CALayers and layout them
        self.sublayers?.removeAll()
        for _ in 0..<cols*rows {
            let layer = CALayer()
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            self.addSublayer(layer)
        }
        //layoutSublayers()
    }
    
    override func layoutSublayers() {
        guard let sublayers = sublayers else { return }
        for col in 0..<cols {
            for row in 0..<rows {
                let sublayer = sublayers[col*rows+row]
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
