//
//  BackgroundScheduler.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

final class BackgroundScheduler {
    static let shared = BackgroundScheduler()
    
    private var timer: Timer?
    private var scheduledPosts: [String: ScheduledPost] = [:]
    
    private init() {}
    
    struct ScheduledPost {
        let postID: String
        let scheduledDate: Date
        let caption: String
        let mediaURLs: [String]
        let platforms: [String]
    }
    
    func start() {
        Logger.xpc.info("Starting background scheduler")
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkScheduledPosts()
        }
    }
    
    func schedulePost(postID: String, scheduledDate: Date, caption: String, mediaURLs: [String], platforms: [String]) {
        scheduledPosts[postID] = ScheduledPost(
            postID: postID,
            scheduledDate: scheduledDate,
            caption: caption,
            mediaURLs: mediaURLs,
            platforms: platforms
        )
        Logger.xpc.info("Scheduled post \(postID) for \(scheduledDate)")
    }
    
    func checkScheduledPosts() {
        let now = Date()
        let postsToPublish = scheduledPosts.values.filter { $0.scheduledDate <= now }
        
        for post in postsToPublish {
            publishPost(post)
            scheduledPosts.removeValue(forKey: post.postID)
        }
    }
    
    private func publishPost(_ post: ScheduledPost) {
        Logger.publishing.info("Publishing post: \(post.postID)")
        Task {
            await PostPublisher.shared.publish(post)
        }
    }
}

