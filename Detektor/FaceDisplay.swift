import Foundation
import AVFoundation
import Cocoa

class FaceDisplay: NSObject {
    var playerItems = [AVPlayerItem]()
    var faceLayers = [FaceDisplayLayer]()
    var faces = [Int32: Face]()
    var tracker: FaceTracker?
    var currentIndex = 0
    var currentFaceIndex = 0 // HACK
    
    init(withLayers layers: [CALayer]) {
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
            .forEach{appendToPlayerItems($0)}
        
        
        // Setup FaceDisplayLayers
        layers.forEach { faceLayers.append(FaceDisplayLayer(layer: $0, facePlayer: self)) }
        
        // Initialize FaceTracker (after FaceDisplayLayers are initialized)
        tracker = FaceTracker()
        tracker?.delegate = self
        
        // Register FaceRecorder Notification
        NotificationCenter.default.addObserver(forName: Notification.Name("newRecording"),
                                               object: nil,
                                               queue: OperationQueue.main) {
                                                self.appendToPlayerItems($0.object as! URL)
        }
        
        // Cycle through
        _ = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true, block: {_ in
            self.currentFaceIndex+=1
            self.updateLayers()
        })
    }
    
    // Append an item to the queue, gest called on starup and when a
    func appendToPlayerItems(_ url:URL) {
        guard url.pathExtension.lowercased() == "mp4" else { return }
        let item = AVPlayerItem(url: url)
        if item.asset.isPlayable {
            self.playerItems.append(item)
        }
    }
    
    // Get the next item to play and fill queue if there are not enough items available
    func getNextPlayerItem() -> AVPlayerItem? {
        while playerItems.count > 0 {
            let item = playerItems[currentIndex]
            let url = (item.asset as! AVURLAsset).url
            
            // Check which timeframe is set and test the file accordingly
            let intervals = ["14 Days": -60*60*24*14, "30 Days": -60*60*24*30, "3 Months": -60*60*24*90] as [String:Double]
            if let timeIntervalLimit = intervals[UserDefaults.standard.string(forKey: "Keep Recordings") ?? "Forever"] {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) as [FileAttributeKey: Any],
                    let creationDate = attributes[FileAttributeKey.creationDate] as? Date else { continue }
                if creationDate.timeIntervalSinceNow < timeIntervalLimit {
                    print("\(url.lastPathComponent) is too old \(creationDate)")
                    playerItems.remove(at: currentIndex)
                    do {
                        if UserDefaults.standard.bool(forKey: "Delete Immediately") {
                            try FileManager.default.removeItem(at: url)
                        } else {
                            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                        }
                    } catch let error as NSError {
                        alert("Fehler: " + error.localizedDescription)
                    }
                    return nil
                }
            } else {
                print("No valid limit found, could be forever")
            }
            print("\(url.lastPathComponent) in timeframe")
            currentIndex = (currentIndex+1)%playerItems.count // we have the item, so we advance
            return item
        }
        return nil
    }
    
    // Toggle playing state of all live and recorded layers
    var isPlaying: Bool = true {
        didSet {
            faceLayers.forEach { $0.player.rate = (isPlaying ? 1.0 : 0.0) }
            tracker?.isTracking = isPlaying
        }
    }
    
    // Update all Layers with faces and players
    func updateLayers() {
        let faceLayer = faceLayers[0] // ONLY UPDATE THE FIRST LAYER (DETEKTOR ONLY HAS ONE LAYER)
        if faces.count == 0 {
            faceLayer.switchPlay()
        } else {
            let index = Int(currentFaceIndex%faces.count)
            print("live faces: \(faces.count) / selecting:  \(index+1)")
            let layer = Array(faces)[index].value.preview
            faceLayer.switchLive(layer)
        }
        
// DISABLED BECAUSE NOT ENOUGH BRAIN RESSOURCES TO THINK N TO N
//        // Switch Players on for faces we lost
//        for orphan in Set(playersLive.keys).subtracting(Set(faces.keys)) {
//            playersLive[orphan]?.switchPlay()
//            playersLive.removeValue(forKey: orphan)
//        }
//
//        // Assign new faces to free players
//        for newbie in Set(faces.keys).subtracting(Set(playersLive.keys)) {
//            if let layer = getBestLayerForLive() {
//                layer.switchLive(faces[newbie]!.preview)
//                playersLive[newbie] = layer
//            }
//        }
    }
    // Get a free layer to display a live image on
    //    func getBestLayerForLive() -> FaceDisplayLayer? {
    //        let faceLayersNotLive = faceLayers.filter({
    //            return $0.liveLayer == nil
    //        })
    //        if faceLayersNotLive.count == 0 { return nil }
    //        // FIXME: Don't use random but a meaningful routine instead!
    //        let index = Int(arc4random_uniform(UInt32(faceLayersNotLive.count)))
    //        return faceLayersNotLive[index]
    //    }
}


// Delegate Extension to communicate with FaceTracker
extension FaceDisplay: FaceTrackerProtocol {
    func addFace(_ face: Face, id: Int32) {
        faces[id] = face
        updateLayers()
    }
    func removeFace(id: Int32) {
        faces.removeValue(forKey: id)
        updateLayers()
    }
}
