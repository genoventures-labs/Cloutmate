//
//  AuroraSelfReflectionService.swift
//  FocusOS
//
//  Self-Reflection Diagnostic Service for Aurora
//  Aggregates memory statistics and generates self-awareness diagnostics
//

import Foundation
import SwiftData
import os.log

@MainActor
final class AuroraSelfReflectionService {
    static let shared = AuroraSelfReflectionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AuroraSelfReflection")
    
    private init() {}
    
    /// Generate a self-reflection diagnostic for Aurora
    func generateDiagnostic(
        period: String = "quarter",
        modelContext: ModelContext
    ) async -> AuroraSelfDiagnostic {
        logger.info("Generating Aurora self-reflection diagnostic for period: \(period)")
        
        // Gather memory statistics
        let memoryStats = gatherMemoryStatistics(modelContext: modelContext)
        
        // Gather compression statistics
        let compressionStats = gatherCompressionStatistics(modelContext: modelContext)
        
        // Gather graph health metrics
        let graphHealth = gatherGraphHealthMetrics(modelContext: modelContext)
        
        // Identify recurring motifs
        let motifs = identifyRecurringMotifs(modelContext: modelContext, period: period)
        
        // Calculate theme evolution
        let themeEvolution = calculateThemeEvolution(modelContext: modelContext, period: period)
        
        // Generate natural language summary
        let naturalLanguageSummary = await generateNaturalLanguageSummary(
            memoryStats: memoryStats,
            compressionStats: compressionStats,
            graphHealth: graphHealth,
            motifs: motifs,
            themeEvolution: themeEvolution
        )
        
        // Create diagnostic
        let diagnostic = AuroraSelfDiagnostic(
            period: period,
            totalMemoriesSummarized: memoryStats.totalSummarized,
            compressedThemesCount: compressionStats.compressedThemes,
            activeThemesCount: memoryStats.activeThemes,
            compressionRatio: compressionStats.compressionRatio,
            spaceSavedBytes: compressionStats.spaceSaved,
            topRecurringMotifs: motifs.topMotifs,
            motifFrequencies: motifs.frequencies,
            themeGrowth: themeEvolution.growth,
            themeDecline: themeEvolution.decline,
            activeNodesCount: graphHealth.activeNodes,
            totalEdgesCount: graphHealth.totalEdges,
            clusterCount: graphHealth.clusters,
            averageConnectionStrength: graphHealth.avgConnectionStrength,
            nodeDensity: graphHealth.nodeDensity,
            revivalCount: compressionStats.revivalCount,
            naturalLanguageSummary: naturalLanguageSummary
        )
        
        // Save diagnostic
        modelContext.insert(diagnostic)
        try? modelContext.save()
        
        logger.info("Generated diagnostic: \(memoryStats.totalSummarized) memories, \(memoryStats.activeThemes) active themes")
        
        return diagnostic
    }
    
    // MARK: - Memory Statistics
    
    private func gatherMemoryStatistics(modelContext: ModelContext) -> (totalSummarized: Int, activeThemes: Int) {
        // Count MemorySummary entries
        let summaryDescriptor = FetchDescriptor<MemorySummary>()
        let summaries = (try? modelContext.fetch(summaryDescriptor)) ?? []
        let totalSummarized = summaries.count
        
        // Count active themes
        let activeThemes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext).count
        
