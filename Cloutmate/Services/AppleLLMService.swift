//
//  AppleLLMService.swift
//  Cloutmate
//
//  Hybrid Fallback Strategy: Apple Intelligence / Core ML fallback for document summarization
//  Used when Gemini API is overloaded (503/429/timeout)
//

import Foundation
import NaturalLanguage

actor AppleLLMService {
    static let shared = AppleLLMService()
    
    private let maxContextLength = 4000 // ~4K tokens for Apple LLM
    
    private init() {}
    
    /// Summarizes document text using Apple Intelligence / Core ML
    /// Returns a concise summary optimized for short-context models
    func summarizeDocument(
        text: String,
        fileName: String,
        userPrompt: String? = nil
    ) async throws -> String {
        // Truncate to max context length
        let truncatedText = truncateToMaxLength(text, maxLength: maxContextLength)
        
        // Use Natural Language framework for summarization
        return try await summarizeWithNaturalLanguage(
            text: truncatedText,
            fileName: fileName,
            userPrompt: userPrompt
        )
    }
    
    private func summarizeWithNaturalLanguage(
        text: String,
        fileName: String,
        userPrompt: String? = nil
    ) async throws -> String {
        // Use NLTokenizer for sentence extraction and heuristic summarization
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [String] = []
        let range = text.startIndex..<text.endIndex
        
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let sentence = String(text[tokenRange])
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 20 && !trimmed.isEmpty {
                sentences.append(trimmed)
            }
            return true
        }
        
        guard !sentences.isEmpty else {
            return heuristicSummarization(text: text, fileName: fileName)
        }
        
        // Score sentences by position, length, and keyword density
        let importantKeywords = ["important", "key", "note", "action", "task", "goal", "objective", "summary", "conclusion", "result"]
        
        let scoredSentences = sentences.enumerated().map { index, sentence -> (sentence: String, score: Double) in
            let positionScore = index < 3 ? 1.0 : max(0.3, 1.0 - Double(index) * 0.05)
            let lengthScore = sentence.count > 50 && sentence.count < 200 ? 1.0 : 0.7
            let keywordScore = importantKeywords.contains { sentence.lowercased().contains($0.lowercased()) } ? 1.2 : 1.0
            
            return (sentence, positionScore * lengthScore * keywordScore)
        }
        
        // Select top 3-5 sentences
        let topSentences = scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0.sentence }
        
        let summary = topSentences.joined(separator: ". ") + "."
        
        // Format summary with context
        var formattedSummary = """
        **Summary of \(fileName):**
        
        \(summary)
        """
        
        if let prompt = userPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !prompt.isEmpty {
            formattedSummary += "\n\n(Note: This is a local summary. For detailed analysis or task extraction, please retry when Gemini is available.)"
        }
        
        // Check if text was truncated
        if text.count >= maxContextLength {
            formattedSummary += "\n\n⚠️ Document was truncated for local processing. Full analysis available when Gemini is back online."
        }
        
        return formattedSummary
    }
    
    /// Heuristic summarization using key phrase extraction and sentence ranking
    private func heuristicSummarization(text: String, fileName: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 } // Filter very short sentences
        
        guard !sentences.isEmpty else {
            return "**\(fileName):** Document processed locally. Content appears to be minimal or non-text."
        }
        
        // Score sentences by:
        // 1. Position (first sentences often more important)
        // 2. Length (medium-length sentences are often more informative)
        // 3. Keyword density (sentences with common important words)
        let importantKeywords = ["important", "key", "note", "action", "task", "goal", "objective", "summary", "conclusion", "result"]
        
        let scoredSentences = sentences.enumerated().map { index, sentence -> (sentence: String, score: Double) in
            let positionScore = index < 3 ? 1.0 : max(0.3, 1.0 - Double(index) * 0.05)
            let lengthScore = sentence.count > 50 && sentence.count < 200 ? 1.0 : 0.7
            let keywordScore = importantKeywords.contains { sentence.lowercased().contains($0.lowercased()) } ? 1.2 : 1.0
            
            return (sentence, positionScore * lengthScore * keywordScore)
        }
        
        // Select top 3-5 sentences
        let topSentences = scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0.sentence }
        
        let summary = topSentences.joined(separator: ". ") + "."
        
        return """
        **\(fileName) - Local Summary:**
        
        \(summary)
        
        ⚠️ This is a quick local summary. For full semantic analysis or task extraction, please retry when Gemini is available.
        """
    }
    
    /// Truncates text to maximum length while preserving sentence boundaries
    private func truncateToMaxLength(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        
        // Try to truncate at sentence boundary
        let truncated = String(text.prefix(maxLength))
        if let lastPeriod = truncated.lastIndex(of: "."),
           let lastNewline = truncated.lastIndex(of: "\n") {
            let boundary = max(lastPeriod, lastNewline)
            return String(truncated[..<boundary]) + "..."
        }
        
        return truncated + "..."
    }
}

