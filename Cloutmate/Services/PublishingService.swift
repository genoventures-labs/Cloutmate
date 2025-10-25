//
//  PublishingService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import os.log

final class PublishingService {
    static let shared = PublishingService()
    
    private init() {}
    
    func publishPost(_ post: Post) async {
        Logger.publishing.info("Publishing post: \(post.id)")
        
        post.postStatus = .publishing
        
        for platform in post.postPlatforms {
            do {
                let accountKey = "\(platform.rawValue)_access_token"
                let accessToken = try KeychainService.shared.getToken(forAccount: accountKey)
                
                let postID: String
                if platform == .threads {
                    postID = try await ThreadsService.shared.publishPost(
                        caption: post.caption,
                        mediaURLs: post.mediaURLs.isEmpty ? nil : post.mediaURLs,
                        accessToken: accessToken
                    )
                    
                    post.threadsPostID = postID
                } else {
                    // Facebook requires page ID - would need to look up from PlatformAccount
                    Logger.publishing.error("Facebook publishing requires page ID")
                    continue
                }
                
                Logger.publishing.info("Successfully published to \(platform.displayName): \(postID)")
                
            } catch {
                Logger.publishing.error("Failed to publish to \(platform.displayName): \(error.localizedDescription)")
                post.lastError = error.localizedDescription
                post.postStatus = .failed
                return
            }
        }
        
        // Update post status
        post.postStatus = .published
        post.publishedDate = Date()
        
        // Fetch initial insights
        Task {
            await fetchInsights(for: post)
        }
    }
    
    private func fetchInsights(for post: Post) async {
        guard let threadsPostID = post.threadsPostID else { return }
        
        do {
            let accountKey = "threads_access_token"
            let accessToken = try KeychainService.shared.getToken(forAccount: accountKey)
            
            let insights = try await MetaAPIService.shared.getPostInsights(
                postID: threadsPostID,
                accessToken: accessToken
            )
            
            // Parse insights and update post
            parseInsights(insights, into: post)
            
        } catch {
            Logger.insights.error("Failed to fetch insights: \(error.localizedDescription)")
        }
    }
    
    private func parseInsights(_ insights: PostInsightsResponse, into post: Post) {
        for data in insights.data {
            guard let value = data.values.first?.value,
                  let doubleValue = Double(value) else { continue }
            
            switch data.name {
            case "likes":
                post.likes = Int(doubleValue)
            case "comments":
                post.comments = Int(doubleValue)
            case "impressions":
                post.impressions = Int(doubleValue)
            case "reach":
                post.reach = Int(doubleValue)
            default:
                break
            }
        }
        
        // Calculate engagement rate
        if let impressions = post.impressions, impressions > 0 {
            let likes = post.likes ?? 0
            let comments = post.comments ?? 0
            post.engagementRate = Double(likes + comments) / Double(impressions) * 100
        }
    }
}

