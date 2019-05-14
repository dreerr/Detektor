import Cocoa
import AVFoundation

class Preferences: NSWindowController {
    @IBOutlet var cameraController: NSArrayController?
    @IBOutlet var cameraFormatController: NSArrayController?

    override func windowDidLoad() {
        super.windowDidLoad()
        setCameraController()
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected,
                                               object: nil,
                                               queue: nil) { _ in self.setCameraController() }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasDisconnected,
                                               object: nil,
                                               queue: nil) { _ in self.setCameraController() }
    }
    
    func registerUserDefaults() {
        let defaults = [
            "Camera": "",
            "High Accuracy": true,
            "Feature Size": 0.01,
            "Angles": 1,
            "Full Screen": false,
            "Delete Immediately": false,
            "Keep Recordings": "14 Days",
            "Image Brightness": 0.0,
            "Image Contrast": 1.1,
            "Image Saturation": 0.0,
            "Image EV": 0.5
            ] as [String : Any]
        UserDefaults.standard.register(defaults: defaults)
        
        // Register Transformers for Int & Double
        ValueTransformer.setValueTransformer(StringDoubleTransformer(), forName: NSValueTransformerName("StringDoubleTransformer"))
        ValueTransformer.setValueTransformer(StringIntTransformer(), forName: NSValueTransformerName("StringIntTransformer"))
        
        // Show all values on OSD
        defaults.keys.sorted().forEach { (key) in
            if let option = UserDefaults.standard.object(forKey: key) {
                alert("\(key): \(String(describing: option))", icon: "⚙️")
            }
        }
        
        // Set User Defaults for loginwindow
        if var loginwindow = UserDefaults.standard.persistentDomain(forName: "com.apple.loginwindow") {
            loginwindow["PowerButtonSleepsSystem"] = false
            UserDefaults.standard.setPersistentDomain(loginwindow, forName: "com.apple.loginwindow")
        }
    }
    
    func setCameraController() {
        cameraController?.content = AVCaptureDevice.devices(for: .video).map({ (device) -> [String : Any] in
            ["name": device.localizedName, "object": device.uniqueID]
        })
        setCamera(self)
    }
    @IBAction func setCamera(_ sender:Any) {
        guard let device = AVCaptureDevice.device(withUniqueID: UserDefaults.standard.string(forKey: "Camera")) else {return}
        let formats = device.formats
        cameraFormatController?.content = Array(formats).map({ (format) -> [String : Any] in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return ["name": "\(dimensions.width)x\(dimensions.height)", "object": [Int(dimensions.width), Int(dimensions.height)]] as [String : Any]
        })
    }
    @IBAction func applyCameraChange(_ sender : Any) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "CameraChange"), object: sender)
    }
}


class StringDoubleTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let number = value as? Double else { return nil }
        return String(number)
    }
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let text = value as? String else { return nil }
        return Double(text)
    }
}

class StringIntTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let number = value as? Int else { return nil }
        return String(number)
    }
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let text = value as? String else { return nil }
        return Int(text)
    }
}
