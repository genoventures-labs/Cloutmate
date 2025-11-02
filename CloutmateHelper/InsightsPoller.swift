//
//  InsightsPoller.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

final class InsightsPoller {
    static let shared = InsightsPoller()
    
    private var timer: Timer?
    private let modelContainer: ModelContainer
    
    private init() {
        self.modelContainer = SharedDataManager.createSharedModelContainer()
    }
    
    func start() {
        os_log("Starting insights poller", log: .default, type: .info)
        
        // Poll immediately on start
        pollAllPosts()
        
        // Then every hour
        timer = Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { [weak self] _ in
            self?.pollAllPosts()
        }
    }
    
    func fetchInsights(for postID: String) {
        os_log("Fetching insights for post: %{public}@", log: .default, type: .info, postID)
        _Concurrency.Task {
            await fetchInsightsForPost(postID)
        }
    }
    
    private func pollAllPosts() {
        os_log("Polling insights for all published posts", log: .default, type: .info)
        _Concurrency.Task {
            await fetchInsightsForAllPosts()
        }
    }
    
    private func fetchInsightsForAllPosts() async {
        let context = modelContainer.mainContext
        
        let descriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.status == "published" }
        )
        
        guard let posts = try? context.fetch(descriptor) else {
            os_log("Failed to fetch posts from SwiftData", log: .default, type: .error)
            return
        }
        
        os_log("Fetching insights for %d published posts", log: .default, type: .info, posts.count)
        
        for post in posts {
            await fetchInsightsForPost(post)
        }
        
        os_log("Insights polling cycle completed", log: .default, type: .info)
    }
    
    private func fetchInsightsForPost(_ post: Post) async {
        let context = modelContainer.mainContext
        
        for platform in post.postPlatforms {
            do {
                let accessToken: String
                let postID: String?
                
                if platform == .threads {
                    accessToken = try KeychainService.shared.getToken(forAccount: "threads_access_token")
                    postID = post.threadsPostID
                } else if platform == .facebook {
                    // Use helper extension to access pageIDs
                    guard let pageID = post.helperGetPageID(platform: "facebook") else { continue }
                    accessToken = try KeychainService.shared.getToken(forAccount: "facebook_page_\(pageID)_access_token")
                    postID = post.facebookPostID
                } else {
                    continue
                }
                
                guard let postID = postID else { continue }
                
                // Fetch insights
            let insights = try await MetaAPIService.shared.getPostInsights(
                postID: postID,
                    accessToken: accessToken,
                    platform: platform
                )
                
                // Update post
                for data in insights.data {
                    guard let rawValue = data.values.first else { continue }
                    let doubleValue: Double
                    if let numeric = rawValue.numericValue {
                        doubleValue = numeric
                    } else if let breakdown = rawValue.breakdown {
                        doubleValue = breakdown.values.reduce(0, +)
                    } else {
                        continue
                    }
                    
                    switch data.name {
                    case "likes", "reactions", "post_reactions_by_type_total":
                        post.likes = (post.likes ?? 0) + Int(doubleValue)
                    case "comments":
                        post.comments = (post.comments ?? 0) + Int(doubleValue)
                    case "impressions", "post_impressions":
                        post.impressions = (post.impressions ?? 0) + Int(doubleValue)
                    case "reach", "post_engaged_users":
                        post.reach = (post.reach ?? 0) + Int(doubleValue)
                    default:
                        break
                    }
                }
                
                // Calculate engagement
                if let impressions = post.impressions, impressions > 0 {
                    let likes = post.likes ?? 0
                    let comments = post.comments ?? 0
                    post.engagementRate = Double(likes + comments) / Double(impressions) * 100
                }
                
                try? context.save()
                
                let platformName = await MainActor.run { platform.displayName }
                os_log("Updated insights for post %@ on %{public}@", log: .default, type: .info, post.id.uuidString, platformName)
                
        } catch {
                os_log("Failed to fetch insights: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func fetchInsightsForPost(_ postID: String) async {
        let context = modelContainer.mainContext
        
        let descriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.id.uuidString == postID }
        )
        
        guard let post = try? context.fetch(descriptor).first else {
            os_log("Post not found: %{public}@", log: .default, type: .error, postID)
            return
        }
        
        await fetchInsightsForPost(post)
    }
}

