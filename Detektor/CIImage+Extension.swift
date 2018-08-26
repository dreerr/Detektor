//
//  CIImagePixelBuffer.swift
//  Observers
//
//  Created by Julian on 24.01.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import CoreImage

extension CIImage {
    func createPixelBuffer(withContext context : CIContext) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil
        let options: [NSObject: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey: false,
            ]
        let size = self.extent.size
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(size.width),
                                         Int(size.height),
                                         Constants.pixelFormat,
                                         options as CFDictionary,
                                         &pixelBuffer)
        if(status == kCVReturnSuccess) {
            context.render(self, to: pixelBuffer!, bounds:CGRect(x: 0,
                                                                 y: 0,
                                                                 width: size.width,
                                                                 height: size.height),
                           colorSpace: self.colorSpace)
        }
        return pixelBuffer
    }
    
}
