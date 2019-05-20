import Foundation
import AVFoundation
import VideoToolbox

class Face: NSObject {
    enum FaceState {
        case running
        case finishing
        case finished
    }
    
    var assetWriter:AVAssetWriter!
    var writeInput:AVAssetWriterInput!
    var bufferAdapter:AVAssetWriterInputPixelBufferAdaptor!
    var size = Constants.videoSize
    let faceSide: CIFaceSide = .right
    var startTime: CMTime
    var lastPresentationTime = CMTime.zero
    let preview = CALayer()
    let imageQueue = DispatchQueue(label: "Image Queue", qos:.userInteractive)
    let recordQueue = DispatchQueue(label: "Record Queue", qos:.default)
//    let lockQueue = DispatchQueue(label: "Lock queue")
    
    var layer: FaceLayer?
    
    var state  = FaceState.running
    //var recordQueueSuspended = true
    
    
    init(time: CMTime) {
        startTime = time
        super.init()
        //recordQueue.suspend()
        do {
            assetWriter = try AVAssetWriter(url:uniqueURL() , fileType: AVFileType.mp4)
        } catch {
            return
        }
        
        // Setup recordung
        let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                            AVVideoWidthKey: self.size.width,
                                            AVVideoHeightKey: self.size.height]
        writeInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        writeInput.expectsMediaDataInRealTime = true
        
        assert(self.assetWriter.canAdd(self.writeInput), "adding AVAssetWriterInput failed")
        assetWriter.add(self.writeInput)
        let bufferAttributes:[String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)]
        bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writeInput, sourcePixelBufferAttributes: bufferAttributes)
        
        assetWriter!.startWriting()
        assetWriter!.startSession(atSourceTime: CMTime.zero)
        
//        writeInput.requestMediaDataWhenReady(on: lockQueue, using: { [weak self] in
//            if (self?.recordQueueSuspended)! {
//                self?.recordQueue.resume()
//                self?.recordQueueSuspended = false
//            }
//        })
        
        // Setup preview layer
        preview.contentsGravity = CALayerContentsGravity.resizeAspect
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        preview.removeAllAnimations()
        
    }
    
    func update(_ inputImage: CIImage, context: CIContext, faceFeature: CIFaceFeature, time timestamp: CMTime) {
        imageQueue.async { [weak self] in
            guard let self = self, let pool = self.bufferAdapter?.pixelBufferPool else {
                return
            }
            
            let croppedImage = inputImage.croppedAndScaledToFace(faceFeature, faceSide: .right)
            
            if self.state == .running {
                // Add image to preview
                let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent)
                DispatchQueue.main.async { [weak self] in
                    self?.preview.contents = cgImage
                }
            }
            

            // Add frame to buffer adapter
            self.recordQueue.async { [weak self] in
                guard let self = self else { return }
                
                guard let buffer = self.createPixelBuffer(croppedImage, pool: pool, withContext: context) else { return }
                
                let presentationTime =  CMTimeSubtract(timestamp, self.startTime)
                self.lastPresentationTime = presentationTime
                
                while !self.writeInput.isReadyForMoreMediaData { usleep(10) }
                
                self.bufferAdapter.append(buffer, withPresentationTime: presentationTime)
            }
        }
    }
    
    func createPixelBuffer(_ image:CIImage, pool: CVPixelBufferPool, withContext context : CIContext) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil
        //        let options: [NSObject: Any] = [
        //            kCVPixelBufferCGImageCompatibilityKey: false,
        //            kCVPixelBufferCGBitmapContextCompatibilityKey: false,
        //            ]
        let size = image.extent.size
        
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        
        //        let status = CVPixelBufferCreate(kCFAllocatorDefault,
        //                                         Int(size.width),
        //                                         Int(size.height),
        //                                         Constants.pixelFormat,
        //                                         options as CFDictionary,
        //                                         &pixelBuffer)
        if(status == kCVReturnSuccess) {
            context.render(image, to: pixelBuffer!, bounds:CGRect(x: 0,
                                                                  y: 0,
                                                                  width: size.width,
                                                                  height: size.height),
                           colorSpace: image.colorSpace)
        }
        return pixelBuffer
    }
    func cleanup() {
        state = .finishing
        //        if recordQueueSuspended {
        //            recordQueue.resume()
        //        }
        recordQueue.async {
            self.finishRecording()
        }
    }
    
    func finishRecording() {
        self.writeInput.markAsFinished()
        let elapsed = CMTimeGetSeconds(self.lastPresentationTime)
        let attrs = try! FileManager.default.attributesOfFileSystem(forPath: Constants.directoryURL.path)
        let diskSpace = attrs[FileAttributeKey.systemFreeSize] as! Int
        
        // Longer than minimumSecs and at least 4GB free on volume
        if(elapsed < Constants.minimumSecs) {
            self.assetWriter.cancelWriting()
            debug(String(format: "Dropped Recording with %.2f secs", elapsed))
            self.state = .finished
        } else if (diskSpace/1024/1024/1024) < Constants.minFreeGB {
            self.assetWriter.cancelWriting()
            alert("Not enough free space, only \((diskSpace/1024/1024/1024))GB left!")
            self.state = .finished
        } else {
            let url = self.assetWriter.outputURL
            assetWriter?.finishWriting {
                debug("Finished Writing", url.lastPathComponent)
                NotificationCenter.default.post(name: Notification.Name("newRecording"),
                                                object: url,
                                                userInfo: nil)
                self.state = .finished
            }
        }
    }
}

