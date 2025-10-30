//
//  HashtagPerformanceService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

actor HashtagPerformanceService {
    static let shared = HashtagPerformanceService()
    
    private init() {}
    
    func trackHashtagPerformance(post: Post, context: ModelContext) async {
        guard post.status == "published",
              let publishedDate = post.publishedDate else {
            return
        }
        
        // Extract hashtags from caption and tags
        let hashtags = extractHashtags(from: post.caption) + post.tags.filter { $0.hasPrefix("#") }
        
        let engagement = (post.engagementRate ?? 0) * Double(post.impressions ?? 0)
        
        for platform in post.postPlatforms {
            for hashtag in hashtags {
                let cleanedHashtag = hashtag.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                
                // Find or create HashtagPerformance
                let descriptor = FetchDescriptor<HashtagPerformance>(
                    predicate: #Predicate {
                        $0.hashtag == cleanedHashtag && $0.platform == platform.rawValue
                    }
                )
                
                if let existing = try? context.fetch(descriptor).first {
                    // Update existing
                    existing.useCount += 1
                    existing.totalEngagement += Int(engagement)
                    existing.lastUsedAt = publishedDate
                    existing.averageEngagement = Double(existing.totalEngagement) / Double(existing.useCount)
                    
                    // Update best performing post
                    if let bestPostId = existing.bestPerformingPostId {
                        let bestPostDescriptor = FetchDescriptor<Post>(
                            predicate: #Predicate { $0.id == bestPostId }
                        )
                        if let bestPost = try? context.fetch(bestPostDescriptor).first,
                           let currentRate = post.engagementRate,
                           let bestRate = bestPost.engagementRate,
                           currentRate > bestRate {
                            existing.bestPerformingPostId = post.id
                        }
                    } else {
                        existing.bestPerformingPostId = post.id
                    }
                    
                    existing.updatedAt = Date()
                } else {
                    // Create new
                    let hashtagPerf = HashtagPerformance(
                        hashtag: cleanedHashtag,
                        platform: platform.rawValue,
                        useCount: 1,
                        totalEngagement: Int(engagement),
                        averageEngagement: engagement,
                        isTrending: false,
                        trendScore: 0
                    )
                    hashtagPerf.lastUsedAt = publishedDate
                    hashtagPerf.bestPerformingPostId = post.id
                    
                    context.insert(hashtagPerf)
                }
            }
        }
        
        try? context.save()
    }
    
    func getTopPerformingHashtags(platform: Platform, limit: Int, context: ModelContext) async -> [HashtagPerformance] {
        let descriptor = FetchDescriptor<HashtagPerformance>(
            predicate: #Predicate { $0.platform == platform.rawValue },
            sortBy: [SortDescriptor<HashtagPerformance>(\.averageEngagement, order: .reverse)]
        )
        
        guard let hashtags = try? context.fetch(descriptor) else {
            return []
        }
        
        return Array(hashtags.prefix(limit))
    }
    
    func suggestHashtags(for caption: String, platform: Platform, context: ModelContext) async -> [String] {
        // Get top performing hashtags
        let topHashtags = await getTopPerformingHashtags(platform: platform, limit: 20, context: context)
        
        // Use AI to suggest hashtags based on caption and top performers
        let topHashtagList = topHashtags.map { "#\($0.hashtag)" }.joined(separator: ", ")
        
        let platformName = await MainActor.run { platform.displayName }
        let prompt = """
        Suggest 5-8 hashtags for this social media post. Use hashtags that are:
        1. Relevant to the content
        2. Similar in style to these top-performing hashtags: \(topHashtagList)
        3. Appropriate for \(platformName)
        
        Post: \(caption)
        
        Return ONLY the hashtags, one per line, starting with #.
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            let suggestions = response.split(separator: "\n")
                .map { String($0).trimmingCharacters(in: CharacterSet.whitespaces) }
                .filter { $0.hasPrefix("#") }
                .map { $0.lowercased() }
            
            return Array(suggestions.prefix(8))
        } catch {
            os_log("Hashtag suggestion failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            return []
        }
    }
    
    func detectTrendingHashtags(platform: Platform, context: ModelContext) async -> [String] {
        // Find hashtags used frequently in last 7 days
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        
        let descriptor = FetchDescriptor<HashtagPerformance>(
            predicate: #Predicate {
                $0.platform == platform.rawValue &&
                ($0.lastUsedAt == nil || $0.lastUsedAt! >= sevenDaysAgo)
            },
            sortBy: [SortDescriptor<HashtagPerformance>(\.useCount, order: .reverse)]
        )
        
        guard let recentHashtags = try? context.fetch(descriptor) else {
            return []
        }
        
        // Mark as trending if use count increased significantly
        for hashtag in recentHashtags {
            if hashtag.useCount >= 3 {
                hashtag.isTrending = true
                hashtag.trendScore = Double(hashtag.useCount) / 10.0 // Normalize to 0-1
            }
        }
        
        try? context.save()
        
        return recentHashtags.filter { $0.isTrending }.map { "#\($0.hashtag)" }
    }
    
    func compareHashtagSets(context: ModelContext) async -> [(HashtagSet, Double)] {
        let descriptor = FetchDescriptor<HashtagSet>()
        
        guard let sets = try? context.fetch(descriptor) else {
            return []
        }
        
        var results: [(HashtagSet, Double)] = []
        
        for set in sets {
            // Calculate average performance of hashtags in this set
            var totalEngagement: Double = 0
            var totalCount = 0
            
            for hashtagString in set.hashtags {
                let cleaned = hashtagString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                let hashtagDescriptor = FetchDescriptor<HashtagPerformance>(
                    predicate: #Predicate { $0.hashtag == cleaned }
                )
                
                if let perf = try? context.fetch(hashtagDescriptor).first {
                    totalEngagement += perf.averageEngagement
                    totalCount += 1
                }
            }
            
            let avgPerformance = totalCount > 0 ? totalEngagement / Double(totalCount) : 0.0
            set.averagePerformance = avgPerformance
            results.append((set, avgPerformance))
        }
        
        try? context.save()
        
        return results.sorted { $0.1 > $1.1 } // Sort by performance descending
    }
    
    // MARK: - Private Helpers
    
    private func extractHashtags(from text: String) -> [String] {
        let pattern = #"#\w+"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let matches = regex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        return matches?.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range]).lowercased()
        } ?? []
    }
}

