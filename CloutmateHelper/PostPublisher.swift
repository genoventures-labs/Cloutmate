//
//  PostPublisher.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

typealias Platform = CloutmateShared.Platform
typealias PostStatus = CloutmateShared.PostStatus

// Extension to access pageIDs property that may not be visible due to SwiftData module issues
extension Post {
    func helperGetPageID(platform: String) -> String? {
        // Use reflection to access the pageIDs dictionary property
        let mirror = Mirror(reflecting: self)
        if let pageIDsProperty = mirror.children.first(where: { $0.label == "pageIDs" }),
           let pageIDsDict = pageIDsProperty.value as? [String: String] {
            return pageIDsDict[platform]
        }
        return nil
    }
}

final class PostPublisher {
    static let shared = PostPublisher()
    
    private init() {}
    
    func publish(_ post: Post, context: ModelContext) async {
        os_log("Publishing post %@", log: .default, type: .info, post.id.uuidString)
        
        post.postStatus = .publishing
        try? context.save()
        
        var publishedPlatforms: [String] = []
        
        for platform in post.postPlatforms {
            do {
                let postID: String
                
                if platform == .threads {
                    let accountKey = "threads_access_token"
                    let accessToken = try KeychainService.shared.getToken(forAccount: accountKey)
                    
                    postID = try await ThreadsService.shared.publishPost(
                        caption: post.caption,
                        mediaURLs: post.mediaURLs.isEmpty ? nil : post.mediaURLs,
                        accessToken: accessToken
                    )
                    post.threadsPostID = postID
                    
                } else if platform == .facebook {
                    // Use helper extension to access pageIDs
                    guard let pageID = post.helperGetPageID(platform: "facebook") else {
                        os_log("No pageID found for Facebook", log: .default, type: .error)
                        continue
                    }
                    
                    let accountKey = "facebook_page_\(pageID)_access_token"
                    let accessToken = try KeychainService.shared.getToken(forAccount: accountKey)
                    
                    postID = try await FacebookService.shared.publishPost(
                        caption: post.caption,
                        mediaURLs: post.mediaURLs.isEmpty ? nil : post.mediaURLs,
                        pageID: pageID,
                        accessToken: accessToken
                    )
                    post.facebookPostID = postID
                    
                } else {
                    let platformName = await MainActor.run { platform.displayName }
                    os_log("Unsupported platform: %{public}@", log: .default, type: .error, platformName)
                    continue
                }
                
                publishedPlatforms.append(platform.rawValue)
                let platformName = await MainActor.run { platform.displayName }
                os_log("Successfully published to %{public}@", log: .default, type: .info, platformName)
                
            } catch {
                post.lastError = error.localizedDescription
                let platformName = await MainActor.run { platform.displayName }
                os_log("Failed to publish to %{public}@: %{public}@", log: .default, type: .error, platformName, error.localizedDescription)
            }
        }
        
        if !publishedPlatforms.isEmpty {
            post.postStatus = .published
            post.publishedDate = Date()
        } else {
            post.postStatus = .failed
        }
        
        try? context.save()
    }
}

