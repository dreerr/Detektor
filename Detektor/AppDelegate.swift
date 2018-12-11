import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        registerUserDefaults()
    }
    var display: FaceDisplay?
    var matrixLayers = [CALayerMatrix]()
    var windows = [NSWindow]()
    var inFullscreen = false
    let osd = OSDLogLayer()
    let defaults = UserDefaults.standard
    var shutdownHasStarted = false
    let prefs = Preferences(windowNibName: "Preferences")
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        observePowerStates()
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
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
        let view = MainView(frame: window.contentView!.bounds)
        window.contentView?.addSubview(view)
        guard let layer = view.layer else { return }
        layer.backgroundColor = NSColor.black.cgColor
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // Initialize CALayerMatrix
        let layerMatrix = CALayerMatrix(withCols: 1, rows: 1)
        layerMatrix.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        matrixLayers.append(layerMatrix)
        layerTiles.append(contentsOf: layerMatrix.sublayers!)
        
        // Transform layer for streched screen: Make it three times bigger then squeeze
        let stretch = CALayerStretch()
        stretch.stretchRatio = 3.0
        layer.addSublayer(stretch)
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        stretch.frame = layer.bounds
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
        setFullScreen(defaults.bool(forKey: "Full Screen"))
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Finish all recordings
        // DISCUSS: It is odd that deinit does not take care of that but whatever
        guard let tracker = display?.tracker else { return }
        tracker.faces.values.forEach{ $0.finishRecording() }
    }
    
    @IBAction func openPreferences(_ sender: Any) {
        prefs.showWindow(self)
    }
    
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
    
    @IBAction func toggleScreen(_ sender: Any) {
        setFullScreen(windows[0].contentView?.isInFullScreenMode==false)
    }
    
    func setFullScreen(_ setFullScreen:Bool) {
        UserDefaults.standard.set(setFullScreen, forKey: "Full Screen")
        if(setFullScreen) {
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

class MainView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect);
        self.autoresizingMask = [.height, .width]
        self.wantsLayer = true
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)!
    }
    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.toggleScreen(self)
        }
    }
}
