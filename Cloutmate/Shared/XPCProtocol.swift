//
//  XPCProtocol.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

@objc protocol CloutmateHelperProtocol {
    func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String])
    func fetchInsights(postID: String)
    func checkScheduledPosts()
}

@objc protocol CloutmateMainAppProtocol {
    func postStatusUpdated(postID: String, status: String, error: String?)
    func insightsUpdated(postID: String, data: [String: Any])
}

