//
//  HelperXPCService.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import os.log

class HelperXPCService: NSObject, NSXPCListenerDelegate, CloutmateHelperProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: CloutmateHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    // schedulePost is deprecated - scheduler now reads from SwiftData directly
    @objc func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String], pageIDs: [String: String]) {
        os_log("schedulePost called but no longer needed - scheduler reads from SwiftData", log: .default, type: .default)
        // Just trigger a check - the post should already be in SwiftData
        checkScheduledPosts()
    }
    
    func fetchInsights(postID: String) {
        os_log("Received insights fetch request for post: %{public}@", log: .default, type: .info, postID)
        InsightsPoller.shared.fetchInsights(for: postID)
    }
    
    func checkScheduledPosts() {
        os_log("Received check scheduled posts request", log: .default, type: .info)
        BackgroundScheduler.shared.checkScheduledPosts()
    }
}

