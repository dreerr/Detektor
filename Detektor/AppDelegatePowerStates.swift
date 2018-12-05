import Cocoa

extension AppDelegate {
    func observePowerStates() {
        // Observe Dialog for Shutdown
        let notification = "com.apple.shutdownInitiated" as CFString
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), observer, { (center, observer, name, _, userInfo) in
            let mySelf = Unmanaged<AppDelegate>.fromOpaque(observer!).takeUnretainedValue()
            mySelf.pressCancel()
        }, notification, nil, .deliverImmediately)
        
        // Observe Sleep Status NOT YET DONE
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
    
    func pressCancel() {
        __NSBeep()
    }
}
