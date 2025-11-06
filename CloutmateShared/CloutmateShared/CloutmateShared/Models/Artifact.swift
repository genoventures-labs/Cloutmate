//
//  Artifact.swift
//  CloutmateShared
//
//  Created by Migration
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

@Model
public final class Artifact {
    public var id: UUID = UUID()
    public var title: String = ""
    public var content: String = ""
    public var mediaURLs: [String] = [] // Array of local file URLs
    public var outputFormat: String = OutputFormat.brief.rawValue
    public var state: String = ArtifactState.idea.rawValue
    public var publishedAt: Date?
    public var tags: [String] = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    // PARA integration
    public var projectId: UUID?
    public var areaId: UUID?
    
    // Custom properties for database views
    public var customProperties: [String: String] = [:]
    
    public init(
        title: String = "",
        content: String = "",
        mediaURLs: [String] = [],
        outputFormat: OutputFormat = .brief,
        state: ArtifactState = .idea,
        publishedAt: Date? = nil,
        tags: [String] = [],
        projectId: UUID? = nil,
        areaId: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.mediaURLs = mediaURLs
        self.outputFormat = outputFormat.rawValue
        self.state = state.rawValue
        self.publishedAt = publishedAt
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.projectId = projectId
        self.areaId = areaId
    }
    
    public var artifactState: ArtifactState {
        get { ArtifactState(rawValue: state) ?? .idea }
        set { state = newValue.rawValue }
    }
    
    public var format: OutputFormat {
        get { OutputFormat(rawValue: outputFormat) ?? .brief }
        set { outputFormat = newValue.rawValue }
    }
    
    // Convenience: Combine title and content for display
    public var fullContent: String {
        if title.isEmpty {
            return content
        }
        if content.isEmpty {
            return title
        }
        return "\(title)\n\n\(content)"
    }
    
    // Convenience: Extract title from content if not set
    public func ensureTitle() {
        if title.isEmpty && !content.isEmpty {
            let lines = content.components(separatedBy: .newlines)
            title = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        }
    }
}

