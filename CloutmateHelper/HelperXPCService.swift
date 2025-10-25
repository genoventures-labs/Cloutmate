//
//  HelperXPCService.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

class HelperXPCService: NSObject, NSXPCListenerDelegate, CloutmateHelperProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: CloutmateHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String]) {
        Logger.xpc.info("Received schedule request for post: \(postID)")
        BackgroundScheduler.shared.schedulePost(
            postID: postID,
            scheduledDate: scheduledDate,
            caption: caption,
            mediaURLs: mediaURLs,
            platforms: platforms
        )
    }
    
    func fetchInsights(postID: String) {
        Logger.xpc.info("Received insights fetch request for post: \(postID)")
        InsightsPoller.shared.fetchInsights(for: postID)
    }
    
    func checkScheduledPosts() {
        Logger.xpc.info("Received check scheduled posts request")
        BackgroundScheduler.shared.checkScheduledPosts()
    }
}

