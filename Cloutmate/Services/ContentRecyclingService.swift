//
//  ContentRecyclingService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class ContentRecyclingService {
    static let shared = ContentRecyclingService()
    
    private init() {}
    
    func identifyEvergreenContent(posts: [Post], context: ModelContext) async -> [RecyclablePost] {
        os_log("Identifying evergreen content from %d posts", log: .default, type: .info, posts.count)
        
        let publishedPosts = posts.filter { $0.status == "published" }
        
        var recyclablePosts: [RecyclablePost] = []
        
        for post in publishedPosts {
        // Check if already tracked
        let postId = post.id
        let existingDescriptor = FetchDescriptor<RecyclablePost>(
            predicate: #Predicate { $0.originalPostId == postId }
        )
            
            if let existing = try? context.fetch(existingDescriptor).first {
                recyclablePosts.append(existing)
                continue
            }
            
            // Criteria for evergreen:
            // 1. High engagement (top 30% of posts)
            // 2. Not time-sensitive (determined by AI)
            // 3. Published at least 1 month ago
            
            guard let publishedDate = post.publishedDate,
                  let engagementRate = post.engagementRate,
                  Date().timeIntervalSince(publishedDate) > 30 * 24 * 3600 else {
                continue
            }
            
            // Check if in top 30% by engagement
            let sortedByEngagement = publishedPosts
                .compactMap { $0.engagementRate }
                .sorted(by: >)
            
            guard !sortedByEngagement.isEmpty else { continue }
            let thresholdIndex = max(0, min(sortedByEngagement.count - 1, Int(Double(sortedByEngagement.count) * 0.3)))
            let top30Threshold = sortedByEngagement[thresholdIndex]
            
            guard engagementRate >= top30Threshold else { continue }
            
            // Check if content is time-sensitive using AI
            let isTimeSensitive = await checkIfTimeSensitive(post.caption)
            
            guard !isTimeSensitive else { continue }
            
            // Extract topic tags from caption
            let topicTags = await extractTopicTags(post.caption)
            
            // Generate suggested recycle date (3-6 months from original post)
            let recycleInterval = Int.random(in: 90...180) // days
            let nextSuggestedDate = Calendar.current.date(byAdding: .day, value: recycleInterval, to: publishedDate)
            
            let recyclable = RecyclablePost(
                originalPostId: post.id,
                isEvergreen: true,
                engagementScore: engagementRate,
                topicTags: topicTags,
                nextSuggestedDate: nextSuggestedDate
            )
            
            context.insert(recyclable)
            recyclablePosts.append(recyclable)
        }
        
        try? context.save()
        os_log("Identified %d evergreen posts", log: .default, type: .info, recyclablePosts.count)
        
        return recyclablePosts
    }
    
    func generateVariations(for post: Post) async -> [String] {
        let prompt = """
        Create 3 variations of this social media post. Keep the core message but change the hook, angle, or approach. Make each variation fresh and engaging.
        
        Original post: \(post.caption)
        
        Return ONLY the 3 variations, numbered 1-3, without any other text.
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            let variations = parseVariations(response)
            return variations
        } catch {
            os_log("Failed to generate variations: %{public}@", log: .default, type: .error, error.localizedDescription)
            return []
        }
    }
    
    func getSuggestionsForToday(context: ModelContext) async -> [RecyclablePost] {
        let today = Date()
        let descriptor = FetchDescriptor<RecyclablePost>(
            predicate: #Predicate {
                $0.isEvergreen == true &&
                ($0.nextSuggestedDate == nil || $0.nextSuggestedDate! <= today)
            },
            sortBy: [SortDescriptor<RecyclablePost>(\.engagementScore, order: .reverse)]
        )
        
        guard let suggestions = try? context.fetch(descriptor) else {
            return []
        }
        
        return Array(suggestions.prefix(5)) // Top 5 suggestions
    }
    
    func scheduleRecycledPost(_ recyclable: RecyclablePost, variation: String, context: ModelContext) async {
        // Create new post from recycled content
        let originalPostId = recyclable.originalPostId
        let descriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.id == originalPostId }
        )
        
        guard let originalPost = try? context.fetch(descriptor).first else {
            os_log("Original post not found for recycling", log: .default, type: .error)
            return
        }
        
        // Create new post with variation
        let recycledPost = Post(
            caption: variation,
            mediaURLs: originalPost.mediaURLs,
            scheduledDate: Date().addingTimeInterval(3600), // Schedule 1 hour from now
            platforms: originalPost.platforms,
            status: PostStatus.scheduled.rawValue,
            tags: originalPost.tags
        )
        
        // Copy custom properties - skip for now due to SwiftData visibility issues
        // Properties will retain default values
        
        context.insert(recycledPost)
        
        // Update recyclable post tracking
        recyclable.lastRecycledAt = Date()
        recyclable.recycleCount += 1
        recyclable.nextSuggestedDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
        
        try? context.save()
    }
    
    // MARK: - Private Helpers
    
    private func checkIfTimeSensitive(_ caption: String) async -> Bool {
        let prompt = """
        Determine if this social media post is time-sensitive. Time-sensitive means it references specific dates, events, current news, or trends that will be irrelevant soon.
        
        Post: \(caption)
        
        Respond with ONLY "yes" or "no".
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            return response.lowercased().contains("yes")
        } catch {
            return false // Default to not time-sensitive if AI fails
        }
    }
    
    private func extractTopicTags(_ caption: String) async -> [String] {
        let prompt = """
        Extract 3-5 main topics or themes from this social media post. Return ONLY a comma-separated list of topics, nothing else.
        
        Post: \(caption)
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            return response.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        } catch {
            return []
        }
    }
    
    private func parseVariations(_ response: String) -> [String] {
        let lines = response.split(separator: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
            .filter { !$0.isEmpty }
        
        // Extract variations (remove numbering)
        return lines.compactMap { line in
            let cleaned = line.replacingOccurrences(of: "^\\d+[\\.\\)]?\\s*", with: "", options: .regularExpression)
            return cleaned.isEmpty ? nil : cleaned
        }
    }
}

