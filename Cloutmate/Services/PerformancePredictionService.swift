//
//  PerformancePredictionService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import CloutmateShared
import os.log

actor PerformancePredictionService {
    static let shared = PerformancePredictionService()
    
    private var predictionCache: [UUID: PerformancePrediction] = [:]
    private var cacheTimestamp: [UUID: Date] = [:]
    private let cacheDuration: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    func predictEngagement(for post: Post, historicalPosts: [Post]) async -> PerformancePrediction {
        // Check cache first
        if let cached = predictionCache[post.id],
           let timestamp = cacheTimestamp[post.id],
           Date().timeIntervalSince(timestamp) < cacheDuration {
            return cached
        }
        
        // Need at least 10 historical posts for reliable prediction
        guard historicalPosts.count >= 10 else {
            return PerformancePrediction(
                postId: post.id,
                predictedEngagementRate: 0,
                confidence: 0,
                factors: ["error": 1.0]
            )
        }
        
        // Calculate factor scores
        let captionAnalysis = await analyzeCaption(post.caption)
        let captionLengthScore = calculateCaptionLengthScore(captionAnalysis.length, historicalPosts: historicalPosts)
        let toneScore = await calculateToneScore(captionAnalysis.sentiment, historicalPosts: historicalPosts)
        let hashtagScore = calculateHashtagScore(post.tags.count, historicalPosts: historicalPosts)
        let platformScore = calculatePlatformScore(post.postPlatforms, historicalPosts: historicalPosts)
        let timeScore = await calculateTimeScore(platform: post.postPlatforms.first ?? .threads, scheduledDate: post.scheduledDate, historicalPosts: historicalPosts)
        let similarityScore = await calculateSimilarityScore(post: post, historicalPosts: historicalPosts)
        
        // Combine scores with weights
        let weights: [String: Double] = [
            "captionLength": 0.15,
            "tone": 0.20,
            "hashtags": 0.10,
            "platform": 0.15,
            "time": 0.25,
            "similarity": 0.15
        ]
        
        let weightedScore = (captionLengthScore * weights["captionLength"]!) +
                           (toneScore * weights["tone"]!) +
                           (hashtagScore * weights["hashtags"]!) +
                           (platformScore * weights["platform"]!) +
                           (timeScore * weights["time"]!) +
                           (similarityScore * weights["similarity"]!)
        
        // Convert to engagement rate (0-100%)
        let predictedEngagementRate = weightedScore * 100
        
        // Calculate confidence based on data quality
        let confidence = min(1.0, Double(historicalPosts.count) / 50.0) // Max confidence at 50+ posts
        
        // Calculate optimal posting time
        let optimalPostingTime = calculateOptimalTime(platform: post.postPlatforms.first ?? .threads, historicalPosts: historicalPosts)
        
        let prediction = PerformancePrediction(
            postId: post.id,
            predictedEngagementRate: predictedEngagementRate,
            confidence: confidence,
            factors: [
                "captionLength": captionLengthScore,
                "tone": toneScore,
                "hashtags": hashtagScore,
                "platform": platformScore,
                "time": timeScore,
                "similarity": similarityScore
            ],
            optimalPostingTime: optimalPostingTime
        )
        
        prediction.captionLengthScore = captionLengthScore
        prediction.toneScore = toneScore
        prediction.hashtagScore = hashtagScore
        prediction.platformScore = platformScore
        prediction.timeScore = timeScore
        prediction.similarityScore = similarityScore
        
        // Cache the result
        predictionCache[post.id] = prediction
        cacheTimestamp[post.id] = Date()
        
        return prediction
    }
    
    func analyzeCaption(_ caption: String) async -> (length: Int, sentiment: String, complexity: Double) {
        let length = caption.count
        let wordCount = caption.split(separator: " ").count
        let complexity = Double(wordCount) / max(Double(length), 1.0)
        
        // Basic sentiment analysis (can be enhanced with AI)
        let sentiment = await analyzeSentiment(caption)
        
        return (length: length, sentiment: sentiment, complexity: complexity)
    }
    
    private func analyzeSentiment(_ text: String) async -> String {
        // Use Gemini for sentiment analysis
        do {
            let prompt = """
            Analyze the sentiment of this social media caption. Respond with ONLY one word: "positive", "neutral", or "negative".
            
            Caption: \(text)
            """
            
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            let cleaned = response.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if cleaned.contains("positive") {
                return "positive"
            } else if cleaned.contains("negative") {
                return "negative"
            } else {
                return "neutral"
            }
        } catch {
            // Logger is thread-safe, no need for MainActor isolation
            os_log("Sentiment analysis failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            return "neutral"
        }
    }
    
    func findSimilarPosts(_ post: Post, in historicalPosts: [Post]) async -> [Post] {
        // Find posts with similar caption length, hashtag count, and platform
        let targetLength = post.caption.count
        let targetHashtagCount = post.tags.count
        let targetPlatforms = Set(post.postPlatforms)
        
        let similar = historicalPosts.filter { otherPost in
            let lengthDiff = abs(otherPost.caption.count - targetLength)
            let hashtagDiff = abs(otherPost.tags.count - targetHashtagCount)
            let platformsMatch = Set(otherPost.postPlatforms) == targetPlatforms
            
            return lengthDiff < 50 && hashtagDiff <= 2 && platformsMatch
        }
        
        // Sort by engagement rate (best first)
        return similar.sorted { ($0.engagementRate ?? 0) > ($1.engagementRate ?? 0) }.prefix(5).map { $0 }
    }
    
    func calculateOptimalTime(platform: Platform, historicalPosts: [Post]) -> Date? {
        // Find posts for this platform
        let platformPosts = historicalPosts.filter { $0.postPlatforms.contains(platform) }
        guard !platformPosts.isEmpty else { return nil }
        
        // Group by day of week and hour
        var timePerformance: [Int: [Int: [Double]]] = [:] // dayOfWeek: hourOfDay: [engagementRates]
        
        for post in platformPosts {
            guard let publishedDate = post.publishedDate,
                  let engagementRate = post.engagementRate else { continue }
            
            let calendar = Calendar.current
            let dayOfWeek = calendar.component(.weekday, from: publishedDate) // 1=Sunday, 7=Saturday
            let hour = calendar.component(.hour, from: publishedDate)
            
            if timePerformance[dayOfWeek] == nil {
                timePerformance[dayOfWeek] = [:]
            }
            if timePerformance[dayOfWeek]![hour] == nil {
                timePerformance[dayOfWeek]![hour] = []
            }
            
            timePerformance[dayOfWeek]![hour]?.append(engagementRate)
        }
        
        // Find best time
        var bestTime: (day: Int, hour: Int, avg: Double)? = nil
        
        for (day, hours) in timePerformance {
            for (hour, rates) in hours {
                let avg = rates.reduce(0, +) / Double(rates.count)
                if bestTime == nil || avg > bestTime!.avg {
                    bestTime = (day: day, hour: hour, avg: avg)
                }
            }
        }
        
        guard let best = bestTime else { return nil }
        
        // Calculate next occurrence of this day/hour
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        
        // Adjust to next occurrence of the best day/hour
        var targetDate = calendar.date(from: components) ?? now
        let currentDay = calendar.component(.weekday, from: targetDate)
        let daysToAdd = (best.day - currentDay + 7) % 7
        
        if daysToAdd > 0 || (daysToAdd == 0 && calendar.component(.hour, from: targetDate) < best.hour) {
            targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetDate) ?? targetDate
        }
        
        components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = best.hour
        components.minute = 0
        
        return calendar.date(from: components)
    }
    
    func getPerformanceScore() -> Double {
        // Returns average confidence across all predictions
        let confidences = predictionCache.values.map { $0.confidence }
        guard !confidences.isEmpty else { return 0 }
        return confidences.reduce(0, +) / Double(confidences.count)
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateCaptionLengthScore(_ length: Int, historicalPosts: [Post]) -> Double {
        // Find optimal caption length from historical data
        let publishedPosts = historicalPosts.filter { $0.status == "published" && $0.engagementRate != nil }
        guard !publishedPosts.isEmpty else { return 0.5 }
        
        // Group by length ranges and find best performing range
        let lengthRanges = [0..<50, 50..<150, 150..<300, 300..<500, 500..<Int.max]
        var bestRange: Range<Int> = 150..<300
        var bestAvgEngagement: Double = 0
        
        for range in lengthRanges {
            let postsInRange = publishedPosts.filter { range.contains($0.caption.count) }
            guard !postsInRange.isEmpty else { continue }
            
            let avgEngagement = postsInRange.compactMap { $0.engagementRate }.reduce(0, +) / Double(postsInRange.count)
            if avgEngagement > bestAvgEngagement {
                bestAvgEngagement = avgEngagement
                bestRange = range
            }
        }
        
        // Score based on how close to optimal range
        if bestRange.contains(length) {
            return 1.0
        } else {
            let distance = min(abs(length - bestRange.lowerBound), abs(length - bestRange.upperBound))
            return max(0.0, 1.0 - Double(distance) / 100.0)
        }
    }
    
    private func calculateToneScore(_ sentiment: String, historicalPosts: [Post]) async -> Double {
        // Compare sentiment to best performing posts
        let publishedPosts = historicalPosts.filter { $0.status == "published" && $0.engagementRate != nil }
        guard !publishedPosts.isEmpty else { return 0.5 }
        
        // Analyze sentiment of top performing posts
        let topPosts = publishedPosts
            .sorted { ($0.engagementRate ?? 0) > ($1.engagementRate ?? 0) }
            .prefix(10)
        
        var sentimentCounts: [String: Int] = [:]
        for post in topPosts {
            let postSentiment = await analyzeSentiment(post.caption)
            sentimentCounts[postSentiment, default: 0] += 1
        }
        
        let dominantSentiment = sentimentCounts.max(by: { $0.value < $1.value })?.key ?? "neutral"
        
        // Score based on match with dominant sentiment
        return sentiment == dominantSentiment ? 1.0 : 0.5
    }
    
    private func calculateHashtagScore(_ hashtagCount: Int, historicalPosts: [Post]) -> Double {
        let publishedPosts = historicalPosts.filter { $0.status == "published" && $0.engagementRate != nil }
        guard !publishedPosts.isEmpty else { return 0.5 }
        
        // Find optimal hashtag count
        var hashtagPerformance: [Int: [Double]] = [:]
        
        for post in publishedPosts {
            let count = post.tags.count
            if let rate = post.engagementRate {
                if hashtagPerformance[count] == nil {
                    hashtagPerformance[count] = []
                }
                hashtagPerformance[count]?.append(rate)
            }
        }
        
        // Find best hashtag count
        var bestCount = hashtagCount
        var bestAvg: Double = 0
        
        for (count, rates) in hashtagPerformance {
            let avg = rates.reduce(0, +) / Double(rates.count)
            if avg > bestAvg {
                bestAvg = avg
                bestCount = count
            }
        }
        
        // Score based on proximity to optimal
        let distance = abs(hashtagCount - bestCount)
        return max(0.0, 1.0 - Double(distance) * 0.2)
    }
    
    private func calculatePlatformScore(_ platforms: [Platform], historicalPosts: [Post]) -> Double {
        // Score based on platform performance history
        var platformAvgEngagement: [Platform: Double] = [:]
        
        for platform in platforms {
            let platformPosts = historicalPosts.filter {
                $0.postPlatforms.contains(platform) &&
                $0.status == "published" &&
                $0.engagementRate != nil
            }
            
            guard !platformPosts.isEmpty else {
                platformAvgEngagement[platform] = 0.5
                continue
            }
            
            let avg = platformPosts.compactMap { $0.engagementRate }.reduce(0, +) / Double(platformPosts.count)
            platformAvgEngagement[platform] = avg / 10.0 // Normalize to 0-1
        }
        
        // Average across selected platforms
        let scores = platformAvgEngagement.values
        return scores.isEmpty ? 0.5 : scores.reduce(0, +) / Double(scores.count)
    }
    
    private func calculateTimeScore(platform: Platform, scheduledDate: Date?, historicalPosts: [Post]) async -> Double {
        guard let scheduledDate = scheduledDate else { return 0.5 }
        
        let platformPosts = historicalPosts.filter { $0.postPlatforms.contains(platform) && $0.status == "published" }
        guard !platformPosts.isEmpty else { return 0.5 }
        
        let calendar = Calendar.current
        let scheduledDay = calendar.component(.weekday, from: scheduledDate)
        let scheduledHour = calendar.component(.hour, from: scheduledDate)
        
        // Find average engagement for this day/hour combo
        let matchingPosts = platformPosts.filter { post in
            guard let publishedDate = post.publishedDate else { return false }
            let postDay = calendar.component(.weekday, from: publishedDate)
            let postHour = calendar.component(.hour, from: publishedDate)
            return postDay == scheduledDay && postHour == scheduledHour
        }
        
        guard !matchingPosts.isEmpty else { return 0.5 }
        
        let avgEngagement = matchingPosts.compactMap { $0.engagementRate }.reduce(0, +) / Double(matchingPosts.count)
        let overallAvg = platformPosts.compactMap { $0.engagementRate }.reduce(0, +) / Double(platformPosts.count)
        
        // Score based on how much better/worse than average
        if overallAvg > 0 {
            return min(1.0, max(0.0, avgEngagement / overallAvg))
        }
        
        return 0.5
    }
    
    private func calculateSimilarityScore(post: Post, historicalPosts: [Post]) async -> Double {
        let similar = await findSimilarPosts(post, in: historicalPosts)
        guard !similar.isEmpty else { return 0.5 }
        
        // Average engagement of similar posts
        let avgEngagement = similar.compactMap { $0.engagementRate }.reduce(0, +) / Double(similar.count)
        
        // Normalize to 0-1 (assuming 10% is good engagement)
        return min(1.0, avgEngagement / 10.0)
    }
}

