//
//  AppDelegate.swift
//  Detektor
//
//  Created by Julian on 26.08.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

//    @IBOutlet weak var window: NSWindow!

    var player: FacePlayer?
    let window = NSWindow()
    var inFullscreen = false
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //var layerTiles = [CALayer]()
        
        // Create new window for each screen
        let screen = NSScreen.main!;
        let window = NSWindow(contentRect: NSMakeRect(screen.frame.origin.x,
                                                      screen.frame.origin.y,
                                                      screen.frame.size.height*CGFloat(Constants.aspectRatio),
                                                      screen.frame.size.height),
                              styleMask: [.closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.contentView?.wantsLayer = true
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        guard let windowLayer = window.contentView?.layer else {return}
        windowLayer.backgroundColor = NSColor.black.cgColor
        let layer = CALayer()
        layer.frame = windowLayer.bounds
        windowLayer.addSublayer(layer)
        player = FacePlayer(withLayers: [layer])
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

