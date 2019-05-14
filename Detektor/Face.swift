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
    var presentationTime = CMTime.zero
    let preview = CALayer()
    //let imageQueue = DispatchQueue(label: "Image Queue", qos:.background)
//    let recordQueue = DispatchQueue(label: "Record Queue", attributes:[])
    var record = false
    var layer: FaceLayer?
    init(recording: Bool, time: CMTime) {
        record = recording
        startTime = time
        super.init()
        
        if(record) {
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
            assetWriter!.startSession(atSourceTime: presentationTime)
        }
        
        // Setup preview layer
        preview.contentsGravity = CALayerContentsGravity.resizeAspect
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        preview.removeAllAnimations()
        
    }
    
    func append(_ buffer: CVPixelBuffer, time timestamp: CMTime) {
        // Add frame to buffer adapter
        if(record) {
            //recordQueue.async {
                if self.writeInput!.isReadyForMoreMediaData {
                    self.presentationTime =  CMTimeSubtract(timestamp, self.startTime)
                    self.bufferAdapter.append(buffer, withPresentationTime: self.presentationTime)
                }
            //}
        }
        // Add image to preview
        //imageQueue.async {
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
            DispatchQueue.main.async {
                self.preview.contents = cgImage
            }
        //}
    }
    
    func finishRecording() {
        if(record) {
            //recordQueue.sync {
                self.writeInput.markAsFinished()
                let elapsed = CMTimeGetSeconds(self.presentationTime)
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
                    let url = self.assetWriter.outputURL
                    self.assetWriter.finishWriting {
                        debug("Finished Writing", url.lastPathComponent)
                        NotificationCenter.default.post(name: Notification.Name("newRecording"),
                                                        object: url,
                                                        userInfo: nil)
                    }
                }
            //}
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
    deinit {
        finishRecording()
    }
}

