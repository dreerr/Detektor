import CoreImage
extension CIImage {
    func croppedAndScaledToFace(_ face:CIFaceFeature, faceSide:CIFaceSide) -> CIImage {
        // Calculate Rectangle and resize image
        let rect = face.boundsForFaceSide(faceSide, withAspectRatio: Constants.aspectRatio)
        let scaleFactor = (Constants.videoSize.height+3.0) / rect.size.height
        let transform = CGAffineTransform(translationX:-rect.minX-0.5, y: -rect.minY-0.5)
            .concatenating(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        let finalRect = CGRect(x: 0, y: 0, width: Constants.videoSize.width, height: Constants.videoSize.height)
        let image = self.cropped(to: rect).transformed(by: transform).cropped(to: finalRect)
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
        #if DETEKTOR
        newBounds.size.width *= 1.3
        newBounds.size.height *= 1.3
        newBounds.origin.y -= newBounds.size.height * 0.09
        #endif
        return newBounds
    }
}


extension AVCaptureDevice {
    static func devices(withNameContaining name: String) -> [AVCaptureDevice]? {
        return AVCaptureDevice.devices().filter { return $0.localizedName.contains(name) }
    }
    static func device(withUniqueID id: String?) -> AVCaptureDevice? {
        return AVCaptureDevice.devices().filter{ return $0.uniqueID == id }.first
    }
}

extension CATransaction {
    class func withDisabledActions<T>(_ body: () throws -> T) rethrows -> T {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        return try body()
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
