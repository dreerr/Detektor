import Foundation
import AVFoundation
import VideoToolbox

class Face: NSObject {
    var assetWriter:AVAssetWriter!
    var writeInput:AVAssetWriterInput!
    var bufferAdapter:AVAssetWriterInputPixelBufferAdaptor!
    var size = Constants.videoSize
    let faceSide: CIFaceSide = .right
    var startTime: CMTime
    var lastPresentationTime = CMTime.zero
    let preview = CALayer()
    let imageQueue = DispatchQueue(label: "Image Queue", qos:.userInteractive)
    let recordQueue = DispatchQueue(label: "Record Queue", qos:.userInitiated)
    let lockQueue = DispatchQueue(label: "Lock queue")
    
    
    var todo: [(CVPixelBuffer, CMTime)] = []
    
    var record = false
    var layer: FaceLayer?
    
    var inactive = false
    
    init(time: CMTime) {
        startTime = time
        super.init()
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
        
        writeInput.requestMediaDataWhenReady(on: lockQueue, using: { [weak self] in
            guard let self = self, !self.shutdown else { return }
            while (self.writeInput.isReadyForMoreMediaData && !self.todo.isEmpty) {
                let (buff, ts) = self.todo.removeFirst()
                self.bufferAdapter.append(buff, withPresentationTime: ts)
            }
            if self.todo.count > 0 { NSLog("Remain = %d", self.todo.count) }
        })
        
        
        
        // Setup preview layer
        preview.contentsGravity = CALayerContentsGravity.resizeAspect
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        preview.removeAllAnimations()
        
    }
    
    func update(_ inputImage: CIImage, context: CIContext, faceFeature: CIFaceFeature, time timestamp: CMTime) {
        if inactive { return }
        imageQueue.async { [weak self] in
            guard let self = self, let pool = self.bufferAdapter?.pixelBufferPool else {
                return
            }
            
            let croppedImage = inputImage.croppedAndScaledToFace(faceFeature, faceSide: .right)
            
            // Add image to preview
            let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent)
            DispatchQueue.main.async { [weak self] in
                self?.preview.contents = cgImage
            }
            
            guard let buffer = self.createPixelBuffer(croppedImage, pool: pool, withContext: context) else { return }
            
            
            // Add frame to buffer adapter
            if(self.record) {
                self.lockQueue.async { [weak self] in
                    guard let self = self else { return }
                    let presentationTime =  CMTimeSubtract(timestamp, self.startTime)
                    self.lastPresentationTime = presentationTime
                    if self.writeInput.isReadyForMoreMediaData {
                        self.bufferAdapter.append(buffer, withPresentationTime: presentationTime)
                    } else {
                        self.todo.append((buffer, presentationTime))
                    }
                }
            }
        }
    }
    
    func cleanup() {
        lockQueue.sync {
            self.inactive = true
            self.finishRecording()
        }
    }
    
    func finishRecording() {
        if(record) {
            self.writeInput.markAsFinished()
            let elapsed = CMTimeGetSeconds(self.lastPresentationTime)
            let attrs = try! FileManager.default.attributesOfFileSystem(forPath: Constants.directoryURL.path)
            let diskSpace = attrs[FileAttributeKey.systemFreeSize] as! Int
            
            // Longer than minimumSecs and at least 4GB free on volume
            if(elapsed < Constants.minimumSecs) {
                self.assetWriter.cancelWriting()
                debug(String(format: "Dropped Recording with %.2f secs", elapsed))
            } else if (diskSpace/1024/1024/1024) < Constants.minFreeGB {
                self.assetWriter.cancelWriting()
                alert("Not enough free space, only \((diskSpace/1024/1024/1024))GB left!")
            } else {
                let assetWriter = self.assetWriter
                let url = assetWriter?.outputURL
                //                recordQueue.activate()
                //                recordQueue.sync {
                NSLog("Deiniting with %d items in todo", self.todo.count)
                assetWriter?.finishWriting {
                    debug("Finished Writing", url?.lastPathComponent)
                    NotificationCenter.default.post(name: Notification.Name("newRecording"),
                                                    object: url,
                                                    userInfo: nil)
                }
                //                }
            }
        }
    }
    
    func uniqueURL() -> URL {
        let manager = FileManager.default
        var directory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        directory.appendPathComponent(Constants.directoryName, isDirectory: true)
        var isDirectory = ObjCBool(true)
        if !manager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            // TODO: fail gracefully!
            try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        let dateFormatter : DateFormatter = DateFormatter()
        let date = Date()
        dateFormatter.dateFormat = "yyyy.MM.dd - HH.mm.ss"
        let dateString = dateFormatter.string(from: date)
        var url = directory.appendingPathComponent(String(format:"%@.mp4", dateString), isDirectory: false)
        
        var idx = 1
        while manager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            url = directory.appendingPathComponent("\(dateString) (\(idx)).mp4", isDirectory: false)
            idx+=1
        }
        
        return url
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
}

