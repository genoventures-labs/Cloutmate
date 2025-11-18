//
//  AuroraPromptVersion.swift
//  FocusOS
//
//  Model for tracking Aurora's prompt versions and cognitive configurations
//

import Foundation

// MARK: - Prompt Version Section

struct PromptSection: Codable, Sendable {
    let id: String // e.g., "core_identity", "phase_1", "behavioral_guidelines"
    let content: String
    let version: String // Version of this section
    let createdAt: String // ISO 8601 timestamp
    let metadata: [String: String] // Additional metadata (phase numbers, enabled features, etc.)
    
    init(id: String, content: String, version: String, metadata: [String: String] = [:]) {
        self.id = id
        self.content = content
        self.version = version
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.metadata = metadata
    }
}

// MARK: - Prompt Version

struct PromptVersion: Codable, Sendable {
    let versionId: String // e.g., "v1.0.0", "v1.1.0"
    let sections: [String: PromptSection] // Section ID -> Section content
    let metadata: PromptVersionMetadata
    let commitHash: String? // Git commit hash when this version was created
    let createdAt: String // ISO 8601 timestamp
    
    init(versionId: String, sections: [String: PromptSection], metadata: PromptVersionMetadata, commitHash: String? = nil, createdAt: String? = nil) {
        self.versionId = versionId
        self.sections = sections
        self.metadata = metadata
        self.commitHash = commitHash
        self.createdAt = createdAt ?? ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Prompt Version Metadata

struct PromptVersionMetadata: Codable, Sendable {
    let phase: Int // Current phase (1-10)
    let enabledPhases: [Int] // List of enabled phases
    let enabledFeatures: [String] // Feature flags (arteEnabled, predictiveCognitionEnabled, etc.)
    let promptLength: Int // Base prompt length (before payload/changelog additions)
    let finalPromptLength: Int? // Final prompt length (after payload/changelog additions)
    let sectionCount: Int // Number of sections
    let description: String // Human-readable description of this version
    
    init(
        phase: Int,
        enabledPhases: [Int],
        enabledFeatures: [String],
        promptLength: Int,
        sectionCount: Int,
        description: String,
        finalPromptLength: Int? = nil
    ) {
        self.phase = phase
        self.enabledPhases = enabledPhases
        self.enabledFeatures = enabledFeatures
        self.promptLength = promptLength
        self.finalPromptLength = finalPromptLength
        self.sectionCount = sectionCount
        self.description = description
    }
}

// MARK: - Prompt Versions Container

struct AuroraPromptVersions: Codable, Sendable {
    var currentVersion: String // Current active version ID
    var versions: [String: PromptVersion] // Version ID -> Version data
    var lastUpdated: String // ISO 8601 timestamp
    
    init(currentVersion: String, versions: [String: PromptVersion]) {
        self.currentVersion = currentVersion
        self.versions = versions
        self.lastUpdated = ISO8601DateFormatter().string(from: Date())
    }
}

