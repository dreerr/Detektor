import Cocoa
import Foundation
import AVFoundation
import VideoToolbox

// Delegate Method for Video Data Output
extension FaceTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Check if we should track
        guard isTracking == true else {return}
        
        // Get Image Buffer and detect faceCV features
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        var ciImage = CIImage(cvImageBuffer: imageBuffer, options: attachments as! [String : Any]?)
        let options: [String : Any] = [CIDetectorTypeFace: true, CIDetectorSmile: true]
        let allFeatures = detector?.features(in: ciImage, options: options)
        
        // Collect all IDs to check for orphans
        var currentIDs = [Int32]()
        
        // Apply filter to image
        ciImage = ciImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": 0.0,
                                                                         "inputContrast": 1.1,
                                                                         "inputSaturation": 0.0])
            .applyingFilter("CIExposureAdjust", parameters: ["inputEV": 0.5])
        
        guard let features = allFeatures else { return }
        drawDebug(features) // only executed if connected
        
        for feature in features {
            guard let faceFeature = feature as? CIFaceFeature else {continue}
            if(faceFeature.hasTrackingFrameCount) {
                // Keep track of the ID
                let id = faceFeature.trackingID
                currentIDs.append(id)
                if(faceFeature.trackingFrameCount == 1) {
                    // Initialize Face Recorder & Previews instances for each face found with frameCount==1
                    print("new face", id)
                    let faceSide = faceFeature.hasSmile ? CIFaceSide.left : CIFaceSide.right
                    
                    // TODO: Limit number of recordings
                    recordings[id] = FaceRecorder(withFaceSide: faceSide, time: timestamp)
                    
                    // Add preview layer
                    let layer = CALayer()
                    layer.contentsGravity = kCAGravityResizeAspectFill
                    layer.masksToBounds = true
                    previews[id] = layer
                    delegate?.addPreview(layer, id: id)
                }
                // Append image to recording
                // TODO: Use own Threads? Limit resources?
                guard let recording = recordings[id] else {continue}
                let image = ciImage.croppedAndScaledToFace(faceFeature, faceSide: recording.faceSide)
                guard let buffer = image.createPixelBuffer(withContext: context) else {continue}
                recording.append(buffer, time: timestamp)
                
                // Add image to preview layer
                guard let preview = previews[id] else {continue}
                var cgImage: CGImage?
                VTCreateCGImageFromCVPixelBuffer(buffer, nil, &cgImage)
                DispatchQueue.main.async {
                    preview.contents = cgImage
                }
            }
        }
        
        // Check for orphans and properly remove them (calls deinit)
        for orphan in Set(previews.keys).subtracting(currentIDs) {
            print("lost face", orphan)
            delegate?.removePreview(id: orphan)
            previews.removeValue(forKey: orphan)
            recordings.removeValue(forKey: orphan)
        }
    }
}

protocol FaceTrackerProtocol {
    func addPreview(_ preview: CALayer, id: Int32)
    func removePreview(id: Int32)
}

extension CIImage {
    func croppedAndScaledToFace(_ face:CIFaceFeature, faceSide:CIFaceSide) -> CIImage {
        // Calculate Rectangle and resize image
        let rect = face.boundsForFaceSide(faceSide, withAspectRatio: Constants.aspectRatio)
        let scaleFactor = Constants.videoSize.height / rect.size.height
        let image = self.cropped(to: rect)
            .transformed(by: CGAffineTransform(translationX:-rect.minX, y: -rect.minY))
            .transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        return image
    }
}

