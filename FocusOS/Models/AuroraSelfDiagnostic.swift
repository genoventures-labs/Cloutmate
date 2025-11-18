//
//  AuroraSelfDiagnostic.swift
//  FocusOS
//
//  Self-Reflection Diagnostic Model for Aurora
//  Stores Aurora's introspection about her own cognitive state
//

import Foundation
import SwiftData

@Model
final class AuroraSelfDiagnostic {
    @Attribute(.unique) var id: UUID
    var generatedAt: Date
    var period: String  // "quarter", "month", "week", etc.
    
    // Memory Management
    var totalMemoriesSummarized: Int
    var compressedThemesCount: Int
    var activeThemesCount: Int
    var compressionRatio: Double  // 0.0 to 1.0
    var spaceSavedBytes: Int64
    
    // Pattern Recognition
    var topRecurringMotifs: [String]  // Array of motif names
    var motifFrequencies: [String: Int]  // Motif name -> frequency
    var themeGrowth: [String: Double]  // Theme name -> growth percentage
    var themeDecline: [String: Double]  // Theme name -> decline percentage
    
    // Graph Health
    var activeNodesCount: Int
    var totalEdgesCount: Int
    var clusterCount: Int
    var averageConnectionStrength: Double
    var nodeDensity: Double
    
    // Compression Stats
    var revivalCount: Int  // Times compressed memories were revived
    
    // Natural Language Summary
    var naturalLanguageSummary: String
    
    init(
        period: String,
        totalMemoriesSummarized: Int,
        compressedThemesCount: Int,
        activeThemesCount: Int,
        compressionRatio: Double,
        spaceSavedBytes: Int64,
        topRecurringMotifs: [String],
        motifFrequencies: [String: Int],
        themeGrowth: [String: Double],
        themeDecline: [String: Double],
        activeNodesCount: Int,
        totalEdgesCount: Int,
        clusterCount: Int,
        averageConnectionStrength: Double,
        nodeDensity: Double,
        revivalCount: Int,
        naturalLanguageSummary: String
    ) {
        self.id = UUID()
        self.generatedAt = Date()
        self.period = period
        self.totalMemoriesSummarized = totalMemoriesSummarized
        self.compressedThemesCount = compressedThemesCount
        self.activeThemesCount = activeThemesCount
        self.compressionRatio = compressionRatio
        self.spaceSavedBytes = spaceSavedBytes
        self.topRecurringMotifs = topRecurringMotifs
        self.motifFrequencies = motifFrequencies
        self.themeGrowth = themeGrowth
        self.themeDecline = themeDecline
        self.activeNodesCount = activeNodesCount
        self.totalEdgesCount = totalEdgesCount
        self.clusterCount = clusterCount
        self.averageConnectionStrength = averageConnectionStrength
        self.nodeDensity = nodeDensity
        self.revivalCount = revivalCount
        self.naturalLanguageSummary = naturalLanguageSummary
    }
    
    /// Format space saved as human-readable string
    var formattedSpaceSaved: String {
        let mb = Double(spaceSavedBytes) / (1024 * 1024)
        if mb >= 1.0 {
            return String(format: "%.1fMB", mb)
        } else {
            let kb = Double(spaceSavedBytes) / 1024
            return String(format: "%.1fKB", kb)
        }
    }
}

