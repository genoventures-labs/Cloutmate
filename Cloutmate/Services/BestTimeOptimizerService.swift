//
//  BestTimeOptimizerService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class BestTimeOptimizerService {
    static let shared = BestTimeOptimizerService()
    
    private init() {}
    
    func createTimeTest(for post: Post, times: [Date], context: ModelContext) async -> PostingTimeTest {
        os_log("Creating time test with %d variants", log: .default, type: .info, times.count)
        
        // Create base post copies for each time
        var variantPostIDs: [UUID] = []
        
        for time in times {
            let variant = Post(
                caption: post.caption,
                mediaURLs: post.mediaURLs,
                scheduledDate: time,
                platforms: post.platforms,
                status: PostStatus.scheduled.rawValue,
                tags: post.tags
            )
            
            // Copy custom properties - using reflection as direct access may fail
            // Skip for now as properties aren't critical for time testing functionality
            
            context.insert(variant)
            variantPostIDs.append(variant.id)
        }
        
        // Create test record
        let test = PostingTimeTest(
            basePostId: post.id,
            testVariants: variantPostIDs,
            testStartDate: Date(),
            status: .active
        )
        
        context.insert(test)
        try? context.save()
        
        return test
    }
    
    func analyzeTestResults(_ test: PostingTimeTest, context: ModelContext) async {
        os_log("Analyzing test results for test %@", log: .default, type: .info, test.id.uuidString)
        
        var results: [UUID: Double] = [:]
        
        // Fetch variant posts and calculate engagement
        for variantId in test.testVariants {
            let descriptor = FetchDescriptor<Post>(
                predicate: #Predicate { $0.id == variantId }
            )
            
            guard let variant = try? context.fetch(descriptor).first,
                  let engagementRate = variant.engagementRate else {
                continue
            }
            
            // Store results as string keys (SwiftData limitation)
            results[variantId] = engagementRate
        }
        
        // Find winning time
        let winningVariant = results.max(by: { $0.value < $1.value })
        
        if let winnerId = winningVariant?.key {
            let descriptor = FetchDescriptor<Post>(
                predicate: #Predicate { $0.id == winnerId }
            )
            if let winnerPost = try? context.fetch(descriptor).first,
               let publishedDate = winnerPost.publishedDate {
                test.winningTime = publishedDate
            }
        }
        
        // Update test status
        test.status = .completed
        test.testEndDate = Date()
        
        // Convert results to string format for storage (PostingTimeTest expects [String: Double])
        test.results = Dictionary<String, Double>(uniqueKeysWithValues: results.map { (key, value) in
            (key.uuidString, value)
        })
        
        try? context.save()
        
        // Update optimal posting times
        await learnFromTest(test, context: context)
    }
    
    func buildPostingHeatmap(platform: Platform, posts: [Post]) -> [[Double]] {
        // 7 days × 24 hours = 168 slots
        var heatmap: [[Double]] = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        var counts: [[Int]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
        
        let calendar = Calendar.current
        let platformPosts = posts.filter { $0.postPlatforms.contains(platform) && $0.status == "published" }
        
        for post in platformPosts {
            guard let publishedDate = post.publishedDate,
                  let engagementRate = post.engagementRate else { continue }
            
            let dayOfWeek = (calendar.component(.weekday, from: publishedDate) - 1) % 7 // 0=Sunday, 6=Saturday
            let hour = calendar.component(.hour, from: publishedDate)
            
            heatmap[dayOfWeek][hour] += engagementRate
            counts[dayOfWeek][hour] += 1
        }
        
        // Calculate averages
        for day in 0..<7 {
            for hour in 0..<24 {
                if counts[day][hour] > 0 {
                    heatmap[day][hour] /= Double(counts[day][hour])
                }
            }
        }
        
        return heatmap
    }
    
    func suggestOptimalTimes(platform: Platform, context: ModelContext) async -> [Date] {
        // Get optimal times from database
        let descriptor = FetchDescriptor<OptimalPostingTime>(
            predicate: #Predicate { $0.platform == platform.rawValue },
            sortBy: [SortDescriptor<OptimalPostingTime>(\.engagementMultiplier, order: .reverse)]
        )
        
        guard let optimalTimes = try? context.fetch(descriptor) else {
            return []
        }
        
        // Convert to Date objects for next week
        let calendar = Calendar.current
        let now = Date()
        var suggestedTimes: [Date] = []
        
        for optimal in optimalTimes.prefix(5) { // Top 5
            // Find next occurrence
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            
            // Adjust day of week (Calendar uses 1=Sunday, we need to convert)
            let currentWeekday = calendar.component(.weekday, from: now)
            let targetWeekday = optimal.dayOfWeek
            let daysToAdd = (targetWeekday - currentWeekday + 7) % 7
            
            if let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) {
                components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = optimal.hourOfDay
                components.minute = 0
                
                if let date = calendar.date(from: components) {
                    suggestedTimes.append(date)
                }
            }
        }
        
        return suggestedTimes.sorted()
    }
    
    func learnFromHistory(posts: [Post], context: ModelContext) async {
        os_log("Learning optimal posting times from history", log: .default, type: .info)
        
        let publishedPosts = posts.filter { $0.status == "published" && $0.engagementRate != nil }
        guard publishedPosts.count >= 10 else {
            os_log("Not enough data for learning (need 10+ posts)", log: .default, type: .info)
            return
        }
        
        let calendar = Calendar.current
        
        // Group by platform
        for platform in Platform.allCases {
            let platformPosts = publishedPosts.filter { $0.postPlatforms.contains(platform) }
            guard !platformPosts.isEmpty else { continue }
            
            // Group by day/hour
            var timePerformance: [Int: [Int: [Double]]] = [:] // dayOfWeek: hourOfDay: [engagementRates]
            
            for post in platformPosts {
                guard let publishedDate = post.publishedDate,
                      let engagementRate = post.engagementRate else { continue }
                
                let dayOfWeek = calendar.component(.weekday, from: publishedDate) // 1=Sunday
                let hourOfDay = calendar.component(.hour, from: publishedDate)
                
                if timePerformance[dayOfWeek] == nil {
                    timePerformance[dayOfWeek] = [:]
                }
                if timePerformance[dayOfWeek]![hourOfDay] == nil {
                    timePerformance[dayOfWeek]![hourOfDay] = []
                }
                
                timePerformance[dayOfWeek]![hourOfDay]?.append(engagementRate)
            }
            
            // Calculate averages and create OptimalPostingTime records
            let overallAvg = platformPosts.compactMap { $0.engagementRate }.reduce(0, +) / Double(platformPosts.count)
            
            for (dayOfWeek, hours) in timePerformance {
                for (hourOfDay, rates) in hours where rates.count >= 2 { // Need at least 2 samples
                    let avgEngagement = rates.reduce(0, +) / Double(rates.count)
                    let multiplier = overallAvg > 0 ? avgEngagement / overallAvg : 1.0
                    let confidence = min(1.0, Double(rates.count) / 10.0) // Max confidence at 10+ samples
                    
                    // Check if exists
                    let descriptor = FetchDescriptor<OptimalPostingTime>(
                        predicate: #Predicate {
                            $0.platform == platform.rawValue &&
                            $0.dayOfWeek == dayOfWeek &&
                            $0.hourOfDay == hourOfDay
                        }
                    )
                    
                    if let existing = try? context.fetch(descriptor).first {
                        existing.engagementMultiplier = multiplier
                        existing.sampleSize = rates.count
                        existing.confidence = confidence
                        existing.lastUpdated = Date()
                    } else {
                        let optimal = OptimalPostingTime(
                            platform: platform.rawValue,
                            dayOfWeek: dayOfWeek,
                            hourOfDay: hourOfDay,
                            engagementMultiplier: multiplier,
                            sampleSize: rates.count,
                            confidence: confidence
                        )
                        context.insert(optimal)
                    }
                }
            }
        }
        
        try? context.save()
        os_log("Completed learning optimal posting times", log: .default, type: .info)
    }
    
    // MARK: - Private Helpers
    
    private func learnFromTest(_ test: PostingTimeTest, context: ModelContext) async {
        guard let winningTime = test.winningTime else { return }
        
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: winningTime)
        let hourOfDay = calendar.component(.hour, from: winningTime)
        
        // Determine platform from base post
        let basePostId = test.basePostId
        let descriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.id == basePostId }
        )
        
        guard let basePost = try? context.fetch(descriptor).first,
              let platform = basePost.postPlatforms.first else {
            return
        }
        
        // Update or create OptimalPostingTime
        let optimalDescriptor = FetchDescriptor<OptimalPostingTime>(
            predicate: #Predicate {
                $0.platform == platform.rawValue &&
                $0.dayOfWeek == dayOfWeek &&
                $0.hourOfDay == hourOfDay
            }
        )
        
        if let existing = try? context.fetch(optimalDescriptor).first {
            existing.sampleSize += test.testVariants.count
            existing.confidence = min(1.0, Double(existing.sampleSize) / 10.0)
            existing.lastUpdated = Date()
        } else {
            let optimal = OptimalPostingTime(
                platform: platform.rawValue,
                dayOfWeek: dayOfWeek,
                hourOfDay: hourOfDay,
                engagementMultiplier: 1.2, // Assume 20% better for winning time
                sampleSize: test.testVariants.count,
                confidence: 0.3 // Lower confidence from single test
            )
            context.insert(optimal)
        }
        
        try? context.save()
    }
}

