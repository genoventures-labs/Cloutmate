//
//  ArtifactMention.swift
//  FocusOSShared
//
//  Artifacts V2 - Tracks @mentions within artifacts
//

import Foundation
import SwiftData

@Model
public final class ArtifactMention {
    @Attribute(.unique) public var id: UUID
    public var artifactId: UUID
    public var mentionedEntityId: UUID
    public var mentionedEntityType: String // "project", "area", "task", "focusSession"
    public var mentionText: String // The actual @mention text
    public var position: Int // Character position in content
    
    public init(
        artifactId: UUID,
        mentionedEntityId: UUID,
        mentionedEntityType: String,
        mentionText: String,
        position: Int
    ) {
        self.id = UUID()
        self.artifactId = artifactId
        self.mentionedEntityId = mentionedEntityId
        self.mentionedEntityType = mentionedEntityType
        self.mentionText = mentionText
        self.position = position
    }
}

