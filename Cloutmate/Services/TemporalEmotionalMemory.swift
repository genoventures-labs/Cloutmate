//
//  TemporalEmotionalMemory.swift
//  Cloutmate
//
//  Tracks emotional patterns over time and provides temporal context for tone selection
//

import Foundation
import SwiftData
import os.log

@MainActor
final class TemporalEmotionalMemory {
    static let shared = TemporalEmotionalMemory()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "TemporalEmotionalMemory")
    
    private init() {}
    
    // MARK: - Epoch Creation & Aggregation
    
    /// Create or update daily epoch for a given date
    func createOrUpdateDailyEpoch(
        for date: Date,
        modelContext: ModelContext
    ) async -> EmotionEpoch {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        // Check if epoch exists
        let descriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.epochType == "daily" &&
                epoch.startDate >= startOfDay &&
                epoch.startDate < endOfDay
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        // Create new daily epoch
        let epoch = EmotionEpoch(
            epochType: .daily,
            startDate: startOfDay,
            endDate: endOfDay
        )
        modelContext.insert(epoch)
        return epoch
    }
    
    /// Create or update weekly epoch for a given date
    func createOrUpdateWeeklyEpoch(
        for date: Date,
        modelContext: ModelContext
    ) async -> EmotionEpoch {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        
        // Check if epoch exists
        let descriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.epochType == "weekly" &&
                epoch.startDate >= weekStart &&
                epoch.startDate < weekEnd
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        // Create new weekly epoch
        let epoch = EmotionEpoch(
            epochType: .weekly,
            startDate: weekStart,
            endDate: weekEnd
        )
        modelContext.insert(epoch)
        return epoch
    }
    
    /// Aggregate metrics from ToneForecastMetrics into an epoch
    func aggregateMetricsIntoEpoch(
        epoch: EmotionEpoch,
        modelContext: ModelContext
    ) async {
        let epochStartDate = epoch.startDate
        let epochEndDate = epoch.endDate
        
        let descriptor = FetchDescriptor<ToneForecastMetrics>(
            predicate: #Predicate<ToneForecastMetrics> { metric in
                metric.timestamp >= epochStartDate && metric.timestamp < epochEndDate
            }
        )
        
        guard let metrics = try? modelContext.fetch(descriptor), !metrics.isEmpty else {
            logger.info("No metrics found for epoch \(epoch.id.uuidString)")
            return
        }
        
        // Aggregate tone distribution
        var toneCounts: [AuroraTone: Int] = [:]
        var accurateCount = 0
        var totalCount = 0
        
        for metric in metrics {
            if let tone = metric.predictedToneValue {
                toneCounts[tone, default: 0] += 1
            }
            if metric.wasAccurate {
                accurateCount += 1
            }
            totalCount += 1
        }
        
        let dominantTone = toneCounts.max(by: { $0.value < $1.value })?.key
        let averageAccuracy = totalCount > 0 ? Double(accurateCount) / Double(totalCount) : 0.5
        
        // Aggregate sentiment
        var sentimentSum = 0.0
        var positiveCount = 0
        var sentimentValues: [Double] = []
        
        for metric in metrics {
            let sentimentValue: Double = {
                switch metric.outcomeSentimentValue {
                case .positive: return 1.0
                case .neutral: return 0.0
                case .negative: return -1.0
                case .none: return 0.0
                }
            }()
            sentimentSum += sentimentValue
            sentimentValues.append(sentimentValue)
            if sentimentValue > 0 {
                positiveCount += 1
            }
        }
        
        let averageSentiment = metrics.isEmpty ? 0.0 : sentimentSum / Double(metrics.count)
        let positiveRatio = metrics.isEmpty ? 0.0 : Double(positiveCount) / Double(metrics.count)
        
        // Calculate sentiment variance
        let sentimentVariance: Double = {
            guard !sentimentValues.isEmpty else { return 0.0 }
            let mean = averageSentiment
            let variance = sentimentValues.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(sentimentValues.count)
            return min(1.0, variance)
        }()
        
        // Calculate tone volatility (variance in tone distribution)
        let toneVolatility: Double = {
            guard !toneCounts.isEmpty else { return 0.5 }
            let totalTones = toneCounts.values.reduce(0, +)
            let mean = Double(totalTones) / Double(toneCounts.count)
            let variance = toneCounts.values.map { pow(Double($0) - mean, 2) }.reduce(0.0, +) / Double(toneCounts.count)
            return min(1.0, variance / (mean * mean + 0.1)) // Normalized variance
        }()
        
        // Calculate transition frequency (from conversation analysis)
        let transitionFrequency = calculateTransitionFrequency(metrics: metrics)
        
        // Calculate emotional baseline (weighted average of sentiment with stability)
        let emotionalBaseline = averageSentiment
        let baselineStability = 1.0 - sentimentVariance // Higher variance = lower stability
        
        // Count conversations and messages
        let uniqueConversations = Set(metrics.compactMap { $0.conversationId })
        let conversationCount = uniqueConversations.count
        let messageCount = metrics.count
        let predictionCount = metrics.count
        
        // Update epoch
        epoch.updateMetrics(
            dominantTone: dominantTone,
            toneDistribution: toneCounts,
            averageAccuracy: averageAccuracy,
            averageSentiment: averageSentiment,
            sentimentVariance: sentimentVariance,
            positiveRatio: positiveRatio,
            toneVolatility: toneVolatility,
            transitionFrequency: transitionFrequency,
            emotionalBaseline: emotionalBaseline,
            baselineStability: baselineStability,
            conversationCount: conversationCount,
            messageCount: messageCount,
            predictionCount: predictionCount
        )
        
        do {
            try modelContext.save()
            logger.info("Aggregated \(metrics.count) metrics into \(epoch.epochType) epoch")
        } catch {
            logger.error("Failed to save epoch: \(error.localizedDescription)")
        }
    }
    
    private func calculateTransitionFrequency(metrics: [ToneForecastMetrics]) -> Double {
        // Group by conversation and count transitions
        let metricsByConversation = Dictionary(grouping: metrics) { $0.conversationId }
        
        var totalTransitions = 0
        var totalConversations = 0
        
        for (_, conversationMetrics) in metricsByConversation {
            guard conversationMetrics.count > 1 else { continue }
            totalConversations += 1
            
            let sortedMetrics = conversationMetrics.sorted { $0.timestamp < $1.timestamp }
            for i in 1..<sortedMetrics.count {
                if sortedMetrics[i].predictedTone != sortedMetrics[i-1].predictedTone {
                    totalTransitions += 1
                }
            }
        }
        
        return totalConversations > 0 ? Double(totalTransitions) / Double(totalConversations) : 0.0
    }
    
    // MARK: - Rolling Averages
    
    /// Get rolling average emotional baseline (last N days)
    func rollingAverageBaseline(
        days: Int = 7,
        modelContext: ModelContext
    ) async -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.startDate >= cutoffDate
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        
        guard let epochs = try? modelContext.fetch(descriptor), !epochs.isEmpty else {
            return 0.0 // Neutral baseline
        }
        
        // Weight recent epochs higher
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (index, epoch) in epochs.enumerated() {
            let recencyWeight = Double(epochs.count - index) / Double(epochs.count) // More recent = higher weight
            let stabilityWeight = epoch.baselineStability
            let weight = recencyWeight * stabilityWeight
            
            weightedSum += epoch.emotionalBaseline * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
    }
    
    /// Get rolling average tone volatility (last N days)
    func rollingAverageVolatility(
        days: Int = 7,
        modelContext: ModelContext
    ) async -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.startDate >= cutoffDate
            }
        )
        
        guard let epochs = try? modelContext.fetch(descriptor), !epochs.isEmpty else {
            return 0.5 // Default moderate volatility
        }
        
        let averageVolatility = epochs.map { $0.toneVolatility }.reduce(0.0, +) / Double(epochs.count)
        return averageVolatility
    }
    
    // MARK: - Historical Emotional Baselines
    
    /// Get historical emotional baseline for similar time periods
    func historicalBaselineForSimilarPeriod(
        currentDate: Date,
        lookbackDays: Int = 30,
        modelContext: ModelContext
    ) async -> Double {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        let currentHour = calendar.component(.hour, from: currentDate)
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: currentDate) ?? currentDate
        
        let descriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.startDate >= cutoffDate && epoch.startDate < currentDate
            }
        )
        
        guard let epochs = try? modelContext.fetch(descriptor), !epochs.isEmpty else {
            return 0.0
        }
        
        // Weight epochs by similarity (same weekday, similar hour)
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for epoch in epochs {
            let epochWeekday = calendar.component(.weekday, from: epoch.startDate)
            let epochHour = calendar.component(.hour, from: epoch.startDate)
            
            // Similarity score (0.0 to 1.0)
            let weekdaySimilarity = epochWeekday == currentWeekday ? 1.0 : 0.5
            let hourSimilarity = 1.0 - (Double(abs(epochHour - currentHour)) / 24.0)
            let similarity = (weekdaySimilarity + hourSimilarity) / 2.0
            
            let weight = similarity * epoch.baselineStability
            weightedSum += epoch.emotionalBaseline * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
    }
    
    // MARK: - Emotional Momentum Forecasting
    
    /// Forecast emotional momentum based on recent trends
    func forecastEmotionalMomentum(
        modelContext: ModelContext
    ) async -> (momentum: Double, trend: TemporalEmotionalTrend, confidence: Double) {
        // Get recent weekly epochs (last 4 weeks)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.epochType == "weekly" && epoch.startDate >= cutoffDate
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        
        guard let epochs = try? modelContext.fetch(descriptor), epochs.count >= 2 else {
            return (0.0, TemporalEmotionalTrend.neutral, 0.0)
        }
        
        // Extract baseline values from epochs
        let recentBaselines = epochs.map { $0.emotionalBaseline }
        
        // Calculate trend
        let trend = calculateTrend(values: recentBaselines)
        
        // Calculate momentum (rate of change)
        let momentum = recentBaselines.count > 1 ?
            recentBaselines.last! - recentBaselines.first! : 0.0
        
        // Confidence based on stability and sample size
        let averageStability = epochs.map { $0.baselineStability }.reduce(0.0, +) / Double(epochs.count)
        let sampleConfidence = min(1.0, Double(epochs.count) / 4.0) // Full confidence at 4+ weeks
        let confidence = averageStability * sampleConfidence
        
        return (momentum, trend, confidence)
    }
    
    private func calculateTrend(values: [Double]) -> TemporalEmotionalTrend {
        guard values.count >= 2 else { return TemporalEmotionalTrend.neutral }
        
        // Simple linear trend
        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))
        
        let firstAvg = firstHalf.reduce(0.0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0.0, +) / Double(secondHalf.count)
        
        let change = secondAvg - firstAvg
        
        if change > 0.1 {
            return TemporalEmotionalTrend.positive
        } else if change < -0.1 {
            return TemporalEmotionalTrend.negative
        } else {
            return TemporalEmotionalTrend.neutral
        }
    }
    
    // MARK: - Integration with ToneReliabilityProfile
    
    /// Get emotional memory context for a tone (how Aurora "felt" during similar periods)
    func emotionalMemoryForTone(
        tone: AuroraTone,
        modelContext: ModelContext,
        lookbackDays: Int = 30
    ) async -> (baseline: Double, stability: Double, momentum: Double)? {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let toneRawValue = tone.rawValue
        
        // Find epochs where this tone was dominant
        let descriptor = FetchDescriptor<EmotionEpoch>(
            predicate: #Predicate<EmotionEpoch> { epoch in
                epoch.dominantTone == toneRawValue && epoch.startDate >= cutoffDate
            }
        )
        
        guard let epochs = try? modelContext.fetch(descriptor), !epochs.isEmpty else {
            return nil
        }
        
        // Calculate weighted baseline
        let weightedBaseline = epochs.map { $0.emotionalBaseline * $0.baselineStability }.reduce(0.0, +) /
            epochs.map { $0.baselineStability }.reduce(0.0, +)
        
        // Average stability
        let averageStability = epochs.map { $0.baselineStability }.reduce(0.0, +) / Double(epochs.count)
        
        // Calculate momentum (trend in baseline over time)
        let sortedEpochs = epochs.sorted { $0.startDate < $1.startDate }
        let momentum = sortedEpochs.count > 1 ?
            sortedEpochs.last!.emotionalBaseline - sortedEpochs.first!.emotionalBaseline : 0.0
        
        return (weightedBaseline, averageStability, momentum)
    }
}

// MARK: - Supporting Types

/// Emotional trend for temporal memory (different from AnalyticsEngine.EmotionalTrend)
enum TemporalEmotionalTrend: Sendable {
    case positive
    case negative
    case neutral
}

