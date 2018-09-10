//
//  FacePlayer.swift
//  Observers
//
//  Created by Julian on 24.01.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import Foundation
import AVFoundation
import Cocoa

class FacePlayer: NSObject {
    var collection = [URL]()
    var queue = [AVPlayerItem]()
    var faceLayers = [FacePlayerLayer]()
    var faceLayersLive = [Int32: FacePlayerLayer]()
    var tracker: FaceTracker?
    var collectionIndex = 0

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

}

// Delegate Extension to communicate with FaceTracker
extension FacePlayer: FaceTrackerProtocol {
    func addPreview(_ preview: CALayer, id: Int32) {
        if let layer = self.getBestLayerForLive() {
            layer.switchLive(preview)
            self.faceLayersLive[id] = layer
        }
    }
    func removePreview(id: Int32) {
        if let layer = self.faceLayersLive[id] {
            layer.switchPlay()
            self.faceLayersLive.removeValue(forKey: id)
        }
    }
}
