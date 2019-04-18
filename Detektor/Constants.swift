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
    static let cols = 6
    static let rows = 2
    static let aspectRatio = (1920/Float(cols)) / (1080/Float(rows))
    #endif
    static let videoHeight = 320.0
    static let videoSize: CGSize = CGSize(width: videoHeight*Double(aspectRatio), height: videoHeight)
    static let directoryName = Bundle.main.infoDictionary!["CFBundleName"] as! String
    static let pixelFormat = kCVPixelFormatType_32ARGB
    static let minimumSecs : CFTimeInterval = 3.5
    static var pause = false
    static let minFreeGB = 4
    
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
