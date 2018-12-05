//
//  Constants.swift
//  Detektor
//


import Cocoa
import CoreGraphics

struct Constants {
    static let aspectRatio: Float = 1/((1920*3)/1080) // 24px Tile Compensation?
    static let videoHeight = 320.0
    static let videoSize: CGSize = CGSize(width: videoHeight*Double(aspectRatio), height: videoHeight)
    static let directoryName = "Detektor"
    static let pixelFormat = kCVPixelFormatType_32ARGB
    static let minimumSecs : CFTimeInterval = 3.5
    static var pause = false
    static let minFreeGB = 4
    static let timeIntervalLimit : Double = -60*60*24*14 //   -60*60*24*14
    
    static var directoryURL: URL {
        var url = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        url.appendPathComponent(Constants.directoryName, isDirectory: true)
        var isDirectory = ObjCBool(true)
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            // TODO: fail gracefully!
            try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }
    var debug = true
}

func registerUserDefaults() {
    UserDefaults.standard.register(defaults: [
        "High Accuracy": true,
        "Feature Size": 0.01,
        "Angles": 1,
        "Full Screen": false
    ])
    syncPrefsMenu()
}
func syncPrefsMenu() {
    let defaults = UserDefaults.standard
    let prefsMenu = NSApplication.shared.mainMenu!.items.filter(){ $0.title == "Preferences" }.first
    for item in (prefsMenu?.submenu?.items)! {
        if item.title == "Use High Accuracy" {
            item.state = (defaults.bool(forKey: "High Accuracy") ? .on : .off)
        }
        for subitem in item.submenu?.items ?? [] {
            if item.title == "Minimum Feature Size" {
                let size = Float(subitem.title.suffix(4))
                subitem.state = defaults.float(forKey: "Feature Size") == size ? .on : .off
            } else if item.title == "Face Angles" {
                let angles = Int(subitem.title.suffix(1))
                subitem.state = defaults.integer(forKey: "Angles") == angles ? .on : .off
            }
        }
    }
    alert("High Accuracy: \(defaults.bool(forKey: "High Accuracy") ? "Yes": "No")")
    alert("Minimum Feature Size: \(defaults.float(forKey: "Feature Size"))")
    alert("Face Angles: \(defaults.integer(forKey: "Angles"))")
}
