import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var player: FaceDisplay?
    var matrixLayers = [CALayerMatrix]()
    var windows = [NSWindow]()
    var inFullscreen = false

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        observeShutdownDialog()
        var layerTiles = [CALayer]()
        
        // Create new window
        guard let screen = NSScreen.screens.last else {return}
        let window = NSWindow(contentRect: NSMakeRect(screen.frame.origin.x,
                                                      screen.frame.origin.y,
                                                      screen.frame.size.height*CGFloat(1080.0/1920.0), //screen.frame.size.width*(CGFloat(Constants.aspectRatio)),
                                                      screen.frame.size.height), //screen.frame.size.height),
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
        
        // Initialize CALayerMatrix and append to window
        let layerMatrix = CALayerMatrix(withCols: 1, rows: 1)
        layerMatrix.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layerMatrix.frame = windowLayer.bounds
        windowLayer.addSublayer(layerMatrix)
        matrixLayers.append(layerMatrix)
        layerTiles.append(contentsOf: layerMatrix.sublayers!)
        
        // Transform layer for streched screen: Make it three times bigger then squeeze
        windowLayer.sublayerTransform = CATransform3DMakeScale(1.0, 1.0/3.0, 1.0)
        layerMatrix.frame = NSRect(origin: windowLayer.bounds.origin, size: CGSize(width: windowLayer.bounds.width, height: windowLayer.bounds.height*3.0))
        
        
        // Init debug OSD
        _ = OSDLogLayer(withLayer: layerMatrix)
        print("Observer v1.0")
        
        // Initialize FacePlayer with the sublayers of CALayerMatrix array
        player = FaceDisplay(withLayers: layerTiles)
        //self.toggleFullscreen(self)
        
        // Observe Sleep Status
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
            print("Sleep")
            //self.setFullscreen(false)
        }
        notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
            print("Wake up")
            //self.setFullscreen(true)
        }
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
        let source = "tell application \"Finder\"\nshut down\nend tell\ntell application \"Detektor\" to quit"
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(nil)
        //        NSApp.terminate(nil)
    }
    
    func observeShutdownDialog() {
        let notification = "com.apple.shutdownInitiated" as CFString
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())

        CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), observer, { (center, observer, name, _, userInfo) in
            let mySelf = Unmanaged<AppDelegate>.fromOpaque(observer!).takeUnretainedValue()
            mySelf.pressCancel()
        }, notification, nil, .deliverImmediately)
    }
    
    func pressCancel() {
        __NSBeep()
    }
    
    @IBAction func toggleFullscreen(_ sender: Any) {
        setFullscreen(windows[0].contentView?.isInFullScreenMode==false)
    }
    
    func setFullscreen(_ goFullscreen:Bool) {
        if(goFullscreen) {
            NSCursor.hide()
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
                guard let screen = window.screen else {continue}
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
        windows.first?.makeKeyAndOrderFront(self)
    }
}
