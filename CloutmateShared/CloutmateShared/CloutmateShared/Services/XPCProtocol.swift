//
//  XPCProtocol.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

@objc public protocol CloutmateHelperProtocol {
    @objc optional func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String], pageIDs: [String: String])
    func fetchInsights(postID: String)
    func checkScheduledPosts()
}

@objc public protocol CloutmateMainAppProtocol {
    func postStatusUpdated(postID: String, status: String, error: String?)
    func insightsUpdated(postID: String, data: [String: Any])
}


