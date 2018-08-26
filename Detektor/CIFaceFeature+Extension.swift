//
//  CIFaceFeatureExtensions.swift
//  Observers
//
//  Created by Julian on 24.01.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import AVFoundation

enum CIFaceSide {
    case left
    case right
}

extension CIFaceFeature {
    func boundsForFaceSide(_ faceSide: CIFaceSide, withAspectRatio aspectRatio: Float) -> CGRect {
        var eyePosition:CGPoint?
        if faceSide == .left && self.hasLeftEyePosition {
            eyePosition = self.leftEyePosition
        } else if faceSide == .right && self.hasRightEyePosition {
            eyePosition = self.rightEyePosition
        }
        var newBounds = self.bounds
        if aspectRatio <= 1.0 && eyePosition != nil {
            newBounds.size.width = newBounds.height*CGFloat(aspectRatio)
            newBounds.origin.x = eyePosition!.x - newBounds.size.width/2.0
        } else if aspectRatio > 1.0 && eyePosition != nil  {
            newBounds.size.height = newBounds.width/CGFloat(aspectRatio)
            newBounds.origin.y = eyePosition!.y - newBounds.size.height/2.0
        }
        return newBounds
    }
}
