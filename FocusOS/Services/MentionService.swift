//
//  MentionService.swift
//  FocusOS
//
//  Service for parsing, resolving, and managing @mentions across all item types
//

import Foundation
import SwiftData
import FocusOSShared
import os.log

struct ResolvedMention {
    let id: UUID
    let type: ObjectType
    let title: String
    let subtitle: String
    let displayName: String
}

@MainActor
final class MentionService {
    static let shared = MentionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "MentionService")
    
    private init() {}
    
    // MARK: - Parsing
    
    /// Parse mentions from text and return both structured and plain mentions
    func parseMentions(from text: String) -> [MentionMatch] {
        return MentionParser.parseMentions(from: text)
    }
    
    // MARK: - Resolving
    
    /// Resolve a mention to an actual workspace object
    func resolveMention(
        _ mention: MentionMatch,
        modelContext: ModelContext
    ) -> ResolvedMention? {
        // If structured mention, directly look up by ID
        if let type = mention.structuredType,
           let id = mention.structuredId,
           let objectType = ObjectType(rawValue: type) {
            return resolveById(id: id, type: objectType, modelContext: modelContext)
        }
        
        // If plain mention, search by name
        if !mention.mentionText.isEmpty && mention.mentionText.lowercased() != "web" {
            return resolveByName(mention.mentionText, modelContext: modelContext)
        }
        
        return nil
    }
    
    /// Resolve all mentions in text
    func resolveAllMentions(
        from text: String,
        modelContext: ModelContext
    ) -> [ResolvedMention] {
        let mentions = parseMentions(from: text)
        var resolved: [ResolvedMention] = []
        
        for mention in mentions {
            if let resolvedMention = resolveMention(mention, modelContext: modelContext) {
                resolved.append(resolvedMention)
            }
        }
        
        return resolved
    }
    
    // MARK: - Conversion
    
    /// Convert plain mentions to structured format in text
    func convertToStructuredFormat(
        text: String,
        modelContext: ModelContext
    ) -> String {
        let mentions = parseMentions(from: text)
        var result = text
        var offset = 0
        
        // Process in reverse order to maintain indices
        for mention in mentions.reversed() {
            // Skip if already structured
            if mention.structuredType != nil {
                continue
            }
            
            // Skip @web mentions
            if MentionParser.isWebSearchMention(mention) {
                continue
            }
            
            // Resolve to get ID
            if let resolved = resolveMention(mention, modelContext: modelContext) {
                let structured = MentionParser.toStructuredFormat(type: resolved.type, id: resolved.id)
                let range = NSRange(
                    location: mention.range.location + offset,
                    length: mention.range.length
                )
                
                if let swiftRange = Range(range, in: result) {
                    result.replaceSubrange(swiftRange, with: structured)
                    offset += structured.count - mention.range.length
                }
            }
        }
        
        return MentionParser.stripTerminators(from: result)
    }
    
    /// Convert structured mentions to display names in text
    func convertToDisplayNames(
        text: String,
        modelContext: ModelContext
    ) -> String {
        let mentions = parseMentions(from: text)
        var result = text
        var offset = 0
        
        // Process in reverse order
        for mention in mentions.reversed() {
            // Only convert structured mentions
            guard let type = mention.structuredType,
                  let id = mention.structuredId,
                  let objectType = ObjectType(rawValue: type) else {
                continue
            }
            
            // Resolve to get display name
            if let resolved = resolveById(id: id, type: objectType, modelContext: modelContext) {
                let displayName = "@\(resolved.displayName)\(MentionParser.mentionTerminator)"
                let resultCount = result.utf16.count
                let rangeLocation = mention.range.location + offset
                
                // Ensure range location is within bounds
                if rangeLocation < 0 || rangeLocation >= resultCount {
                    continue
                }
                
                let availableLength = resultCount - rangeLocation
                let rangeLength = max(0, min(mention.range.length, availableLength))
                
                if rangeLength >= 1 {
                    let range = NSRange(location: rangeLocation, length: rangeLength)
                    if let swiftRange = Range(range, in: result) {
                        result.replaceSubrange(swiftRange, with: displayName)
                        offset += displayName.count - rangeLength
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - Model Updates
    
    /// Update linkedEntityIds and linkedEntityTypes arrays for a model
    func updateLinkedEntities<T>(
        for item: T,
        text: String,
        modelContext: ModelContext,
        updateHandler: ([UUID], [String]) -> Void
    ) {
        let resolved = resolveAllMentions(from: text, modelContext: modelContext)
        let ids = resolved.map { $0.id }
        let types = resolved.map { $0.type.rawValue }
        
        updateHandler(ids, types)
        
        logger.debug("Updated linked entities: \(ids.count) mentions")
    }
    
    // MARK: - Private Helpers
    
    private func resolveById(
        id: UUID,
        type: ObjectType,
        modelContext: ModelContext
    ) -> ResolvedMention? {
        if let details = WorkspaceObjectSearchService.shared.getObjectDetails(
            id: id,
            type: type,
            modelContext: modelContext
        ) {
            return ResolvedMention(
                id: id,
                type: type,
                title: details.title,
                subtitle: details.subtitle,
                displayName: details.title
            )
        }
        return nil
    }
    
    private func resolveByName(
        _ name: String,
        modelContext: ModelContext
    ) -> ResolvedMention? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        
        let results = WorkspaceObjectSearchService.shared.search(
            query: trimmedName,
            modelContext: modelContext,
            limit: 10 // Get more results to find best match
        )
        
        // Prefer exact matches for multi-word mentions
        // First try exact match (case-insensitive)
        if let exactMatch = results.first(where: { 
            $0.title.lowercased() == trimmedName.lowercased() 
        }) {
            return ResolvedMention(
                id: exactMatch.id,
                type: exactMatch.type,
                title: exactMatch.title,
                subtitle: exactMatch.subtitle,
                displayName: exactMatch.displayName
            )
        }
        
        // Fall back to best match score
        guard let first = results.first else { return nil }
        
        return ResolvedMention(
            id: first.id,
            type: first.type,
            title: first.title,
            subtitle: first.subtitle,
            displayName: first.displayName
        )
    }
}

