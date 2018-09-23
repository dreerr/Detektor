import Foundation
import AVFoundation
import Cocoa

class FacePlayer: NSObject {
    var collection = [URL]()
    var queue = [AVPlayerItem]()
    var faceLayers = [FacePlayerLayer]()
//    var playersLive = [Int32: FacePlayerLayer]()
    var faces = [Int32: Face]()
    var tracker: FaceTracker?
    var collectionIndex = 0
    var currentFaceIndex = 0 // HACK
    //weak var faceIndexTimer: Timer? // HACK
    
    init(withLayers layers: [CALayer]) {
        super.init()
        // Scan for movies
        guard let urls = try? FileManager.default.contentsOfDirectory(at: Constants.directoryURL,
                                                                       includingPropertiesForKeys: [.contentModificationDateKey],
                                                                       options:.skipsHiddenFiles)
        else { return }
        urls.map { url in
            (url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast)
            }
            .sorted(by: { $0.1 < $1.1 })
            .map { $0.0 }
            .forEach{appendToQueue($0)}
        
        
        // Setup FacePlayerLayers
        layers.forEach { faceLayers.append(FacePlayerLayer(layer: $0, facePlayer: self)) }
        
        // Initialize FaceTracker (after FacePlayerLayers are initialized)
        tracker = FaceTracker()
        tracker?.delegate = self
       
        // Register FaceRecorder Notification
        NotificationCenter.default.addObserver(forName: Notification.Name("newRecording"),
                                               object: nil,
                                               queue: OperationQueue.main) {
                                                self.appendToQueue($0.object as! URL)
        }
        
        fillQueue(5)
        
        _ = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true, block: {_ in
            self.currentFaceIndex+=1
            self.updateLayers()
        })
    }

    
    // Append an item to the queue
    func appendToQueue(_ url:URL) {
        let item = AVPlayerItem(url: url)
        if item.asset.isPlayable {
            self.queue.insert(item, at: 0)
            self.collection.insert(url, at: 0)
        }
    }

    // Get the next item to play and fill queue if there are not enough items available
    func nextPlayerItem() -> AVPlayerItem? {
        if queue.count < 5 {
            fillQueue(5)
        }
        if let item = queue.popLast() {
            print("playing", item)
            return item
        }
        return nil
    }
    
    // Fill up queue with a given number of items
    func fillQueue(_ numItems: Int) {
        guard collection.count > 0 else {return}
        for _ in 1...numItems {
            let item = AVPlayerItem(url: collection[collectionIndex])
            if item.asset.isPlayable {
                queue.insert(item, at: 0)
            }
            collectionIndex = (collectionIndex+1)%collection.count
            print("collectionIndex", collectionIndex)
        }
    }

    // Get a free layer to display a live image on
    func getBestLayerForLive() -> FacePlayerLayer? {
        let faceLayersNotLive = faceLayers.filter({
            return $0.liveLayer == nil
        })
        if faceLayersNotLive.count == 0 { return nil }
        // FIXME: Don't use random but a meaningful routine instead!
        let index = Int(arc4random_uniform(UInt32(faceLayersNotLive.count)))
        return faceLayersNotLive[index]
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
        print("updating layers for \(faces.count) faces")
        let faceLayer = faceLayers[0]
        if(faces.count == 0) {
            faceLayer.switchPlay()
        } else {
            let index = Int(currentFaceIndex%faces.count)
            print("selecting face \(index)")
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
}

// Delegate Extension to communicate with FaceTracker
extension FacePlayer: FaceTrackerProtocol {
    func addFace(_ face: Face, id: Int32) {
        faces[id] = face
        updateLayers()
    }
    func removeFace(id: Int32) {
        faces.removeValue(forKey: id)
        updateLayers()
    }
}
