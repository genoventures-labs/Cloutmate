//
//  XPCProtocol.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

@objc protocol FocusOSHelperProtocol {
    func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String], pageIDs: [String: String])
    func fetchInsights(postID: String)
    func checkScheduledPosts()
}

@objc protocol FocusOSMainAppProtocol {
    func postStatusUpdated(postID: String, status: String, error: String?)
    func insightsUpdated(postID: String, data: [String: Any])
}

