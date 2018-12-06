import Cocoa
import ApplicationServices

extension AppDelegate {
    func registerUserDefaults() {
        UserDefaults.standard.register(defaults: [
            "High Accuracy": true,
            "Feature Size": 0.01,
            "Angles": 1,
            "Full Screen": false,
            "Delete Immediately": false,
            "Keep Recordings": "14 Days"
            ])
        syncPrefsMenu()
    }
    func syncPrefsMenu() {
        let defaults = UserDefaults.standard
        let prefsMenu = NSApplication.shared.mainMenu!.items.filter(){ $0.title == "Preferences" }.first
        prefsMenu?.submenu?.autoenablesItems = false
        for item in (prefsMenu?.submenu?.items)! {
            if item.title == "Use High Accuracy" {
                item.state = (defaults.bool(forKey: "High Accuracy") ? .on : .off)
            }
            if item.title == "Delete Immediately" {
                item.state = (defaults.bool(forKey: "Delete Immediately") ? .on : .off)
            }
            for subitem in item.submenu?.items ?? [] {
                if item.title == "Minimum Feature Size" {
                    let size = Float(subitem.title.suffix(4))
                    subitem.state = defaults.float(forKey: "Feature Size") == size ? .on : .off
                } else if item.title == "Face Angles" {
                    let angles = Int(subitem.title.suffix(1))
                    subitem.state = defaults.integer(forKey: "Angles") == angles ? .on : .off
                } else if item.title == "Keep Recordings" {
                    subitem.state = defaults.string(forKey: "Keep Recordings") == subitem.title ? .on : .off
                }
            }
        }
        alert("High Accuracy: \(defaults.bool(forKey: "High Accuracy") ? "Yes": "No")")
        alert("Minimum Feature Size: \(defaults.float(forKey: "Feature Size"))")
        alert("Face Angles: \(defaults.integer(forKey: "Angles"))")
        alert("Keep Recordings: \(defaults.string(forKey: "Keep Recordings") ?? "Unknown")")
        alert("Delete Immediately: \(defaults.bool(forKey: "Delete Immediately") ? "Yes": "No")")
    }
}
