//
//  MentionParser.swift
//  FocusOS
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
    static let mentionTerminator = "\u{200B}" // zero-width space used as mention boundary
    static let mentionTerminatorCharacter: Character = "\u{200B}"
    
    static func stripTerminators(from text: String) -> String {
        text.replacingOccurrences(of: mentionTerminator, with: "")
    }
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
        
        // Then find plain mentions: @word or @multi word phrase (but exclude structured ones we already found)
        // Match @ followed by characters (including spaces) until we hit a newline, another @, or end of string
        // The pattern matches everything after @ except @ and newline characters
        let plainPattern = "@([^@\\n]+)"
        if let plainRegex = try? NSRegularExpression(pattern: plainPattern, options: []) {
            let range = NSRange(location: 0, length: nsString.length)
            let plainMatches = plainRegex.matches(in: text, options: [], range: range)
            
            for match in plainMatches {
                guard match.numberOfRanges >= 2 else { continue }
                
                let fullRange = match.range(at: 0)
                var mentionRange = match.range(at: 1)
                
                // Skip if this range overlaps with any structured mention
                if matches.contains(where: { $0.range.intersects(fullRange) }) {
                    continue
                }
                
                guard mentionRange.location != NSNotFound,
                      mentionRange.length > 0 else {
                    continue
                }
                
                var highlightRange = fullRange
                var mentionSubstringRange = mentionRange
                
                // Adjust range if mention terminator is present
                let rawFullText = nsString.substring(with: fullRange)
                var fullText = rawFullText
                if let terminatorIndex = fullText.firstIndex(of: mentionTerminatorCharacter) {
                    fullText = String(fullText[..<terminatorIndex])
                    let adjustedLength = (fullText as NSString).length
                    // Ensure range length remains valid (at least 1 for the "@")
                    let clampedLength = max(1, adjustedLength)
                    highlightRange = NSRange(location: fullRange.location, length: clampedLength)
                    mentionSubstringRange = NSRange(location: highlightRange.location + 1, length: max(highlightRange.length - 1, 0))
                }
                
                if highlightRange.length <= 1 {
                    continue
                }
                
                var mentionText = mentionSubstringRange.length > 0 ? nsString.substring(with: mentionSubstringRange) : ""
                
                // Strip terminator characters from mention text
                mentionText = stripTerminators(from: mentionText)
                
                // Trim trailing whitespace from mention text
                let trimmedMentionText = mentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip if mention text is empty or only whitespace
                if trimmedMentionText.isEmpty {
                    continue
                }
                
                // Build full text without terminator
                fullText = stripTerminators(from: fullText)
                
                matches.append(MentionMatch(
                    fullText: fullText,
                    mentionText: trimmedMentionText,
                    range: highlightRange,
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
            var afterAt = String(textBeforeCursor[textBeforeCursor.index(after: atIndex)...])
            
            if let terminatorIndex = afterAt.firstIndex(of: mentionTerminatorCharacter) {
                afterAt = String(afterAt[..<terminatorIndex])
            }
            
            // Check if there's a newline after @ (means mention ended)
            // Allow spaces within mentions for multi-word phrases
            if let newlineIndex = afterAt.firstIndex(where: { $0.isNewline }) {
                return nil // Mention ended at newline
            }
            
            // Extract mention text (everything after @ until cursor, including spaces)
            // Preserve internal spaces for multi-word mentions like "@Focus Gravity Redo"
            // Only trim leading/trailing whitespace
            let mentionText = afterAt.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Calculate range (from @ to cursor position)
            let nsString = text as NSString
            let atLocation = nsString.range(of: "@", options: .backwards, range: NSRange(location: 0, length: cursorPosition)).location
            if atLocation != NSNotFound {
                // Range includes @ symbol and all text up to cursor
                let range = NSRange(location: atLocation, length: cursorPosition - atLocation)
                // Return mention text (without @) and range (including @)
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

