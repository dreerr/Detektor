import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var player: FacePlayer?
    var matrixLayers = [CALayerMatrix]()
    var windows = [NSWindow]()
    var inFullscreen = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        var layerTiles = [CALayer]()
        
        // Create new window
        guard let screen = NSScreen.screens.last else {return}
        let window = NSWindow(contentRect: NSMakeRect(screen.frame.origin.x,
                                                      screen.frame.origin.y,
                                                      screen.frame.size.width*(CGFloat(Constants.aspectRatio)),
                                                      screen.frame.size.height),
                              styleMask: [.closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.contentView?.wantsLayer = true
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
        guard let windowLayer = window.contentView?.layer else {return}
        windowLayer.backgroundColor = NSColor.black.cgColor
        windowLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        
        // Initialize CALayerMatrix
        let layerMatrix = CALayerMatrix(withCols: 1, rows: 1)
        layerMatrix.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layerMatrix.frame = windowLayer.bounds
        windowLayer.addSublayer(layerMatrix)
        matrixLayers.append(layerMatrix)
        layerTiles.append(contentsOf: layerMatrix.sublayers!)

    
        // Initialize FacePlayer with the sublayers of CALayerMatrix array
        player = FacePlayer(withLayers: layerTiles)
        
        //self.toggleFullscreen(self)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Finish all recordings
        // DISCUSS: It is odd that deinit does not take care of that but whatever
        guard let tracker = player?.tracker else {return}
        tracker.faces.values.forEach{ $0.finishRecording() }
    }
    
    // Toggle play/pause of all videos and live footage
    @IBAction func togglePlayingState(_ sender: Any) {
        player?.isPlaying = !(player!.isPlaying)
    }
    
    // Toggle debug infos
    @IBAction func toggleDebug(_ sender: Any) {
        // Connect FaceTracker to matrix and preview
        if player?.tracker?.previewLayer == nil {
            if let layer = windows[0].contentView?.layer {
                player?.tracker?.connectDebug(layer)
            }
        } else {
            player?.tracker?.disconnectDebug()
        }
    }
    @IBAction func terminateAndShutdown(_ sender: Any) {
        let source = "tell application \"Finder\"\nshut down\nend tell\ntell application \"Observers\" to quit"
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(nil)
        //        NSApp.terminate(nil)
    }
    
    @IBAction func toggleFullscreen(_ sender: Any) {
        setFullscreen(windows[0].contentView?.isInFullScreenMode==false)
    }
    
    func setFullscreen(_ goFullscreen:Bool) {
        if(goFullscreen) {
            //NSCursor.hide()
            //            NSApp.presentationOptions = [
            //                .disableProcessSwitching,
            //                .disableForceQuit,
            //                .disableHideApplication,
            //                .disableSessionTermination,
            //                .hideDock,
            //                .fullScreen
            //            ]
            for (_, window) in windows.enumerated() {
                guard let view = window.contentView else {continue}
                guard let screen = window.screen else{continue}
                view.enterFullScreenMode(screen,
                                         withOptions: [NSView.FullScreenModeOptionKey.fullScreenModeSetting: true,
                                                       NSView.FullScreenModeOptionKey.fullScreenModeAllScreens: false])
                guard let layer = view.layer?.sublayers?[0] else {continue}
                layer.frame =  layer.superlayer!.bounds
            }
        } else {
            NSCursor.unhide()
            NSApp.presentationOptions = []
            windows.forEach({ (window) in
                window.contentView?.exitFullScreenMode(options: [NSView.FullScreenModeOptionKey.fullScreenModeSetting: false])
                guard let layer = window.contentView?.layer?.sublayers?[0] else {return}
                layer.frame =  layer.superlayer!.bounds
            })
        }
    }
}
