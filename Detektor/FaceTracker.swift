import Cocoa
import Foundation
import AVFoundation
import VideoToolbox

class FaceTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayerRects = CALayer()
    
    let detector = CIDetector(ofType: CIDetectorTypeFace,
                              context: nil,
                              options: [CIDetectorAccuracy : CIDetectorAccuracyHigh,
                                        CIDetectorTracking: true,
                                        CIDetectorMinFeatureSize: 0.01,
                                        CIDetectorNumberOfAngles: 1])
    var detectorFeatures: [CIFeature]?
    let context = CIContext()
    var faces = [Int32 : Face]()
    var delegate: FaceTrackerProtocol?
    var queue: DispatchQueue?
    let detectorQueue = DispatchQueue(label: "Face Recognition Queue", qos:.default)
    var isTracking = true
    
    
    override init() {
        super.init()
        
        // Get AVCaptureDevice
        if let device = (AVCaptureDevice.devices(withNameContaining: "USB 2.0 Camera")?.first) {
            guard let format = device.formats.filter({ (format) -> Bool in
                print(format)
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width == 1280 && dimensions.height == 720
                //                return dimensions.width == 1920 && dimensions.height == 1080
            }).first else { return }
            try! device.lockForConfiguration()
            device.activeFormat = format
            device.unlockForConfiguration()
            captureDevice = device
        }
        if captureDevice == nil {
            if let device = (AVCaptureDevice.devices(withNameContaining: "FaceTime")?.first) {
                try! device.lockForConfiguration()
                let fps = CMTimeMake(20, 600) // 30 fps
                device.activeVideoMinFrameDuration = fps
                device.activeVideoMaxFrameDuration = fps
                device.unlockForConfiguration()
                captureDevice = device
            }
        }
        guard captureDevice != nil else { return }
        
        // Configure Capture Session
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice!))
        } catch let error as NSError {
            print("Error: no valid camera input in \(error.domain)")
        }
        
        // Configure AVCaptureVideoDataOutput and set Delegate
        let output = AVCaptureVideoDataOutput()
        //output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: Constants.pixelFormat)]
        captureSession.addOutput(output)
        captureSession.commitConfiguration()
        
        // Create queue with high QoS and autorelease frequency
        queue = DispatchQueue(label: "at.palacz.observers.samplebuffer-queue",
                              qos: .userInteractive,
                              autoreleaseFrequency: .workItem,
                              target: nil)
        //        queue = DispatchQueue.global(qos: .userInteractive)
        
        output.setSampleBufferDelegate(self, queue: queue)
        captureSession.startRunning()
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Check if we should track
        guard isTracking == true else {return}
        
        // Get Image Buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        var ciImage = CIImage(cvImageBuffer: imageBuffer, options: attachments as! [String : Any]?)
        
        // Recognize faces on other queue
        detectorQueue.async {
            let options: [String : Any] = [CIDetectorTypeFace: true]
            self.detectorFeatures = self.detector?.features(in: ciImage, options: options)
        }
        guard let features = detectorFeatures else { return }
        drawDebug(features) // only executed if connected
        
        // Collect all IDs to check for orphans
        var currentIDs = [Int32]()
        
        // Apply filter to image
        ciImage = ciImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": 0.0,
                                                                         "inputContrast": 1.1,
                                                                         "inputSaturation": 0.0])
            .applyingFilter("CIExposureAdjust", parameters: ["inputEV": 0.5])
        
        detectorQueue.sync {
            for (index, feature) in features.enumerated() {
                guard let faceFeature = feature as? CIFaceFeature else {continue}
                if(faceFeature.hasTrackingFrameCount) {
                    // Keep track of the ID
                    let id = faceFeature.trackingID
                    currentIDs.append(id)
                    if(!faces.keys.contains(id) && faceFeature.trackingFrameCount > 10) {
                        // Initialize Face instance for each new face that stayed longer than 10 frames
                        print("new face", id)
                        let face = Face(recording: (index == 0), time: timestamp)
                        delegate?.addFace(face, id: id)
                        faces[id] = face
                    }
                    guard let face = faces[id] else { continue }
                    let image = ciImage.croppedAndScaledToFace(faceFeature, faceSide: .left)
                    guard let buffer = image.createPixelBuffer(withContext: context) else { continue }
                    face.append(buffer, time: timestamp)
                }
            }
        }
        
        // Check for orphans and properly remove them (calls deinit)
        for orphan in Set(faces.keys).subtracting(currentIDs) {
            print("lost face", orphan)
            delegate?.removeFace(id: orphan)
            faces.removeValue(forKey: orphan)
        }
    }
}

protocol FaceTrackerProtocol {
    func addFace(_ face: Face, id: Int32)
    func removeFace(id: Int32)
}
