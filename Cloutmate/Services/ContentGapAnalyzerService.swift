//
//  ContentGapAnalyzerService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import CloutmateShared
import os.log

actor ContentGapAnalyzerService {
    static let shared = ContentGapAnalyzerService()
    
    private init() {}
    
    func analyzeTopicClusters(posts: [Post]) async -> [ContentTopic] {
        os_log("Analyzing topic clusters from %d posts", log: .default, type: .info, posts.count)
        
        let publishedPosts = posts.filter { $0.status == "published" }
        guard !publishedPosts.isEmpty else { return [] }
        
        // Use AI to cluster topics
        let captions = publishedPosts.map { $0.caption }.joined(separator: "\n---\n")
        
        let prompt = """
        Analyze these social media posts and identify the main topic clusters. For each topic, provide:
        - Topic name
        - Related keywords (3-5 words)
        - Estimated post count for this topic
        
        Posts:
        \(captions)
        
        Return as JSON array with format:
        [
          {
            "name": "Topic Name",
            "keywords": ["keyword1", "keyword2"],
            "count": 5
          }
        ]
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            let topics = try parseTopicClusters(response, posts: publishedPosts)
            return topics
        } catch {
            os_log("Topic clustering failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            return []
        }
    }
    
    func detectContentGaps(topics: [ContentTopic]) async -> [String] {
        // Generate gap suggestions using AI
        let topicNames = topics.map { $0.name }.joined(separator: ", ")
        
        let prompt = """
        Based on these content topics, suggest 3-5 related topics that are missing or underrepresented:
        
        Current topics: \(topicNames)
        
        Return ONLY a comma-separated list of missing topics.
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            return response.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        } catch {
            return []
        }
    }
    
    func analyzeContentBalance(posts: [Post]) async -> ContentBalance {
        let publishedPosts = posts.filter { $0.status == "published" }
        
        // Categorize posts by type
        var contentTypeCounts: [String: Int] = [:]
        var topicCounts: [String: Int] = [:]
        
        for post in publishedPosts {
            // Determine content type
            let type = await classifyContentType(post.caption)
            contentTypeCounts[type, default: 0] += 1
            
            // Count topics from tags
            for tag in post.tags {
                topicCounts[tag, default: 0] += 1
            }
        }
        
        // Calculate percentages
        let total = publishedPosts.count
        var contentTypePercentages: [String: Double] = [:]
        for (type, count) in contentTypeCounts {
            contentTypePercentages[type] = Double(count) / Double(total)
        }
        
        // Detect gaps based on underrepresented content types
        let gaps = contentTypePercentages.compactMap { (type, value) -> String? in
            value < 0.1 ? type : nil
        }
        
        // Generate recommendations
        let recommendations = generateRecommendations(contentTypes: contentTypePercentages, totalPosts: total)
        
        return ContentBalance(
            contentTypes: contentTypePercentages,
            topicClusters: topicCounts,
            gaps: gaps,
            recommendations: recommendations
        )
    }
    
    func suggestTopics(basedOn topics: [ContentTopic]) async -> [String] {
        // Find underrepresented topics and suggest related ones
        let underrepresented = topics.filter { $0.isUnderrepresented }
        
        guard !underrepresented.isEmpty else {
            return topics.prefix(5).map { $0.name }
        }
        
        // Suggest based on underrepresented topics
        let topicNames = underrepresented.map { $0.name }.joined(separator: ", ")
        
        let prompt = """
        These topics are underrepresented in the content. Suggest 5 related topics that would balance the content mix:
        
        Underrepresented: \(topicNames)
        
        Return ONLY a comma-separated list.
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            return response.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        } catch {
            return []
        }
    }
    
    // MARK: - Private Helpers
    
    private func parseTopicClusters(_ response: String, posts: [Post]) throws -> [ContentTopic] {
        // Try to parse JSON response
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            // Fallback: extract topics from text
            return extractTopicsFromText(response, posts: posts)
        }
        
        var topics: [ContentTopic] = []
        
        for item in json {
            guard let name = item["name"] as? String else { continue }
            let keywords = (item["keywords"] as? [String]) ?? []
            let count = (item["count"] as? Int) ?? 0
            
            // Calculate average engagement for this topic
            let topicPosts = posts.filter { post in
                keywords.contains { keyword in
                    post.caption.lowercased().contains(keyword.lowercased()) ||
                    post.tags.contains { $0.lowercased().contains(keyword.lowercased()) }
                }
            }
            
            let avgEngagement = topicPosts.compactMap { $0.engagementRate }.reduce(0, +) / max(Double(topicPosts.count), 1.0)
            let lastPosted = topicPosts.compactMap { $0.publishedDate }.max()
            
            let isUnderrepresented = count < posts.count / 10 // Less than 10% of posts
            
            let topic = ContentTopic(
                name: name,
                postCount: count,
                averageEngagement: avgEngagement,
                relatedKeywords: keywords,
                isUnderrepresented: isUnderrepresented,
                suggestedFrequency: isUnderrepresented ? 2 : 1
            )
            
            topic.lastPostedAt = lastPosted
            topics.append(topic)
        }
        
        return topics
    }
    
    private func extractTopicsFromText(_ text: String, posts: [Post]) -> [ContentTopic] {
        // Fallback: simple keyword extraction
        let lines = text.split(separator: "\n").map { String($0).trimmingCharacters(in: CharacterSet.whitespaces) }
        var topics: [ContentTopic] = []
        
        for (index, line) in lines.enumerated() {
            if index < 10 { // Limit to 10 topics
                let topic = ContentTopic(name: line, postCount: 0, averageEngagement: 0)
                topics.append(topic)
            }
        }
        
        return topics
    }
    
    private func classifyContentType(_ caption: String) async -> String {
        let prompt = """
        Classify this social media post into ONE of these categories:
        - tips
        - stories
        - promotions
        - questions
        - educational
        - entertainment
        - inspirational
        
        Post: \(caption)
        
        Return ONLY the category name.
        """
        
        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            return response.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } catch {
            return "other"
        }
    }
    
    private func generateRecommendations(contentTypes: [String: Double], totalPosts: Int) -> [String] {
        var recommendations: [String] = []
        
        // Ideal distribution (can be customized)
        let idealDistribution: [String: Double] = [
            "tips": 0.30,
            "stories": 0.25,
            "educational": 0.20,
            "questions": 0.15,
            "promotions": 0.10
        ]
        
        for (type, ideal) in idealDistribution {
            let current = contentTypes[type] ?? 0.0
            let gap = ideal - current
            
            if gap > 0.10 { // More than 10% gap
                recommendations.append("Increase \(type) content (currently \(Int(current * 100))%, target \(Int(ideal * 100))%)")
            }
        }
        
        if totalPosts < 20 {
            recommendations.append("Post more frequently to get better insights")
        }
        
        return recommendations
    }
}

