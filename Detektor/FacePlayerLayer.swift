//
//  FacePlayerLayer.swift
//  Observers
//
//  Created by Julian on 28.01.18.
//  Copyright © 2018 Julian Palacz. All rights reserved.
//

import Foundation
import AVFoundation
import Cocoa

class FacePlayerLayer: NSObject {
    var layer: CALayer
    var liveLayer: CALayer?
    var playerLayer: AVPlayerLayer
    var parent: FacePlayer
    var player = AVQueuePlayer() // Maybe only AVPlayer?

    init(layer: CALayer, facePlayer: FacePlayer) {
        self.layer = layer
        self.parent = facePlayer
        self.playerLayer = AVPlayerLayer(player: player)
        super.init()
        
        // Setup players and layers
        playerLayer.videoGravity = .resize
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.frame = layer.bounds
        layer.addSublayer(playerLayer)
        
        // Play next item available
        self.insert(parent.nextPlayerItem())
    }
    
    func insert(_ playerItem:AVPlayerItem?) {
        // Insert item on the playlist and start playing
        if let item = playerItem {
            self.player.insert(item, after: nil)
            self.player.play()
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didPlayToEndTime(notification:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: item)
        }
    }
    @objc func didPlayToEndTime(notification:Notification) {
        self.insert(self.parent.nextPlayerItem())
    }
    
    var timeRemaining : CMTime {
        // returns remaining time in the player
        if let item = player.currentItem {
            return item.duration - item.currentTime()
        } else {
            return CMTime(seconds: 0, preferredTimescale: 600)
        }
    }

    func switchLive(_ live:CALayer) {
        // Connect a CALayer to display live preview
        liveLayer = live
        player.pause()
        liveLayer!.frame = layer.bounds
        layer.addSublayer(liveLayer!)
        DispatchQueue.main.async {
            self.layer.setNeedsDisplay()
        }
    }
    
    func switchPlay() {
        // Disconnect live preview and contiune playing items
        liveLayer?.removeFromSuperlayer()
        liveLayer = nil
        player.play()
        DispatchQueue.main.async {
            self.layer.setNeedsDisplay()
        }
    }
}
