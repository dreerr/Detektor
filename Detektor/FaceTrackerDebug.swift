import Cocoa
import Foundation
import AVFoundation

extension FaceTracker {
    // Connects to a CALayer for live video
    func connectDebug(_ layer: CALayer) {
        // Create and setup AVCaptureVideoPreviewLayer
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        let formatDescription = captureDevice?.activeFormat.formatDescription
        let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, false)
        let sideLength = layer.bounds.size.width/2
        let size = CGSize(width: sideLength,
                          height: sideLength/cleanAperture.size.width*cleanAperture.size.height)
        preview.frame = CGRect(origin: layer.bounds.origin, size: size)
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        preview.videoGravity = .resize
        layer.addSublayer(preview)
        previewLayer = preview
        
        // Layer holds all shapes
        previewLayerRects.frame = preview.bounds
        layer.addSublayer(previewLayerRects)
    }
    
    
    func disconnectDebug() {
        previewLayer?.removeFromSuperlayer()
        previewLayerRects.sublayers?.removeAll()
        previewLayer = nil
    }

    // Draws rectangles over the faces found in the videofeed
    func drawDebug(_ features: [CIFeature]) {
        guard previewLayer != nil else {return}
        previewLayerRects.sublayers?.removeAll()
        for feature in features {
            if let face = feature as? CIFaceFeature {
                
                // Setup shape
                let shapeLayer = CAShapeLayer()
                shapeLayer.fillColor = nil
                shapeLayer.opacity = 1.0
                shapeLayer.strokeColor = NSColor.red.cgColor
                let path = CGMutablePath()
                
                // Add rectangles to shape layer
                let rect = scaledInPreview(face.bounds)
                path.addRect(rect)
                if(face.hasLeftEyePosition) {
                    let leftEye = scaledInPreview(CGRect(x: face.leftEyePosition.x,
                                                         y: face.leftEyePosition.y,
                                                         width: 3.0,
                                                         height: 3.0))
                    path.addEllipse(in: leftEye)
                    path.addRect(scaledInPreview(face.boundsForFaceSide(.left, withAspectRatio: Constants.aspectRatio)))
                }
                if(face.hasSmile) {
                    shapeLayer.strokeColor = NSColor.green.cgColor
                }
                
                // Add to preview layer
                shapeLayer.path = path
                previewLayerRects.addSublayer(shapeLayer)
            }
        }
        DispatchQueue.main.async {
            self.previewLayer?.setNeedsDisplay()
            self.previewLayerRects.setNeedsDisplay()
        }
    }

    
    // Calculates the scaled sizes in the smaller preview
    func scaledInPreview(_ rect: CGRect) -> CGRect {
        let formatDescription = captureDevice?.activeFormat.formatDescription
        let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, false)
        let parentFrameSize = self.previewLayer!.bounds
        var newRect = rect
        let widthScaleBy = parentFrameSize.width / cleanAperture.size.width
        let heightScaleBy = parentFrameSize.height / cleanAperture.size.height
        newRect.size.width *= widthScaleBy
        newRect.size.height *= heightScaleBy
        newRect.origin.x *= widthScaleBy
        newRect.origin.y *= heightScaleBy
        return newRect
    }
}
