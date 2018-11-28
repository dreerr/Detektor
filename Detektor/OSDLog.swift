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
    init(withLayer layer:CALayer) {
        super.init()
        self.fontSize = 20
        self.string = ""
        self.isWrapped = true
        self.frame = layer.bounds
        self.frame.origin.x += 10
        self.frame.size.width -= 20
        self.frame.size.height -= 20
        self.frame.origin.y -= 10
        layer.addSublayer(self)
        NotificationCenter.default.addObserver(forName: Notification.Name("Log"),
                                               object: nil,
                                               queue: OperationQueue.main) {
                                                var lines = (self.string as! String).components(separatedBy: "\n")
                                                lines.append($0.object as! String)
                                                
                                                self.string = lines.suffix(10).joined(separator: "\n")
        }
        
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "*\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    NotificationCenter.default.post(name: Notification.Name("Log"), object: output)
}
