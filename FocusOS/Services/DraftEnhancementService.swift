//
//  DraftEnhancementService.swift
//  FocusOS
//
//  Aurora AI enhancements for Drafts: improvements, summaries, titles, captions.
//

import Foundation
import SwiftData

struct DraftEnhancementSuggestion: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    let replacement: String?
    
    init(id: UUID = UUID(), title: String, detail: String, replacement: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.replacement = replacement
    }
}

actor DraftEnhancementService {
    static let shared = DraftEnhancementService()
    
    private let coreResponseService = CoreResponseService.shared
    private init() {}
    
    // MARK: - Suggestions
    
    func requestImprovement(
        for draft: Draft,
        title: String,
        content: String,
        tags: [String]
    ) async throws -> [DraftEnhancementSuggestion] {
        let prompt = """
        You are Aurora, the creative intelligence inside FocusOS. Improve the following draft.
        
        Draft title: \(title)
        Tags: \(tags.isEmpty ? "none" : tags.joined(separator: ", "))
        
        Draft content:
        \"\"\"
        \(content)
        \"\"\"
        
        Respond ONLY with JSON array. Each element must have:
        - title: short headline for the suggestion
        - detail: explanation (2 sentences max)
        - replacement: optional improved version of the draft section (omit if not necessary)
        
        Example output:
        [
          {
            "title": "...",
            "detail": "...",
            "replacement": "..."
          }
        ]
        """
        
        let response = try await coreResponseService.generateResponse(for: prompt)
        if let suggestions: [DraftEnhancementSuggestionPayload] = decodeJSONArray(from: response) {
            return suggestions.map { $0.makeSuggestion() }
        }
        
        // Fallback: return single suggestion with original content.
        return [
            DraftEnhancementSuggestion(
                title: "Polish draft",
                detail: "Aurora couldn't parse a structured response. Try again soon.",
                replacement: nil
            )
        ]
    }
    
    // MARK: - Summary
    
    func generateSummary(
        for draft: Draft,
        title: String,
        content: String
    ) async throws -> String {
        let prompt = """
        You are Aurora, summarizing a user's creative draft. Summarize in 3 concise sentences.
        
        Title: \(title)
        Draft:
        \"\"\"
        \(content)
        \"\"\"
        
        Respond with plain text summary only.
        """
        return try await coreResponseService.generateResponse(for: prompt)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Titles
    
    func suggestTitleVariants(
        for draft: Draft,
        limit: Int
    ) async throws -> [String] {
        let draftTitle = await MainActor.run { draft.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        let fallbackTitle = await MainActor.run { draft.displayTitle }
        let draftBody = await MainActor.run { draft.caption }
        
        let effectiveTitle = draftTitle.isEmpty ? fallbackTitle : draftTitle
        
        let prompt = """
        Generate \(limit) title variants for the following draft. Titles should feel energetic yet calm.
        Return JSON array of strings only.
        
        Current title: \(effectiveTitle)
        
        Draft body:
        \"\"\"
        \(draftBody)
        \"\"\"
        """
        
        let response = try await coreResponseService.generateResponse(for: prompt)
        if let titles: [String] = decodeJSONArray(from: response) {
            return titles
        }
        // Fallback: split lines
        return response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "-•*")) }
            .filter { !$0.isEmpty }
            .prefix(limit)
            .map { String($0) }
    }
    
    // MARK: - Captions
    
    func generateCaption(
        for draft: Draft
    ) async throws -> String {
        let draftTitle = await MainActor.run { draft.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        let fallbackTitle = await MainActor.run { draft.displayTitle }
        let draftBody = await MainActor.run { draft.caption }
        
        let effectiveTitle = draftTitle.isEmpty ? fallbackTitle : draftTitle
        
        let prompt = """
        Create a short caption for this content.
        Keep it under 220 characters, include a positive call-to-action, and mirror the draft's tone.
        
        Draft title: \(effectiveTitle)
        Draft content:
        \"\"\"
        \(draftBody)
        \"\"\"
        
        Respond with the caption only.
        """
        return try await coreResponseService.generateResponse(for: prompt)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Helpers
    
    private func decodeJSONArray<T: Decodable>(from raw: String) -> T? {
        guard let jsonString = extractJSONArray(from: raw),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    private func extractJSONArray(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "["),
              let end = raw.lastIndex(of: "]") else {
            return nil
        }
        let range = start...end
        return String(raw[range])
    }
}

// MARK: - Suggestion Payload

private struct DraftEnhancementSuggestionPayload: Codable {
    let title: String
    let detail: String
    let replacement: String?
    
    func makeSuggestion() -> DraftEnhancementSuggestion {
        DraftEnhancementSuggestion(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            replacement: replacement?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
