//
//  ContentIntelligenceService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class ContentIntelligenceService {
    static let shared = ContentIntelligenceService()
    
    private init() {}
    
    func processPostPublish(_ post: Post, context: ModelContext) async {
        guard post.postStatus == .published else { return }
        
        os_log("Running intelligence pipelines for post %@", log: .default, type: .info, post.id.uuidString)
        
        // Update hashtag performance
        await HashtagPerformanceService.shared.trackHashtagPerformance(post: post, context: context)
        
        // Refresh optimal posting times
        let descriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.status == "published" }
        )
        if let publishedPosts = try? context.fetch(descriptor) {
            await BestTimeOptimizerService.shared.learnFromHistory(posts: publishedPosts, context: context)
        }
        
        // Refresh evergreen detection
        let allPostsDescriptor = FetchDescriptor<Post>(
            sortBy: [SortDescriptor<Post>(\.publishedDate, order: .reverse)]
        )
        if let allPosts = try? context.fetch(allPostsDescriptor) {
            _ = await ContentRecyclingService.shared.identifyEvergreenContent(
                posts: allPosts,
                context: context
            )
        }
    }
}

