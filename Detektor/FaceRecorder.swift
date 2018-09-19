import Foundation
import AVFoundation

class FaceRecorder: NSObject {
    var assetWriter:AVAssetWriter!
    var writeInput:AVAssetWriterInput!
    var bufferAdapter:AVAssetWriterInputPixelBufferAdaptor!
    var size = Constants.videoSize
    let faceSide: CIFaceSide
    var startTime: CMTime
    var presentationTime: CMTime
    
    init(withFaceSide side: CIFaceSide, time: CMTime) {
        faceSide = side
        startTime = time
        presentationTime = kCMTimeZero
        super.init()
        do {
            assetWriter = try AVAssetWriter(url:self.uniqueURL() , fileType: AVFileType.mp4)
        } catch {
            return
        }
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
    
    func append(_ buffer: CVPixelBuffer, time timestamp: CMTime) {
        if writeInput!.isReadyForMoreMediaData {
            presentationTime =  CMTimeSubtract(timestamp, startTime)
            self.bufferAdapter.append(buffer, withPresentationTime: self.presentationTime)
        }
    }
    
    func finishRecording() {
        writeInput.markAsFinished()
        let elapsed = CMTimeGetSeconds(presentationTime)
        let attrs = try! FileManager.default.attributesOfFileSystem(forPath: Constants.directoryURL.path)
        let diskSpace = attrs[FileAttributeKey.systemFreeSize] as! Int
        
        // Longer than minimumSecs and at least 4GB free on volume
        if(elapsed > Constants.minimumSecs && (diskSpace/1024/1024/1024) > Constants.minFreeGB) {
            let url = assetWriter.outputURL
            assetWriter.finishWriting {
                print("finished writing movie at", url)
                NotificationCenter.default.post(name: Notification.Name("newRecording"),
                                                object: url,
                                                userInfo: nil)
            }
        } else {
            assetWriter.cancelWriting()
            print(String(format: "dropped recording with %.2f secs", elapsed))
            let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(diskSpace), countStyle: .file)
            print("Free size on volume: \(fileSizeWithUnit)")
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

