//
//  Constants.swift
//  Detektor
//


import Cocoa
import CoreGraphics

struct Constants {
    
    #if DETEKTOR
    static let cols = 1
    static let rows = 1
    static let aspectRatio: Float = 1080 / (1920*3) // 24px Tile Compensation?
    #else
    static let cols = 4
    static let rows = 3
    static let aspectRatio = (1080/Float(cols)) / (1920/Float(rows))
    #endif
    static let videoWidth = 144.0
    static let videoSize: CGSize = CGSize(width: videoWidth, height: round(videoWidth/Double(aspectRatio)))
    static let directoryName = Bundle.main.infoDictionary!["CFBundleName"] as! String
    static let pixelFormat = kCVPixelFormatType_32BGRA
    static let minimumSecs : CFTimeInterval = 3.0
    static var pause = false
    static let minFreeGB = 4
    
    static let intervals = ["14 Days": -60*60*24*14, "30 Days": -60*60*24*30, "3 Months": -60*60*24*90] as [String:Double]
    
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
}
