//
//  XPCService.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import os.log

// Import XPCProtocol from the correct location
// This allows XPCService to use FocusOSHelperProtocol

public final class XPCService {
    public static let shared = XPCService()
    
    private var connection: NSXPCConnection?
    
    private init() {}
    
    public func establishConnection() {
        guard connection == nil else { return }
        
        let connection = NSXPCConnection(serviceName: "com.kosmicapps.FocusOS.Helper")
        connection.remoteObjectInterface = NSXPCInterface(with: FocusOSHelperProtocol.self)
        connection.resume()
        
        self.connection = connection
    }
    
    public func getRemoteObject() -> FocusOSHelperProtocol? {
        guard let connection = connection else {
            establishConnection()
            return connection?.remoteObjectProxy as? FocusOSHelperProtocol
        }
        return connection.remoteObjectProxy as? FocusOSHelperProtocol
    }
    
    // Deprecated: schedulePost no longer needed - helper reads from SwiftData directly
    public func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String], pageIDs: [String: String]) {
        Logger.xpc.info("schedulePost called - triggering immediate check (post should be in SwiftData)")
        checkScheduledPosts()
    }
    
    public func fetchInsights(postID: String) {
        guard let remoteObject = getRemoteObject() else {
            Logger.xpc.error("Failed to get remote object for fetching insights")
            return
        }
        
        remoteObject.fetchInsights(postID: postID)
    }
    
    public func checkScheduledPosts() {
        guard let remoteObject = getRemoteObject() else {
            Logger.xpc.error("Failed to get remote object for checking scheduled posts")
            return
        }
        
        remoteObject.checkScheduledPosts()
    }
}

