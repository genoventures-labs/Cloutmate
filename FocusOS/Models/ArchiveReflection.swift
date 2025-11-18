//
//  ArchiveReflection.swift
//  FocusOS
//
//  Archives V2 - AI-generated reflections for archived items
//

import Foundation
import SwiftData

@Model
final class ArchiveReflection {
    @Attribute(.unique) var id: UUID
    var entityId: UUID
    var entityType: String // "Project", "Note", "Artifact", "Area", "Draft"
    var reflectionText: String
    var auroraCommentary: String?
    var generatedAt: Date
    var arteToneSnapshot: String? // EmotionalState.rawValue
    var focusGravityScore: Double?
    var learningThemes: [String] // From Predictive Cognition
    
    init(
        entityId: UUID,
        entityType: String,
        reflectionText: String,
        auroraCommentary: String? = nil,
        arteToneSnapshot: String? = nil,
        focusGravityScore: Double? = nil,
        learningThemes: [String] = []
    ) {
        self.id = UUID()
        self.entityId = entityId
        self.entityType = entityType
        self.reflectionText = reflectionText
        self.auroraCommentary = auroraCommentary
        self.generatedAt = Date()
        self.arteToneSnapshot = arteToneSnapshot
        self.focusGravityScore = focusGravityScore
        self.learningThemes = learningThemes
    }
}

