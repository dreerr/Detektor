//
//  Preferences.swift
//  Detektor
//
//  Created by Julian on 08.12.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import Cocoa

class Preferences: NSWindowController {
    @IBOutlet weak var highAccuracy: NSButton?
    @IBOutlet weak var featureSize: NSPopUpButton?
    @IBOutlet weak var faceAngles: NSPopUpButton?
    
    @IBOutlet weak var deleteImmediately: NSButton?
    @IBOutlet weak var keepRecordings: NSPopUpButton?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
//        highAccuracy?.bind(NSBindingName(rawValue: "state"),
//                           to: NSUserDefaultsController.shared,
//                           withKeyPath: "values.High Accuracy Button",
//                           options: [NSBindingOption.continuouslyUpdatesValue:true])
//        
//    
//        deleteImmediately?.bind(NSBindingName(rawValue: "state"),
//                                to: NSUserDefaultsController.shared,
//                                withKeyPath: "values.Delete Immediately",
//                                options: [NSBindingOption.continuouslyUpdatesValue:true])
//        
    }
}

func registerUserDefaults() {
    let defaults = UserDefaults.standard
    defaults.register(defaults: [
        "High Accuracy": true,
        "Feature Size": 0.01,
        "Angles": 1,
        "Full Screen": false,
        "Delete Immediately": false,
        "Keep Recordings": "14 Days",
        "Image Brightness": 0.0,
        "Image Contrast": 1.1,
        "Image Saturation": 0.0,
        "Image EV": 0.5,
        ])
    ValueTransformer.setValueTransformer(StringDoubleTransformer(), forName: NSValueTransformerName("StringDoubleTransformer"))
    ValueTransformer.setValueTransformer(StringIntTransformer(), forName: NSValueTransformerName("StringIntTransformer"))
    alert("High Accuracy: \(defaults.bool(forKey: "High Accuracy") ? "Yes": "No")")
    alert("Minimum Feature Size: \(defaults.float(forKey: "Feature Size"))")
    alert("Face Angles: \(defaults.integer(forKey: "Angles"))")
    alert("Keep Recordings: \(defaults.string(forKey: "Keep Recordings") ?? "Unknown")")
    alert("Delete Immediately: \(defaults.bool(forKey: "Delete Immediately") ? "Yes": "No")")
}

class StringDoubleTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let number = value as? Double else { return nil }
        return String(number)
    }
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let text = value as? String else { return nil }
        return Double(text)
    }
}

class StringIntTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let number = value as? Int else { return nil }
        return String(number)
    }
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let text = value as? String else { return nil }
        return Int(text)
    }
}
