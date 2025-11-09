//
//  ArchiveReflectionService.swift
//  Cloutmate
//
//  Archives V2 - AI reflection generation for archived items
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class ArchiveReflectionService {
    static let shared = ArchiveReflectionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ArchiveReflection")
    
    private init() {}
    
    // MARK: - Reflection Generation
    
    func generateReflection(
        for item: ArchiveItem,
        modelContext: ModelContext
    ) async throws -> ArchiveReflection {
        logger.info("Generating reflection for archived \(item.entityType)")
        
        // Check if reflection already exists
        if let existing = try? await getOrCreateReflection(for: item.id, modelContext: modelContext) {
            return existing
        }
        
        // Gather context
        let arteTone = await getARTEToneSnapshot(for: item, modelContext: modelContext)
        let focusGravity = await getFocusGravityScore(for: item, modelContext: modelContext)
        let learningThemes = await getLearningThemes(for: item, modelContext: modelContext)
        
        // Build AI prompt
        let prompt = buildReflectionPrompt(for: item, arteTone: arteTone, focusGravity: focusGravity, learningThemes: learningThemes)
        
        // Generate reflection via CoreResponseService
        let reflectionText = try await CoreResponseService.shared.generateResponse(
            for: prompt,
            context: "",
            modelContext: modelContext
        )
        
        // Generate Aurora commentary
        let auroraCommentary = try? await generateAuroraCommentary(for: item, reflectionText: reflectionText, modelContext: modelContext)
        
        // Create reflection model
        let reflection = ArchiveReflection(
            entityId: item.id,
            entityType: item.entityType,
            reflectionText: reflectionText,
            auroraCommentary: auroraCommentary,
            arteToneSnapshot: arteTone?.rawValue,
            focusGravityScore: focusGravity,
            learningThemes: learningThemes
        )
        
        modelContext.insert(reflection)
        try modelContext.save()
        
        logger.info("Generated reflection for \(item.entityType) \(item.id)")
        return reflection
    }
    
    func getOrCreateReflection(
        for itemId: UUID,
        modelContext: ModelContext
    ) async -> ArchiveReflection? {
        let descriptor = FetchDescriptor<ArchiveReflection>(
            predicate: #Predicate { $0.entityId == itemId }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func getARTEToneSnapshot(for item: ArchiveItem, modelContext: ModelContext) async -> EmotionalState? {
        // Get current ARTE state as snapshot
        return ReactiveThemeManager.shared.currentEmotion()
    }
    
    private func getFocusGravityScore(for item: ArchiveItem, modelContext: ModelContext) async -> Double? {
        switch item {
        case .project(let project):
            let metrics = ProjectFocusGravityService.shared.focusMetrics(for: project, modelContext: modelContext)
            return (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
        default:
            return nil
        }
    }
    
    private func getLearningThemes(for item: ArchiveItem, modelContext: ModelContext) async -> [String] {
        // Query Predictive Cognition for themes
        // For now, return empty array - can be enhanced with ConceptTracker integration
        return []
    }
    
    private func buildReflectionPrompt(
        for item: ArchiveItem,
        arteTone: EmotionalState?,
        focusGravity: Double?,
        learningThemes: [String]
    ) -> String {
        let entityType = item.entityType
        let title = item.title
        let description = item.description
        
        var prompt = "Generate a reflection for this archived \(entityType): \"\(title)\"\n\n"
        
        if let description = description, !description.isEmpty {
            prompt += "Description: \(description)\n\n"
        }
        
        if let tone = arteTone {
            prompt += "Emotional tone during work: \(tone.displayName)\n\n"
        }
        
        if let gravity = focusGravity {
            prompt += "Focus gravity score: \(String(format: "%.2f", gravity))\n\n"
        }
        
        if !learningThemes.isEmpty {
            prompt += "Learning themes: \(learningThemes.joined(separator: ", "))\n\n"
        }
        
        prompt += "Consider its emotional journey, completion patterns, and learning outcomes. Write a thoughtful reflection (2-3 sentences) that captures what this \(entityType) meant and what was learned."
        
        return prompt
    }
    
    private func generateAuroraCommentary(
        for item: ArchiveItem,
        reflectionText: String,
        modelContext: ModelContext
    ) async throws -> String {
        let prompt = "Based on this reflection for \"\(item.title)\", write a brief Aurora commentary (1 sentence) that provides insight about patterns or growth. Be warm and insightful."
        
        return try await CoreResponseService.shared.generateResponse(
            for: prompt,
            context: reflectionText,
            modelContext: modelContext
        )
    }
}

// MARK: - ArchiveItem Protocol

protocol ArchiveItemProtocol {
    var id: UUID { get }
    var title: String { get }
    var entityType: String { get }
    var description: String? { get }
}

enum ArchiveItem: ArchiveItemProtocol, Identifiable {
    case project(CloutmateShared.Project)
    case area(Area)
    case note(CloutmateShared.Note)
    case artifact(CloutmateShared.Artifact)
    case draft(Draft)
    
    var id: UUID {
        switch self {
        case .project(let p): return p.id
        case .area(let a): return a.id
        case .note(let n): return n.id
        case .artifact(let a): return a.id
        case .draft(let d): return d.id
        }
    }
    
    var title: String {
        switch self {
        case .project(let p): return p.title
        case .area(let a): return a.title
        case .note(let n): return n.title
        case .artifact(let a): return a.title
        case .draft(let d): return d.title.isEmpty ? d.caption : d.title
        }
    }
    
    var entityType: String {
        switch self {
        case .project: return "Project"
        case .area: return "Area"
        case .note: return "Note"
        case .artifact: return "Artifact"
        case .draft: return "Draft"
        }
    }
    
    var description: String? {
        switch self {
        case .project(let p): return p.goal
        case .area(let a): return a.notes
        case .note(let n): return n.markdown.isEmpty ? nil : String(n.markdown.prefix(200))
        case .artifact(let a): return a.content.isEmpty ? nil : String(a.content.prefix(200))
        case .draft(let d): return d.caption.isEmpty ? nil : d.caption
        }
    }
    
    var archivedAt: Date? {
        switch self {
        case .project(let p): return p.archivedAt ?? (p.status == .completed || p.status == .paused ? p.updatedAt : nil)
        case .area(let a): return a.archivedAt ?? (a.status == .archived ? a.updatedAt : nil)
        case .note(let n): return n.archivedAt ?? (n.isArchived ? n.updatedAt : nil)
        case .artifact(let a): return a.archivedAt ?? (a.artifactState == .archived ? a.updatedAt : nil)
        case .draft(let d): return d.archivedAt ?? (d.isArchived ? d.updatedAt : nil)
        }
    }
}

