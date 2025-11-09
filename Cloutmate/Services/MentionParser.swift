//
//  MentionParser.swift
//  Cloutmate
//
//  Parses @ mentions from text input
//

import Foundation

struct MentionMatch {
    let fullText: String // e.g., "@projectname"
    let mentionText: String // e.g., "projectname"
    let range: NSRange
}

struct MentionParser {
    /// Parse @ mentions from text input
    static func parseMentions(from text: String) -> [MentionMatch] {
        // Pattern matches @word or @web followed by optional text
        // First, find all @mentions (simple pattern)
        let simplePattern = "@([\\w]+)"
        guard let regex = try? NSRegularExpression(pattern: simplePattern, options: []) else {
            return []
        }
        
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: text, options: [], range: range)
        
        return matches.compactMap { match -> MentionMatch? in
            guard match.numberOfRanges >= 2 else { return nil }
            
            let fullRange = match.range(at: 0)
            let mentionRange = match.range(at: 1)
            
            guard mentionRange.location != NSNotFound,
                  let mentionText = nsString.substring(with: mentionRange) as String? else {
                return nil
            }
            
            let fullText = nsString.substring(with: fullRange)
            
            return MentionMatch(
                fullText: fullText,
                mentionText: mentionText.trimmingCharacters(in: .whitespacesAndNewlines),
                range: fullRange
            )
        }
    }
    
    /// Check if a mention is a web search mention
    static func isWebSearchMention(_ mention: MentionMatch) -> Bool {
        return mention.mentionText.lowercased() == "web"
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
            
            // Return mention text if it's not empty
            return mentionText.isEmpty ? nil : mentionText
        }
        
        return nil
    }
    
    /// Extract mention text from a full mention string (e.g., "@projectname" -> "projectname")
    static func extractMentionText(from mention: String) -> String {
        return mention.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

