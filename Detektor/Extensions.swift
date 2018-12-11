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
    func croppedAndScaledToFace(_ face:CIFaceFeature, faceSide:CIFaceSide) -> CIImage {
        // Calculate Rectangle and resize image
        let rect = face.boundsForFaceSide(faceSide, withAspectRatio: Constants.aspectRatio)
        let scaleFactor = Constants.videoSize.height / rect.size.height
        let transform = CGAffineTransform(translationX:-rect.minX, y: -rect.minY)
            .concatenating(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        let image = self.cropped(to: rect).transformed(by: transform)
        return image
    }
}




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


extension AVCaptureDevice {
    static func devices(withNameContaining name: String) -> [AVCaptureDevice]? {
        return AVCaptureDevice.devices().filter { return $0.localizedName.contains(name) }
    }
}
