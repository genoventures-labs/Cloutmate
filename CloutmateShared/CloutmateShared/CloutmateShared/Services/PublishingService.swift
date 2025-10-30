//
//  PublishingService.swift
//  CloutmateShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import os.log

public final class PublishingService {
    public static let shared = PublishingService()
    
    private init() {}
    
    public func publishPost(_ post: Post, context: ModelContext) async {
        Logger.publishing.info("Publishing post: \(post.id)")
        
        post.postStatus = .publishing
        try? context.save()
        
        // For immediate posts, save to SwiftData and trigger helper
        // Helper will read from SwiftData and publish
        XPCService.shared.checkScheduledPosts()
        
        // Note: The helper will update post status when publishing completes
        // Status will be updated to "published" or "failed" by PostPublisher
    }
}
