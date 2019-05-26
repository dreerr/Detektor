import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        prefs = Preferences(windowNibName: "Preferences")
        prefs.registerUserDefaults()
    }
    var display: FaceDispatcher?
    var matrixLayers = [CALayerMatrix]()
    var windows = [NSWindow]()
    var inFullscreen = false
    let osd = OSDLogLayer()
    let defaults = UserDefaults.standard
    var shutdownHasStarted = false
    let prefs : Preferences
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        observePowerStates()
        
        // Create new window
        guard let screen = NSScreen.screens.last else {return}
        #if DETEKTOR
        let height = screen.frame.size.height*CGFloat(1080.0/1920.0)
        let width = screen.frame.size.height
        #else
        let height = screen.frame.size.height*CGFloat(1080.0/1920.0)
        let width = screen.frame.size.height
        #endif
        let window = NSWindow(contentRect: NSMakeRect(screen.frame.origin.x,
                                                      screen.frame.origin.y,
                                                      height,
                                                      width),
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
        var faceLayers = [FaceLayer]()
        for _ in 1...Constants.cols*Constants.rows {
            faceLayers.append(FaceLayer())
        }
        let layerMatrix = CALayerMatrix(withCols: Constants.cols, rows: Constants.rows, layers: faceLayers)

        matrixLayers.append(layerMatrix)
        
        // Transform layer for streched screen: Make it three times bigger then squeeze
        let stretch = CALayerStretch()
        #if DETEKTOR
        stretch.stretchRatio = 3.0
        #else
        stretch.stretchRatio = 1.0
        #endif
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
        let diskSpace = attrs[FileAttributeKey.systemFreeSize] as! Int64
        let diskSpaceFormatted = ByteCountFormatter.string(fromByteCount: diskSpace, countStyle: .file)
        alert("Free Size: \(diskSpaceFormatted)")
        
        // Initialize FacePlayer with the sublayers of CALayerMatrix array
        display = FaceDispatcher(withLayers: faceLayers)
        
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
            if let layer = windows[0].contentView?.subviews.first?.layer?.sublayers?.first?.sublayers?.first {
                display?.tracker?.connectDebug(layer)
            }
        } else {
            display?.tracker?.disconnectDebug()
        }
    }
    
    @IBAction func toggleScreen(_ sender: Any) {
        setFullScreen(windows[0].contentView?.isInFullScreenMode==false)
    }
    
    var hideCursorTimer : Timer?
    func setFullScreen(_ setFullScreen:Bool) {
        UserDefaults.standard.set(setFullScreen, forKey: "Full Screen")
        if(setFullScreen) {
            hideCursorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true){_ in NSCursor.hide() }
            hideCursorTimer?.fire()
            let presOptions: NSApplication.PresentationOptions = [
                .fullScreen,
                .autoHideMenuBar
            ]
            let optionsDictionary = [
                .fullScreenModeApplicationPresentationOptions: presOptions,
                .fullScreenModeAllScreens: false
            ] as [NSView.FullScreenModeOptionKey : Any]
            for window in windows {
                guard let view = window.contentView else {continue}
                guard let screen = window.screen else {continue}
                
                view.enterFullScreenMode(screen, withOptions: optionsDictionary)
            }
        } else {
            hideCursorTimer?.invalidate()
            NSCursor.unhide()
            NSApp.presentationOptions = []
            for window in windows {
                window.contentView?.exitFullScreenMode(options: [NSView.FullScreenModeOptionKey.fullScreenModeSetting: false])
            }
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
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        if event.clickCount == 1 {
            appDelegate.display?.isPlaying = !(appDelegate.display!.isPlaying)
        }
        if event.clickCount == 2 {
            appDelegate.toggleScreen(self)
        }
    }
}
