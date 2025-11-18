//
//  HelperXPCService.swift
//  FocusOSHelper
//
//  XPC Service for helper app (publishing functionality removed)
//

import Foundation
import os.log

class HelperXPCService: NSObject, NSXPCListenerDelegate, FocusOSHelperProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: FocusOSHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    // Deprecated: schedulePost no longer needed - social media publishing removed
    @objc func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String], pageIDs: [String: String]) {
        os_log("schedulePost called but publishing is disabled", log: .default, type: .debug)
        // No-op
    }
    
    // Deprecated: fetchInsights no longer needed - social media insights removed
    func fetchInsights(postID: String) {
        os_log("fetchInsights called but insights polling is disabled", log: .default, type: .debug)
        // No-op
    }
    
    // Deprecated: checkScheduledPosts no longer needed - publishing removed
    func checkScheduledPosts() {
        os_log("checkScheduledPosts called but publishing is disabled", log: .default, type: .debug)
        // No-op
    }
}