        return (totalSummarized, activeThemes)
    }
    
    // MARK: - Compression Statistics
    
    private func gatherCompressionStatistics(modelContext: ModelContext) -> (
        compressedThemes: Int,
        compressionRatio: Double,
        spaceSaved: Int64,
        revivalCount: Int
    ) {
        let summaryDescriptor = FetchDescriptor<MemorySummary>()
        let summaries = (try? modelContext.fetch(summaryDescriptor)) ?? []
        
        // Count archived themes
        let archivedThemes = summaries.filter { $0.isArchived }.count
        
        // Calculate average compression ratio
        let avgCompressionRatio = summaries.isEmpty ? 0.0 :
            summaries.reduce(0.0) { $0 + $1.compressionRatio } / Double(summaries.count)
        
        // Estimate space saved (rough calculation)
        // This is approximate since we don't store original sizes
        let estimatedSpaceSaved = summaries.reduce(Int64(0)) { total, summary in
            // Estimate: if compression ratio is 0.3, we saved 70% of original
            let estimatedOriginalSize = Int64(Double(summary.summaryText.utf8.count) / summary.compressionRatio)
            let saved = estimatedOriginalSize - Int64(summary.summaryText.utf8.count)
            return total + max(0, saved)
        }
        
        // Count revivals
        let revivalCount = summaries.reduce(0) { $0 + $1.revivalCount }
        
        return (archivedThemes, avgCompressionRatio, estimatedSpaceSaved, revivalCount)
    }
    
    // MARK: - Graph Health Metrics
    
    private func gatherGraphHealthMetrics(modelContext: ModelContext) -> (
        activeNodes: Int,
        totalEdges: Int,
        clusters: Int,
        avgConnectionStrength: Double,
        nodeDensity: Double
    ) {
        // Get nodes
        let nodeDescriptor = FetchDescriptor<MemoryNode>()
        let nodes = (try? modelContext.fetch(nodeDescriptor)) ?? []
        let activeNodes = nodes.count
        
        // Get edges
        let edgeDescriptor = FetchDescriptor<MemoryEdge>()
        let edges = (try? modelContext.fetch(edgeDescriptor)) ?? []
        let totalEdges = edges.count
        
        // Get themes (clusters)
        let themeDescriptor = FetchDescriptor<ThemeNode>()
        let themes = (try? modelContext.fetch(themeDescriptor)) ?? []
        let clusters = themes.count
        
        // Calculate average connection strength
        let avgConnectionStrength = edges.isEmpty ? 0.0 :
            edges.reduce(0.0) { $0 + $1.weight } / Double(edges.count)
        
        // Calculate node density (edges per node)
        let nodeDensity = activeNodes == 0 ? 0.0 :
            Double(totalEdges) / Double(activeNodes)
        
        return (activeNodes, totalEdges, clusters, avgConnectionStrength, nodeDensity)
    }
    
    // MARK: - Recurring Motifs
    
    private func identifyRecurringMotifs(
        modelContext: ModelContext,
        period: String
    ) -> (topMotifs: [String], frequencies: [String: Int]) {
        // Get active themes and their keywords
        let themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)
        
        // Count keyword frequencies across themes
        var keywordCounts: [String: Int] = [:]
        for theme in themes {
            for keyword in theme.keywords {
                keywordCounts[keyword, default: 0] += 1
            }
        }
        
        // Sort by frequency and get top motifs
        let sortedKeywords = keywordCounts.sorted { $0.value > $1.value }
        let topMotifs = Array(sortedKeywords.prefix(5)).map { $0.key }
        
        return (topMotifs, keywordCounts)
    }
    
    // MARK: - Theme Evolution
    
    private func calculateThemeEvolution(
        modelContext: ModelContext,
        period: String
    ) -> (growth: [String: Double], decline: [String: Double]) {
        let themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)
        
        var growth: [String: Double] = [:]
        var decline: [String: Double] = [:]
        
        // Calculate momentum-based growth/decline
        for theme in themes {
            if theme.momentum > 0.1 {
                growth[theme.label] = theme.momentum * 100  // Convert to percentage
            } else if theme.momentum < -0.1 {
                decline[theme.label] = abs(theme.momentum) * 100
            }
        }
        
        return (growth, decline)
    }
    
    // MARK: - Natural Language Generation
    
    private func generateNaturalLanguageSummary(
        memoryStats: (totalSummarized: Int, activeThemes: Int),
        compressionStats: (compressedThemes: Int, compressionRatio: Double, spaceSaved: Int64, revivalCount: Int),
        graphHealth: (activeNodes: Int, totalEdges: Int, clusters: Int, avgConnectionStrength: Double, nodeDensity: Double),
        motifs: (topMotifs: [String], frequencies: [String: Int]),
        themeEvolution: (growth: [String: Double], decline: [String: Double])
    ) async -> String {
        // Build natural language summary
        var summary = "I've summarized \(memoryStats.totalSummarized) memories"
        
        if compressionStats.compressedThemes > 0 {
            summary += " and compressed \(compressionStats.compressedThemes) inactive themes"
        }
        
        if !motifs.topMotifs.isEmpty {
            let topMotif = motifs.topMotifs.first ?? "patterns"
            summary += ". My most recurring motif is '\(topMotif)'"
        }
        
        if graphHealth.activeNodes > 0 {
            summary += ". My memory graph currently has \(graphHealth.activeNodes) active nodes"
            if graphHealth.clusters > 0 {
                summary += " with \(graphHealth.clusters) distinct clusters"
            }
        }
        
        if !themeEvolution.growth.isEmpty {
            let topGrowth = themeEvolution.growth.max(by: { $0.value < $1.value })
            if let (theme, growthPct) = topGrowth {
                summary += ". I notice '\(theme)' has grown \(Int(growthPct))% in relevance"
            }
        }
        
        if compressionStats.spaceSaved > 0 {
            let diagnostic = AuroraSelfDiagnostic(
                period: "temp",
                totalMemoriesSummarized: memoryStats.totalSummarized,
                compressedThemesCount: compressionStats.compressedThemes,
                activeThemesCount: memoryStats.activeThemes,
                compressionRatio: compressionStats.compressionRatio,
                spaceSavedBytes: compressionStats.spaceSaved,
                topRecurringMotifs: motifs.topMotifs,
                motifFrequencies: motifs.frequencies,
                themeGrowth: themeEvolution.growth,
                themeDecline: themeEvolution.decline,
                activeNodesCount: graphHealth.activeNodes,
                totalEdgesCount: graphHealth.totalEdges,
                clusterCount: graphHealth.clusters,
                averageConnectionStrength: graphHealth.avgConnectionStrength,
                nodeDensity: graphHealth.nodeDensity,
                revivalCount: compressionStats.revivalCount,
                naturalLanguageSummary: ""
            )
            summary += ", saving \(diagnostic.formattedSpaceSaved) through compression"
        }
        
        summary += "."
        
        return summary
    }
    
    /// Get the most recent diagnostic
    func getLatestDiagnostic(modelContext: ModelContext) -> AuroraSelfDiagnostic? {
        let descriptor = FetchDescriptor<AuroraSelfDiagnostic>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }
}

