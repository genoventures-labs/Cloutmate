//
//  OfflineSummarizationService.swift
//  Cloutmate
//
//  Tertiary fallback: Heuristic summarization when both Gemini and Apple LLM fail
//  Uses text extraction, key phrase clustering, and sentence ranking
//

import Foundation
import NaturalLanguage

actor OfflineSummarizationService {
    static let shared = OfflineSummarizationService()
    
    private init() {}
    
    /// Generates a summary using heuristic methods (no AI required)
    func generateSummary(
        text: String,
        fileName: String,
        userPrompt: String? = nil
    ) -> String {
        let sentences = extractSentences(from: text)
        guard !sentences.isEmpty else {
            return "**\(fileName):** Document processed. Content appears minimal or non-text."
        }
        
        // Extract key phrases
        let keyPhrases = extractKeyPhrases(from: text)
        
        // Score and rank sentences
        let rankedSentences = rankSentences(
            sentences: sentences,
            keyPhrases: keyPhrases,
            userPrompt: userPrompt
        )
        
        // Select top sentences for summary
        let summaryCount = min(5, max(2, sentences.count / 4))
        let topSentences = Array(rankedSentences.prefix(summaryCount))
        
        // Build summary
        var summary = "**\(fileName) - Quick Summary:**\n\n"
        summary += topSentences.map { $0.sentence }.joined(separator: ". ") + ".\n\n"
        
        if !keyPhrases.isEmpty {
            summary += "**Key topics:** \(keyPhrases.prefix(5).joined(separator: ", "))\n\n"
        }
        
        summary += "⚠️ This is an offline summary. For full AI analysis, please retry when services are available."
        
        return summary
    }
    
    // MARK: - Private Helpers
    
    private func extractSentences(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [String] = []
        let range = text.startIndex..<text.endIndex
        
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let sentence = String(text[tokenRange])
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            // Filter out very short sentences (likely artifacts)
            if trimmed.count > 20 && !trimmed.isEmpty {
                sentences.append(trimmed)
            }
            return true
        }
        
        return sentences.isEmpty ? [text] : sentences
    }
    
    private func extractKeyPhrases(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var nounPhrases: [String] = []
        var currentPhrase: [String] = []
        
        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            if tag == .noun || tag == .adjective {
                let word = String(text[tokenRange]).lowercased()
                currentPhrase.append(word)
            } else {
                if currentPhrase.count >= 2 {
                    nounPhrases.append(currentPhrase.joined(separator: " "))
                }
                currentPhrase.removeAll()
            }
            
            return true
        }
        
        // Add final phrase if exists
        if currentPhrase.count >= 2 {
            nounPhrases.append(currentPhrase.joined(separator: " "))
        }
        
        // Count frequency and return top phrases
        let phraseCounts = Dictionary(grouping: nounPhrases, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(phraseCounts.prefix(10).map { $0.key })
    }
    
    private func rankSentences(
        sentences: [String],
        keyPhrases: [String],
        userPrompt: String?
    ) -> [(sentence: String, score: Double)] {
        return sentences.enumerated().map { index, sentence -> (sentence: String, score: Double) in
            var score = 0.0
            
            // Position score (first sentences are often important)
            if index < 3 {
                score += 2.0
            } else if index < 10 {
                score += 1.0
            } else {
                score += 0.5
            }
            
            // Length score (medium-length sentences are often more informative)
            let length = sentence.count
            if length > 50 && length < 200 {
                score += 1.0
            } else if length > 200 {
                score += 0.5 // Very long sentences might be less clear
            }
            
            // Key phrase match score
            let lowerSentence = sentence.lowercased()
            let matchingPhrases = keyPhrases.filter { lowerSentence.contains($0.lowercased()) }
            score += Double(matchingPhrases.count) * 0.5
            
            // User prompt relevance (if provided)
            if let prompt = userPrompt?.lowercased() {
                let promptWords = prompt.components(separatedBy: .whitespacesAndNewlines)
                let matchingWords = promptWords.filter { lowerSentence.contains($0.lowercased()) }
                score += Double(matchingWords.count) * 1.0
            }
            
            // Important keywords boost
            let importantKeywords = ["important", "key", "note", "action", "task", "goal", "objective", "summary", "conclusion", "result", "decision"]
            if importantKeywords.contains(where: { lowerSentence.contains($0.lowercased()) }) {
                score += 1.0
            }
            
            return (sentence, score)
        }
    }
}

