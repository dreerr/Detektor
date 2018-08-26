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

class FaceTracker: NSObject {
    let captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayerRects = CALayer()
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
    
    override init() {
        super.init()
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
}

extension AVCaptureDevice {
    static func devices(withNameContaining name: String) -> [AVCaptureDevice]? {
        return AVCaptureDevice.devices().filter { return $0.localizedName.contains(name) }
    }
}
