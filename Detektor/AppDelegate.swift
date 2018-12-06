import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var display: FaceDisplay?
    var matrixLayers = [CALayerMatrix]()
    var windows = [NSWindow]()
    var inFullscreen = false
    let osd = OSDLogLayer()
    let defaults = UserDefaults.standard
    var shutdownHasStarted = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        observePowerStates()
        registerUserDefaults()
        var layerTiles = [CALayer]()
        
        // Create new window
        guard let screen = NSScreen.screens.last else {return}
        let window = NSWindow(contentRect: NSMakeRect(screen.frame.origin.x,
                                                      screen.frame.origin.y,
                                                      screen.frame.size.height*CGFloat(1080.0/1920.0),
                                                      screen.frame.size.height),
                              styleMask: [.closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.contentView?.wantsLayer = true
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
        guard let windowLayer = window.contentView?.layer else { return }
        windowLayer.backgroundColor = NSColor.black.cgColor
        windowLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // Initialize CALayerMatrix
        let layerMatrix = CALayerMatrix(withCols: 1, rows: 1)
        layerMatrix.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        matrixLayers.append(layerMatrix)
        layerTiles.append(contentsOf: layerMatrix.sublayers!)
        
        // Transform layer for streched screen: Make it three times bigger then squeeze
        let stretch = CALayerStretch()
        stretch.stretchRatio = 3.0
        windowLayer.addSublayer(stretch)
        windowLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        stretch.frame = windowLayer.bounds
        stretch.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        stretch.content.addSublayer(layerMatrix)
        layerMatrix.frame = stretch.content.bounds
        layerMatrix.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // Connect OSD
        osd.connect(to: stretch.content)
        let attrs = try! FileManager.default.attributesOfFileSystem(forPath: Constants.directoryURL.path)
        let diskSpace = attrs[FileAttributeKey.systemFreeSize] as! Int
        let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(diskSpace), countStyle: .file)
        alert("Free Size: \(fileSizeWithUnit)")
        
        // Initialize FacePlayer with the sublayers of CALayerMatrix array
        display = FaceDisplay(withLayers: layerTiles)
        
        // Set Fullscreen if it was before
        setFullscreen(defaults.bool(forKey: "Full Screen"))
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Finish all recordings
        // DISCUSS: It is odd that deinit does not take care of that but whatever
        guard let tracker = display?.tracker else { return }
        tracker.faces.values.forEach{ $0.finishRecording() }
    }
    
    @IBAction func togglePreferences(_ sender: Any) {
        guard let item = (sender as? NSMenuItem) else {return}
        if item.title == "Delete Immediately" {
            defaults.set(!defaults.bool(forKey: "Delete Immediately"), forKey: "Delete Immediately")
        } else if item.title == "Use High Accuracy" {
            defaults.set(!defaults.bool(forKey: "High Accuracy"), forKey: "High Accuracy")
            display?.tracker?.initDetector()
        } else if item.parent!.title.contains("Minimum Feature Size") {
            if let size = Float(item.title.suffix(4)) {
                defaults.set(size, forKey: "Feature Size")
            }
            display?.tracker?.initDetector()
        } else if item.parent!.title.contains("Face Angles") {
            if let angles = Int(item.title.suffix(1)) {
                defaults.set(angles, forKey: "Angles")
            }
            display?.tracker?.initDetector()
        } else if item.parent!.title.contains("Keep Recordings") {
            defaults.set(item.title, forKey: "Keep Recordings")
        }
        syncPrefsMenu()
    }
    
    
    // Toggle play/pause of all videos and live footage
//    @IBAction func togglePlayingState(_ sender: Any) {
//        display?.isPlaying = !(display!.isPlaying)
//    }
    
    // Toggle debug infos
    @IBAction func toggleDebug(_ sender: Any) {
        // Connect FaceTracker to matrix and preview
        if display?.tracker?.previewLayer == nil {
            if let layer = windows[0].contentView?.layer?.sublayers?.first?.sublayers?.first {
                display?.tracker?.connectDebug(layer)
            }
        } else {
            display?.tracker?.disconnectDebug()
        }
    }
    
    @IBAction func toggleFullscreen(_ sender: Any) {
        setFullscreen(windows[0].contentView?.isInFullScreenMode==false)
    }
    
    func setFullscreen(_ goFullscreen:Bool) {
        UserDefaults.standard.set(goFullscreen, forKey: "Full Screen")
        if(goFullscreen) {
            NSCursor.hide()
            let presOptions: NSApplication.PresentationOptions = [
                .fullScreen,
                .autoHideMenuBar
            ]
            let optionsDictionary = [
                .fullScreenModeApplicationPresentationOptions: presOptions,
                .fullScreenModeAllScreens: false
            ] as [NSView.FullScreenModeOptionKey : Any]
            for (_, window) in windows.enumerated() {
                guard let view = window.contentView else {continue}
                guard let screen = window.screen else {continue}
                
                view.enterFullScreenMode(screen, withOptions: optionsDictionary)
            }
        } else {
            NSCursor.unhide()
            NSApp.presentationOptions = []
            windows.forEach({ (window) in
                window.contentView?.exitFullScreenMode(options: [NSView.FullScreenModeOptionKey.fullScreenModeSetting: false])
            })
        }
        windows.first?.makeKeyAndOrderFront(self)
    }
}
