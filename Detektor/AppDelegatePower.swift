import Cocoa
import ApplicationServices

extension AppDelegate {
    func observePowerStates() {
        // Observe Dialog for Shutdown
        let notification = "com.apple.shutdownInitiated" as CFString
        let selfOpaque = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), selfOpaque, { (center, selfOpaque, name, _, userInfo) in
            let mySelf = Unmanaged<AppDelegate>.fromOpaque(selfOpaque!).takeUnretainedValue()
            mySelf.handleShutdownDialog()
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
    
    func handleShutdownDialog() {
        guard shutdownHasStarted == false else { return }
        shutdownHasStarted = true
        __NSBeep()
        let source = """
        tell application "System Events"
            tell application process "loginwindow"
                click button 3 of window 1
            end tell
        end tell
        """
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(nil)
        self.terminateAndShutdown(self)
    }
    
    @IBAction func terminateAndShutdown(_ sender: Any) {
        let source = "tell application \"Finder\"\nshut down\nend tell\ntell application \"Detektor\" to quit"
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(nil)
    }
}
