//
//  MentionParser.swift
//  Cloutmate
//
//  Parses @ mentions from text input
//

import Foundation

extension NSRange {
    func intersects(_ other: NSRange) -> Bool {
        return location < other.location + other.length && other.location < location + length
    }
}

struct MentionMatch {
    let fullText: String // e.g., "@projectname" or "@{task:uuid}"
    let mentionText: String // e.g., "projectname" or "{task:uuid}"
    let range: NSRange
    let structuredType: String? // e.g., "task" from @{task:uuid}
    let structuredId: UUID? // e.g., UUID from @{task:uuid}
}

struct MentionParser {
    /// Parse @ mentions from text input
    /// Supports both structured format (@{type:id}) and plain format (@name)
    static func parseMentions(from text: String) -> [MentionMatch] {
        var matches: [MentionMatch] = []
        let nsString = text as NSString
        
        // First, find structured mentions: @{type:uuid}
        let structuredPattern = "@\\{([a-zA-Z]+):([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\\}"
        if let structuredRegex = try? NSRegularExpression(pattern: structuredPattern, options: []) {
        let range = NSRange(location: 0, length: nsString.length)
            let structuredMatches = structuredRegex.matches(in: text, options: [], range: range)
        
            for match in structuredMatches {
                guard match.numberOfRanges >= 3 else { continue }
                
                let fullRange = match.range(at: 0)
                let typeRange = match.range(at: 1)
                let idRange = match.range(at: 2)
                
                guard typeRange.location != NSNotFound,
                      idRange.location != NSNotFound,
                      let typeString = nsString.substring(with: typeRange) as String?,
                      let idString = nsString.substring(with: idRange) as String?,
                      let uuid = UUID(uuidString: idString) else {
                    continue
                }
                
                let fullText = nsString.substring(with: fullRange)
                
                matches.append(MentionMatch(
                    fullText: fullText,
                    mentionText: "{\(typeString):\(idString)}",
                    range: fullRange,
                    structuredType: typeString,
                    structuredId: uuid
                ))
            }
        }
        
        // Then find plain mentions: @word (but exclude structured ones we already found)
        let plainPattern = "@([\\w]+)"
        if let plainRegex = try? NSRegularExpression(pattern: plainPattern, options: []) {
            let range = NSRange(location: 0, length: nsString.length)
            let plainMatches = plainRegex.matches(in: text, options: [], range: range)
            
            for match in plainMatches {
                guard match.numberOfRanges >= 2 else { continue }
            
            let fullRange = match.range(at: 0)
            let mentionRange = match.range(at: 1)
                
                // Skip if this range overlaps with any structured mention
                if matches.contains(where: { $0.range.intersects(fullRange) }) {
                    continue
                }
            
            guard mentionRange.location != NSNotFound,
                  let mentionText = nsString.substring(with: mentionRange) as String? else {
                    continue
            }
            
            let fullText = nsString.substring(with: fullRange)
            
                matches.append(MentionMatch(
                fullText: fullText,
                mentionText: mentionText.trimmingCharacters(in: .whitespacesAndNewlines),
                    range: fullRange,
                    structuredType: nil,
                    structuredId: nil
                ))
        }
        }
        
        // Sort by position in text
        return matches.sorted { $0.range.location < $1.range.location }
    }
    
    /// Convert a mention to structured format: @{type:id}
    static func toStructuredFormat(type: ObjectType, id: UUID) -> String {
        return "@{\(type.rawValue):\(id.uuidString)}"
    }
    
    /// Extract type and ID from structured mention
    static func parseStructuredMention(_ text: String) -> (type: ObjectType, id: UUID)? {
        let pattern = "@\\{([a-zA-Z]+):([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              match.numberOfRanges >= 3 else {
            return nil
        }
        
        let nsString = text as NSString
        guard let typeString = nsString.substring(with: match.range(at: 1)) as String?,
              let idString = nsString.substring(with: match.range(at: 2)) as String?,
              let type = ObjectType(rawValue: typeString),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        
        return (type: type, id: id)
    }
    
    /// Check if a mention is a web search mention
    static func isWebSearchMention(_ mention: MentionMatch) -> Bool {
        return mention.mentionText.lowercased() == "web" && mention.structuredType == nil
    }
    
    /// Extract search query from @web mention in text
    static func extractWebSearchQuery(from text: String, mention: MentionMatch) -> String? {
        guard isWebSearchMention(mention) else { return nil }
        
        // Find text after "@web " - look for the next word boundary or end of string
        let mentionEnd = mention.range.location + mention.range.length
        
        // Check if there's text immediately after "@web"
        if mentionEnd < text.count {
            let remainingText = String(text[text.index(text.startIndex, offsetBy: mentionEnd)...])
            let trimmed = remainingText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If there's text, extract until next @ or end of line/string
            if !trimmed.isEmpty {
                // Find the end of the query (next @, newline, or end of string)
                var queryEnd = trimmed.count
                if let nextAt = trimmed.firstIndex(of: "@") {
                    queryEnd = trimmed.distance(from: trimmed.startIndex, to: nextAt)
                } else if let newline = trimmed.firstIndex(of: "\n") {
                    queryEnd = trimmed.distance(from: trimmed.startIndex, to: newline)
                }
                
                let query = String(trimmed.prefix(queryEnd)).trimmingCharacters(in: .whitespacesAndNewlines)
                return query.isEmpty ? nil : query
            }
        }
        
        return nil
    }
    
    /// Check if cursor is currently inside a mention (e.g., typing "@proj")
    static func getCurrentMention(from text: String, cursorPosition: Int) -> String? {
        if let info = getCurrentMentionInfo(from: text, cursorPosition: cursorPosition) {
            return info.text
        }
        return nil
    }
    
    /// Get current mention info including range
    static func getCurrentMentionInfo(from text: String, cursorPosition: Int) -> (text: String, range: NSRange)? {
        // Find the @ symbol before cursor
        let textBeforeCursor = String(text.prefix(cursorPosition))
        
        // Find the last @ symbol
        if let atIndex = textBeforeCursor.lastIndex(of: "@") {
            let afterAt = String(textBeforeCursor[textBeforeCursor.index(after: atIndex)...])
            
            // Check if there's a space or newline after @ (means mention ended)
            if let spaceIndex = afterAt.firstIndex(where: { $0.isWhitespace || $0.isNewline }) {
                return nil // Mention already ended
            }
            
            // Extract mention text (everything after @ until cursor)
            let mentionText = afterAt.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Calculate range (even if mentionText is empty, we still have "@")
            let nsString = text as NSString
            let atLocation = nsString.range(of: "@", options: .backwards, range: NSRange(location: 0, length: cursorPosition)).location
            if atLocation != NSNotFound {
                let range = NSRange(location: atLocation, length: cursorPosition - atLocation)
                // Return empty string if just "@" was typed
                return (text: mentionText, range: range)
            }
        }
        
        return nil
    }
    
    /// Extract mention text from a full mention string (e.g., "@projectname" -> "projectname")
    static func extractMentionText(from mention: String) -> String {
        return mention.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

