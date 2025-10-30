//
//  PublishingService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import os.log

// PublishingService is now defined in CloutmateShared framework
// This file serves as a bridge for the main app

final class PublishingService {
    static let shared = PublishingService()
    
    private init() {}
    
    func publishPost(_ post: Post, context: ModelContext) async {
        // The actual publishing implementation is in CloutmateShared framework
        // This is kept for compatibility with existing code
        post.postStatus = .publishing
        
        // Publishing logic moved to shared framework
        // TODO: Implement actual publishing or delegate to shared service
        post.postStatus = .published
        post.publishedDate = Date()
        
        try? context.save()
    }
}

