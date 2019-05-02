import Cocoa
import Foundation
import AVFoundation
import VideoToolbox

class FaceTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayerRects = CALayer()
    let defaults = UserDefaults.standard
    
    var detector: CIDetector?
    var detectorFeatures: [CIFeature]?
    let context = CIContext()
    var faces = [Int32 : Face]()
    var delegate: FaceTrackerProtocol?
    var captureQueue = DispatchQueue(label: "Capture Queue",
                                     qos: .userInteractive,
                                     autoreleaseFrequency: .workItem,
                                     target: nil)
    let detectorQueue = DispatchQueue(label: "Face Recognition Queue", qos:.userInteractive)
    var isTracking = true
    
    override init() {
        super.init()
        
        
        
        // Configure Capture Session
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        // Configure AVCaptureVideoDataOutput and set Delegate
        let output = AVCaptureVideoDataOutput()
        //output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: Constants.pixelFormat)]
        captureSession.addOutput(output)
        captureSession.commitConfiguration()
        output.setSampleBufferDelegate(self, queue: captureQueue)
        
        connectDefaultDevice()
        initDetector()
        let mainQueue = OperationQueue.main
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CameraChange"), object: nil, queue: mainQueue) { (_) in
            self.connectDefaultDevice()
        }
    }
    
    func connectDefaultDevice() {
        guard let device = AVCaptureDevice.device(withUniqueID: UserDefaults.standard.string(forKey: "Camera")) else {
            alert("Default camera not found! Please select in Preferences!")
            return
        }
        guard let defaultDimensions = UserDefaults.standard.array(forKey: "Camera Format") else {return}
        let deviceFormat = device.formats.first {
            let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return (dimensions.width == (defaultDimensions[0] as! Int)) && (dimensions.height == (defaultDimensions[1] as! Int))
        }
        guard let format = deviceFormat else {
            alert("Default format not found! Please select in Preferences!")
            return
        }
        connectDevice(device, withFormat: format)
    }
    
    func connectDevice(_ device: AVCaptureDevice, withFormat format: AVCaptureDevice.Format) {
        if(!device.formats.contains(format)) { alert("Invalid format to connect to!") }
        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) } // remove old inputs
        
        // Configure device format
        try! device.lockForConfiguration()
        //        device.activeFormat = format
        //        let fps = CMTimeMake(value: 20, timescale: 600) // 30 fps
        //        device.activeVideoMinFrameDuration = fps
        //        device.activeVideoMaxFrameDuration = fps
        //        device.exposureMode = .locked
        device.unlockForConfiguration()
        
        
        // Add to capture session
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: device))
        } catch let error as NSError {
            print("Camera Error: \(error.localizedDescription)")
        }
        captureDevice = device
        captureSession.commitConfiguration()
        captureQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func initDetector() {
        let accuracy = (UserDefaults.standard.bool(forKey: "High Accuracy") ? CIDetectorAccuracyHigh : CIDetectorAccuracyLow)
        let featureSize = UserDefaults.standard.float(forKey: "Feature Size")
        let angles = UserDefaults.standard.integer(forKey: "Angles")
        detector = CIDetector(ofType: CIDetectorTypeFace,
                              context: nil,
                              options: [CIDetectorAccuracy : accuracy,
                                        CIDetectorTracking: true,
                                        CIDetectorMinFeatureSize: featureSize,
                                        CIDetectorNumberOfAngles: angles,
                                        CIDetectorMaxFeatureCount: 4])
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Check if we should track
        guard isTracking == true else {return}
        
        // Get Image Buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: sampleBuffer,
                                                        attachmentMode: kCMAttachmentMode_ShouldPropagate)
        let ciImageRaw = CIImage(cvImageBuffer: imageBuffer,
                                 options: (attachments as! [CIImageOption : Any]))
        
        // Recognize faces on other queue?
        captureQueue.async {
            let options: [String : Any] = [CIDetectorTypeFace: true]
            self.detectorFeatures = self.detector?.features(in: ciImageRaw, options: options)
        }
        guard let features = detectorFeatures else { return }
        drawDebug(features) // only executed if connected
        
        // Collect all IDs to check for orphans
        var currentIDs = [Int32]()
        
        // Apply filter to image
        let ciImage = applyFilterChain(to: ciImageRaw)
        var isFirst = true
        for feature in features {
            guard let faceFeature = feature as? CIFaceFeature else {continue}
            if(faceFeature.hasTrackingFrameCount && faceFeature.trackingFrameCount > 10) {
                // Keep track of the ID
                let id = faceFeature.trackingID
                currentIDs.append(id)
                if(!self.faces.keys.contains(id)) {
                    // Initialize Face instance for each new face that stayed longer than 10 frames
                    print("new face", id)
                    let face = Face(recording: isFirst, time: timestamp)
                    self.delegate?.addLiveFace(face, id: id)
                    self.faces[id] = face
                    isFirst = false
                }
                guard let face = self.faces[id] else { continue }
                captureQueue.async {
                    let image = ciImage.croppedAndScaledToFace(faceFeature, faceSide: .right)
                    if let buffer = image.createPixelBuffer(withContext: self.context) {
                        face.append(buffer, time: timestamp)
                    }
                    
                }
            }
        }
        
        // Check for orphans and properly remove them (calls deinit)
        for orphan in Set(self.faces.keys).subtracting(currentIDs) {
            print("lost face", orphan)
            self.delegate?.removeLiveFace(id: orphan)
            self.faces.removeValue(forKey: orphan)
        }
    }
    
    func applyFilterChain(to image: CIImage) -> CIImage {
        let colorFilter = CIFilter(name: "CIExposureAdjust",
                                   parameters: [kCIInputImageKey: image,
                                                "inputEV": defaults.float(forKey: "Image EV")])!
        let parameters = [
            "inputBrightness": defaults.float(forKey: "Image Brightness"),
            "inputContrast": defaults.float(forKey: "Image Contrast"),
            "inputSaturation": defaults.float(forKey: "Image Saturation")
        ]
        let exposureImage = colorFilter.outputImage!.applyingFilter("CIColorControls", parameters:parameters)
        return exposureImage
    }
}

protocol FaceTrackerProtocol {
    func addLiveFace(_ face: Face, id: Int32)
    func removeLiveFace(id: Int32)
}
