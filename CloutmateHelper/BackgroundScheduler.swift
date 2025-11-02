//
//  BackgroundScheduler.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

final class BackgroundScheduler {
    static let shared = BackgroundScheduler()
    
    private var timer: Timer?
    private let modelContainer: ModelContainer
    
    private init() {
        self.modelContainer = SharedDataManager.createSharedModelContainer()
    }
    
    func start() {
        os_log("Starting background scheduler", log: .default, type: .info)
        
        // Check immediately on start
        checkScheduledPosts()
        
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkScheduledPosts()
        }
    }
    
    func checkScheduledPosts() {
        let context = modelContainer.mainContext
        
        // Check for scheduled posts ready to publish
        let scheduledDescriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.status == "scheduled" }
        )
        
        guard let scheduledPosts = try? context.fetch(scheduledDescriptor) else {
            os_log("Failed to fetch scheduled posts from SwiftData", log: .default, type: .error)
            return
        }
        
        let now = Date()
        
        for post in scheduledPosts where post.scheduledDate ?? .distantFuture <= now {
            os_log("Publishing scheduled post: %@", log: .default, type: .info, post.id.uuidString)
            
            post.postStatus = .publishing
            try? context.save()
            
            _Concurrency.Task {
                await publishPost(post)
            }
        }
        
        // Also check for immediate posts (publishing status, no scheduled date)
        let publishingDescriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.status == "publishing" && $0.scheduledDate == nil }
        )
        
        guard let publishingPosts = try? context.fetch(publishingDescriptor) else {
            return
        }
        
        for post in publishingPosts {
            os_log("Publishing immediate post: %@", log: .default, type: .info, post.id.uuidString)
            
            _Concurrency.Task {
                await publishPost(post)
            }
        }
    }
    
    private func publishPost(_ post: Post) async {
        let publisher = PostPublisher.shared
        await publisher.publish(post, context: modelContainer.mainContext)
    }
}

