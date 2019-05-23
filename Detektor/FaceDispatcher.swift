import Foundation
import AVFoundation
import Cocoa

class FaceDispatcher: NSObject {
    var assets = [AVAsset]()
    var faceLayers = [FaceLayer]()
    var faces = [Int32: Face]()
    var tracker: FaceTracker?
    var currentIndex = 0
    var currentFaceIndex = 0 // HACK
    
    init(withLayers layers: [FaceLayer]) {
        self.faceLayers = layers
        super.init()
        // Scan for movies
        guard let initialUrls = try? FileManager.default.contentsOfDirectory(at: Constants.directoryURL,
                                                                             includingPropertiesForKeys: [.creationDateKey],
                                                                             options:.skipsHiddenFiles)
            else { return }
        initialUrls.map { url in
            (url, (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast)
            }
            .sorted(by: { $0.1 < $1.1 })
            .map { $0.0 }
            .forEach{appendToAssets($0, updateLayers: false)}
        
        self.faceLayers.forEach { $0.dispatcher = self }
        
        // Initialize FaceTracker (after FaceDisplayLayers are initialized)
        tracker = FaceTracker()
        tracker?.delegate = self
        
        // Register FaceRecorder Notification
        let center = NotificationCenter.default
        center.addObserver(forName: Notification.Name("newRecording"),
                           object: nil,
                           queue: OperationQueue.main) { (note) in
                            guard let url: URL = note.object as? URL else {return}
                            self.appendToAssets(url, updateLayers: true)
        }
        
        #if DETEKTOR
        // Cycle through images
        _ = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true, block: {_ in
            self.currentFaceIndex+=1
            self.updateLayers()
        })
        #endif
    }
    
    // Append an item to the queue, gets called on starup and when a new movie is recorded
    func appendToAssets(_ url:URL, updateLayers:Bool) {
        guard url.pathExtension.lowercased() == "mp4" else { return }
        let item = AVURLAsset(url: url)
        if item.isPlayable {
            self.assets.append(item)
            if updateLayers, let layer = getEmptyLayer() {
                DispatchQueue.main.async {
                    layer.insertNextPlayerItem()
                }
            }
        }
    }
    
    // Get the next item to play and fill queue if there are not enough items available
    func getNextAsset() -> AVAsset? {
        while assets.count > 0 {
            let item = assets.removeLast()
            let url = (item as! AVURLAsset).url
            
            // Check Time Invervals
            let interval = UserDefaults.standard.string(forKey: "Keep Recordings") ?? "Forever"
            if let timeIntervalLimit = Constants.intervals[interval] {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) as [FileAttributeKey: Any],
                    let creationDate = attributes[FileAttributeKey.creationDate] as? Date else { continue }
                if creationDate.timeIntervalSinceNow < timeIntervalLimit {
                    debug("\(url.lastPathComponent) is too old \(creationDate)")
                    
                    // Try to delete the file if necessary
                    do {
                        if UserDefaults.standard.bool(forKey: "Delete Immediately") {
                            try FileManager.default.removeItem(at: url)
                        } else {
                            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                        }
                    } catch let error as NSError {
                        alert("Error deleting file: " + error.localizedDescription)
                    }
                    continue
                }
            }
            return item
        }
        return nil
    }
    
    func restoreAsset(_ item : AVAsset?) {
        if let item = item {assets.insert(item, at: 0)}
    }
    
    
    // Toggle playing state of all live and recorded layers
    var isPlaying: Bool = true {
        didSet {
            faceLayers.forEach { $0.player.rate = (isPlaying ? 1.0 : 0.0) }
            tracker?.isTracking = isPlaying
        }
    }
    
    func updateLayers() {
        // TODO!
    }
    
    // Get a empty layer
    func getEmptyLayer() -> FaceLayer? {
        if let emptyLayer = faceLayers.filter({return $0.state == .empty}).first {
            return emptyLayer
        }
        return nil
    }
    
    // Get a free layer to display a live image on
    func getBestLayerForLive() -> FaceLayer? {
        if let emptyLayer = getEmptyLayer() {
            return emptyLayer
        }
        let playingLayers = faceLayers.filter({return $0.state == .playing})
        if let longestLayer = playingLayers.sorted(by: {$0.player.currentTime() > $1.player.currentTime()}).first {
            return longestLayer
        }
        return nil
    }
}


// Delegate Extension to communicate with FaceTracker
extension FaceDispatcher: FaceTrackerProtocol {
    func addLiveFace(_ face: Face, id: Int32) {
        faces[id] = face
        if let layer = getBestLayerForLive() {
            layer.switchLive(face.preview)
            face.layer = layer
        }
    }
    func removeLiveFace(id: Int32) {
        if faces.keys.contains(id) {
            debug("removeLiveFace")
            faces[id]?.layer?.switchPlay() {
                self.faces.removeValue(forKey: id)
            }
        }
    }
}
