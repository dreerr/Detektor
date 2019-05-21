import Foundation
import AVFoundation
import VideoToolbox

class Face: NSObject {
    enum FaceState {
        case running, finishing, finished
    }
    
    var assetWriter:AVAssetWriter!
    var writeInput:AVAssetWriterInput!
    var adaptor:AVAssetWriterInputPixelBufferAdaptor!
    let faceSide: CIFaceSide = .right
    var startTime: CMTime
    var elapsedTime = CMTime.zero
    let preview = CALayer()
    let imageQueue = DispatchQueue(label: "Image Queue", qos:.userInitiated)
    let recordQueue = DispatchQueue(label: "Record Queue", qos:.background)
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
                                            AVVideoWidthKey: Constants.videoSize.width,
                                            AVVideoHeightKey: Constants.videoSize.height]
        writeInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        writeInput.expectsMediaDataInRealTime = true
        
        assert(self.assetWriter.canAdd(self.writeInput), "adding AVAssetWriterInput failed")
        assetWriter.add(self.writeInput)
        let bufferAttributes:[String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)]
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writeInput, sourcePixelBufferAttributes: bufferAttributes)
        
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
            guard let self = self else { return }
            let croppedImage = inputImage.croppedAndScaledToFace(faceFeature, faceSide: .right)
            
            // If running add to preview layer
            if self.state == .running {
                let cgImage = context.createCGImage(croppedImage, from:croppedImage.extent)
                DispatchQueue.main.async {
                    self.preview.contents = cgImage
                }
            }
            
            // Add frame to buffer adapter
            self.recordQueue.async { [weak self] in
                guard let self = self else { return }
                guard let buffer = self.createPixelBuffer(croppedImage, withContext: context) else { NSLog("could not buffer!"); return }
                let presentationTime =  CMTimeSubtract(timestamp, self.startTime)
                self.elapsedTime = presentationTime
                while !self.writeInput.isReadyForMoreMediaData { NSLog("sleep"); usleep(400) }
                self.adaptor.append(buffer, withPresentationTime: presentationTime)
            }
        }
    }
    
    func createPixelBuffer(_ image:CIImage, withContext context : CIContext) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { NSLog("adaptor.pixelBufferPool is nil"); return nil }
        
        var pixelBuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        if(status == kCVReturnSuccess) {
            context.render(image, to: pixelBuffer!, bounds:CGRect(x: 0,
                                                                  y: 0,
                                                                  width: image.extent.size.width,
                                                                  height: image.extent.size.height),
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
        writeInput.markAsFinished()
        let elapsed = CMTimeGetSeconds(elapsedTime)
        let attrs = try! FileManager.default.attributesOfFileSystem(forPath: Constants.directoryURL.path)
        let diskSpace = attrs[FileAttributeKey.systemFreeSize] as! Int
        
        // Longer than minimumSecs and at least 4GB free on volume
        if(elapsed < Constants.minimumSecs) {
            assetWriter.cancelWriting()
            debug(String(format: "Dropped Recording with %.2f secs", elapsed))
            state = .finished
        } else if (diskSpace/1024/1024/1024) < Constants.minFreeGB {
            assetWriter.cancelWriting()
            alert("Not enough free space, only \((diskSpace/1024/1024/1024))GB left!")
            self.state = .finished
        } else {
            let url = assetWriter.outputURL
            assetWriter?.finishWriting {
                NotificationCenter.default.post(name: Notification.Name("newRecording"),
                                                object: url,
                                                userInfo: nil)
                debug("Finished Writing", url.lastPathComponent)
                self.state = .finished
            }
        }
    }
}

