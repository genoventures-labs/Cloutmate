//
//  XPCService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import os.log

final class XPCService {
    static let shared = XPCService()
    
    private var connection: NSXPCConnection?
    
    private init() {}
    
    func establishConnection() {
        guard connection == nil else { return }
        
        let connection = NSXPCConnection(serviceName: "com.kosmicapps.Cloutmate.Helper")
        connection.remoteObjectInterface = NSXPCInterface(with: CloutmateHelperProtocol.self)
        connection.resume()
        
        self.connection = connection
    }
    
    func getRemoteObject() -> CloutmateHelperProtocol? {
        guard let connection = connection else {
            establishConnection()
            return connection?.remoteObjectProxy as? CloutmateHelperProtocol
        }
        return connection.remoteObjectProxy as? CloutmateHelperProtocol
    }
    
    // Deprecated: schedulePost no longer needed - helper reads from SwiftData directly
    func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String], pageIDs: [String: String]) {
        Logger.xpc.info("schedulePost called - triggering immediate check (post should be in SwiftData)")
        checkScheduledPosts()
    }
    
    func fetchInsights(postID: String) {
        guard let remoteObject = getRemoteObject() else {
            Logger.xpc.error("Failed to get remote object for fetching insights")
            return
        }
        
        remoteObject.fetchInsights(postID: postID)
    }
    
    func checkScheduledPosts() {
        guard let remoteObject = getRemoteObject() else {
            Logger.xpc.error("Failed to get remote object for checking scheduled posts")
            return
        }
        
        remoteObject.checkScheduledPosts()
    }
}

