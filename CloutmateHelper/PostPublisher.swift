//
//  PostPublisher.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

final class PostPublisher {
    static let shared = PostPublisher()
    
    private init() {}
    
    func publish(_ scheduledPost: BackgroundScheduler.ScheduledPost) async {
        Logger.publishing.info("Publishing post \(scheduledPost.postID)")
        
        // Retrieve access tokens from Keychain
        for platformString in scheduledPost.platforms {
            guard let platform = Platform(rawValue: platformString) else { continue }
            
            do {
                let accountKey = "\(platform.rawValue)_access_token"
                let accessToken = try KeychainService.shared.getToken(forAccount: accountKey)
                
                let postID: String
                if platform == .threads {
                    postID = try await ThreadsService.shared.publishPost(
                        caption: scheduledPost.caption,
                        mediaURLs: scheduledPost.mediaURLs.isEmpty ? nil : scheduledPost.mediaURLs,
                        accessToken: accessToken
                    )
                } else {
                    // For Facebook, we need page ID - this would come from the SwiftData store
                    // For now, we'll just log an error
                    Logger.publishing.error("Facebook publishing requires page ID")
                    continue
                }
                
                Logger.publishing.info("Successfully published post \(scheduledPost.postID) as \(postID)")
                
            } catch {
                Logger.publishing.error("Failed to publish post \(scheduledPost.postID): \(error.localizedDescription)")
            }
        }
    }
}

