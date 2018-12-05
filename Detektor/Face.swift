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
    let imageQueue = DispatchQueue(label: "Image Queue", qos:.background)
    let recordQueue = DispatchQueue(label: "Record Queue", attributes:[])
    var record = false
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
            assert(self.assetWriter.canAdd(self.writeInput), "add AVAssetWriterInput failed")
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
            recordQueue.async {
                if self.writeInput!.isReadyForMoreMediaData {
                    self.presentationTime =  CMTimeSubtract(timestamp, self.startTime)
                    self.bufferAdapter.append(buffer, withPresentationTime: self.presentationTime)
                }
            }
        }
        // Add image to preview
        imageQueue.async {
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
            DispatchQueue.main.async {
                self.preview.contents = cgImage
            }
        }
    }
    
    func finishRecording() {
        if(record) {
            recordQueue.sync {
                self.writeInput.markAsFinished()
                let elapsed = CMTimeGetSeconds(self.presentationTime)
                let attrs = try! FileManager.default.attributesOfFileSystem(forPath: Constants.directoryURL.path)
                let diskSpace = attrs[FileAttributeKey.systemFreeSize] as! Int
                
                // Longer than minimumSecs and at least 4GB free on volume
                if(elapsed > Constants.minimumSecs && (diskSpace/1024/1024/1024) > Constants.minFreeGB) {
                    let url = self.assetWriter.outputURL
                    self.assetWriter.finishWriting {
                        print("finished writing movie at", url)
                        NotificationCenter.default.post(name: Notification.Name("newRecording"),
                                                        object: url,
                                                        userInfo: nil)
                    }
                } else {
                    self.assetWriter.cancelWriting()
                    print(String(format: "dropped recording with %.2f secs", elapsed))
                }
                let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(diskSpace), countStyle: .file)
                print("Free size on volume: \(fileSizeWithUnit)")
            }
        }
    }
    
    func uniqueURL() -> URL {
        var url = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        url.appendPathComponent(Constants.directoryName, isDirectory: true)
        var isDirectory = ObjCBool(true)
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            // TODO: fail gracefully!
            try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        let faceSideString = faceSide == .left ? "left" : "right"
        url.appendPathComponent(String(format:"%@-%@.mp4", faceSideString, UUID().uuidString))
        return url
    }
    deinit {
        finishRecording()
    }
}

