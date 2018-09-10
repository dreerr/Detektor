//
//  FaceTracker.swift
//  Observers
//
//  Created by Julian on 23.01.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//


import Cocoa
import Foundation
import AVFoundation
import Vision

class FaceTracker: NSObject {
    let captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayerRects = CALayer()
    
    // OLD
    let detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: nil,
                                  options: [CIDetectorAccuracy : CIDetectorAccuracyLow,
                                            CIDetectorTracking: true,
                                            CIDetectorMinFeatureSize: 0.01,
                                            CIDetectorNumberOfAngles: 1])
    let context = CIContext()
    var recordings = [Int32 : FaceRecorder]()
    var previews = [Int32 : CALayer]()
    var delegate: FaceTrackerProtocol?
    var queue: DispatchQueue?
    var isTracking = true
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    override init() {
        super.init()
        self.prepareVisionRequest()
        
        // Get AVCaptureDevice
        if let device = (AVCaptureDevice.devices(withNameContaining: "USB 2.0 Camera")?.first) {
            guard let format = device.formats.filter({ (format) -> Bool in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width == 1280 && dimensions.height == 720
            }).first else { return }
            try! device.lockForConfiguration()
            device.activeFormat = format
            device.unlockForConfiguration()
            captureDevice = device
        }
        if captureDevice == nil {
            if let device = (AVCaptureDevice.devices(withNameContaining: "FaceTime HD Camera")?.first) {
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
        //output.alwaysDiscardsLateVideoFrames = true
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
    
    fileprivate func prepareVisionRequest() {
        
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                    return
            }
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceRequestHandler = VNSequenceRequestHandler()
        
        //self.setupVisionDrawingLayers()
    }
}



extension AVCaptureDevice {
    static func devices(withNameContaining name: String) -> [AVCaptureDevice]? {
        return AVCaptureDevice.devices().filter { return $0.localizedName.contains(name) }
    }
}
