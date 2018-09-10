import Cocoa
extension AppDelegate {
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
