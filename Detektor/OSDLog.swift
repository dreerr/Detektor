//
//  OSDLog.swift
//  Detektor
//
//  Created by Julian on 27.11.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import Foundation
import Cocoa

class OSDLogLayer: CATextLayer {
    var fadeOut : Timer?
    override init() {
        super.init()
        self.fontSize = 40
        self.string = ""
        self.isWrapped = true
        self.opacity = 0.0
        self.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        NotificationCenter.default.addObserver(forName: Notification.Name("Log"),
                                               object: nil,
                                               queue: OperationQueue.main) {self.print($0.object as! String)}
    }
    
    func print(_ string: String) {
        var lines = (self.string as! String).components(separatedBy: "\n")
        lines.append(string)
        self.string = lines.suffix(20).joined(separator: "\n")
        opacity = 1.0
        fadeOut?.invalidate()
        fadeOut = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: {_ in
            self.opacity = 0.0
            self.string = ""
        })
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func connect(to layer: CALayer) {
        self.frame = layer.bounds
        self.frame.origin.x += 10
        self.frame.size.width -= 20
        self.frame.size.height -= 20
        self.frame.origin.y -= 10
        layer.addSublayer(self)
    }
}

public func alert(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "▸ \($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    NotificationCenter.default.post(name: Notification.Name("Log"), object: output)
}
