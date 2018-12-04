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
