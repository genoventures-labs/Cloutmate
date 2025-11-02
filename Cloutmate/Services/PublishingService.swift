//
//  PublishingService.swift
//  Cloutmate
//
//  Publishing orchestration for social platforms
//

import Foundation
import SwiftData
import os.log
import CloutmateShared

@MainActor
final class PublishingService {
    static let shared = PublishingService()
    
    private let facebookService = FacebookService.shared
    private let threadsService = ThreadsService.shared
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "Publishing")
    
    private init() {}
    
    /// Publish a post to its configured platforms
    /// - Parameters:
    ///   - post: The post to publish
    ///   - context: SwiftData model context
    /// - Note: Attempts external platform publishing if OAuth tokens are configured
    func publishPost(_ post: Post, context: ModelContext) async {
        logger.info("Publishing post \(post.id.uuidString) to platforms: \(post.platforms.joined(separator: ", "))")
        
        post.postStatus = .publishing
        post.updatedAt = Date()
        try? context.save()
        
        var publishedToPlatforms: [String] = []
        var errors: [String] = []
        
        // Attempt to publish to each platform
        for platformString in post.platforms {
            guard let platform = Platform(rawValue: platformString.lowercased()) else {
                errors.append("Unknown platform: \(platformString)")
                continue
            }
            
            switch platform {
            case .facebook:
                if let result = await publishToFacebook(post: post) {
                    if result.success {
                        publishedToPlatforms.append("Facebook")
                        if let postId = result.postId {
                            post.facebookPostID = postId
                        }
                        logger.info("Published to Facebook successfully")
                    } else {
                        errors.append("Facebook: \(result.error ?? "Unknown error")")
                        logger.error("Facebook publish failed: \(result.error ?? "unknown")")
                    }
                } else {
                    errors.append("Facebook: Not configured (OAuth token missing)")
                    logger.warning("Facebook OAuth not configured")
                }
                
            case .threads:
                if let result = await publishToThreads(post: post) {
                    if result.success {
                        publishedToPlatforms.append("Threads")
                        if let postId = result.postId {
                            post.threadsPostID = postId
                        }
                        logger.info("Published to Threads successfully")
                    } else {
                        errors.append("Threads: \(result.error ?? "Unknown error")")
                        logger.error("Threads publish failed: \(result.error ?? "unknown")")
                    }
                } else {
                    errors.append("Threads: Not configured (OAuth token missing)")
                    logger.warning("Threads OAuth not configured")
                }
            }
        }
        
        // Update post status based on results
        if !publishedToPlatforms.isEmpty {
            post.postStatus = .published
            post.publishedDate = Date()
            post.lastError = nil  // Clear any previous errors
            logger.info("Post published successfully to \(publishedToPlatforms.count) platform(s)")
        } else {
            // If no platforms succeeded, mark as failed but store what went wrong
            post.postStatus = .failed
            post.lastError = errors.joined(separator: "; ")
            post.retryCount += 1
            logger.error("Post publishing failed for all platforms")
        }
        
        post.updatedAt = Date()
        try? context.save()
        
        AIRecallService.shared.registerUpdated(post, modelContext: context)
    }
    
    // MARK: - Platform-Specific Publishing
    
    private func publishToFacebook(post: Post) async -> (success: Bool, error: String?, postId: String?)? {
        // Check if we have a stored access token (from Settings)
        let token = UserDefaults.standard.string(forKey: "facebook_access_token")
        let pageId = UserDefaults.standard.string(forKey: "facebook_page_id")
        
        guard let token = token, let pageId = pageId else {
            return nil // Not configured
        }
        
        do {
            // Publish using FacebookService
            let fbPostId = try await facebookService.publishPost(
                caption: post.caption,
                mediaURLs: post.mediaURLs,
                pageID: pageId,
                accessToken: token
            )
            
            return (true, nil, fbPostId)
        } catch {
            return (false, error.localizedDescription, nil)
        }
    }
    
    private func publishToThreads(post: Post) async -> (success: Bool, error: String?, postId: String?)? {
        // Check if we have a stored access token (from Settings)
        let token = UserDefaults.standard.string(forKey: "threads_access_token")
        
        guard let token = token else {
            return nil // Not configured
        }
        
        do {
            // Publish using ThreadsService
            let threadsPostId = try await threadsService.publishPost(
                caption: post.caption,
                mediaURLs: post.mediaURLs,
                accessToken: token
            )
            
            return (true, nil, threadsPostId)
        } catch {
            return (false, error.localizedDescription, nil)
        }
    }
    
    /// Check if a platform is ready for publishing
    func isPlatformReady(_ platform: Platform) -> Bool {
        switch platform {
        case .facebook:
            return UserDefaults.standard.string(forKey: "facebook_access_token") != nil &&
                   UserDefaults.standard.string(forKey: "facebook_page_id") != nil
        case .threads:
            return UserDefaults.standard.string(forKey: "threads_access_token") != nil
        }
    }
    
    /// Get status of all platforms
    func getPlatformStatus() -> [String: String] {
        var status: [String: String] = [:]
        
        if isPlatformReady(.facebook) {
            status["facebook"] = "Ready"
        } else {
            status["facebook"] = "Not configured - OAuth required in Settings"
        }
        
        if isPlatformReady(.threads) {
            status["threads"] = "Ready"
        } else {
            status["threads"] = "Not configured - OAuth required in Settings"
        }
        
        return status
    }
}

