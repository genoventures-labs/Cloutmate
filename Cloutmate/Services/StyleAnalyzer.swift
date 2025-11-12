//
//  StyleAnalyzer.swift
//  Cloutmate
//
//  Extracts typing style signals from user messages so Aurora can adapt tone dynamically.
//

import Foundation

struct TypingStyle: Sendable {
    enum CapitalizationPattern: String, Sendable {
        case proper
        case lowercase
        case mixed
    }
    
    let formalityScore: Double
    let capitalizationPattern: CapitalizationPattern
    let punctuationDensity: Double
    let averageSentenceLength: Double
    let emojiUsageFrequency: Double
    let contractionUsage: Double
    let exclamationFrequency: Double
    let questionFrequency: Double
    let energyLevel: Double
    let emojiCount: Int
    let wordCount: Int
    let sampleText: String
    
    static let neutral = TypingStyle(
        formalityScore: 0.5,
        capitalizationPattern: .proper,
        punctuationDensity: 0.4,
        averageSentenceLength: 12.0,
        emojiUsageFrequency: 0.0,
        contractionUsage: 0.2,
        exclamationFrequency: 0.05,
        questionFrequency: 0.05,
        energyLevel: 0.5,
        emojiCount: 0,
        wordCount: 0,
        sampleText: ""
    )
}

enum StyleAnalyzer {
    private static let casualLexicon: Set<String> = [
        "lol", "haha", "omg", "tbh", "idk", "btw", "brb", "gonna", "wanna",
        "kinda", "sorta", "dude", "buddy", "hey", "yo", "sup", "nah",
        "yeah", "yep", "y'all", "luv", "thx", "thanks", "pls", "plz",
        "haha", "hehe", "ya", "xd", "lmao", "rofl"
    ]
    
    private static let formalLexicon: Set<String> = [
        "therefore", "however", "regarding", "furthermore", "appreciate",
        "sincerely", "regards", "objective", "analysis", "deliverable",
        "strategy", "timeline", "accordingly", "coordination", "prioritize"
    ]
    
    private static let contractionPatterns: [String] = [
        "'m", "'re", "'s", "'ve", "'d", "'ll", "n't"
    ]
    
    private static let punctuationCharacters = CharacterSet(charactersIn: "!?,.;:—-…")
    private static let emojiRanges: [ClosedRange<UInt32>] = [
        0x1F300...0x1F5FF, // Misc Symbols and Pictographs
        0x1F600...0x1F64F, // Emoticons
        0x1F680...0x1F6FF, // Transport and Map
        0x2600...0x26FF,   // Misc symbols
        0x2700...0x27BF,   // Dingbats
        0x1F900...0x1F9FF, // Supplemental Symbols and Pictographs
        0x1FA70...0x1FAFF  // Symbols and Pictographs Extended-A
    ]
    private static let textualEmojiPatterns: [String] = [
        "xd",
        ":p", ":-p", ";p", ";-p",
        ":d", ":-d",
        ":)", ":-)", ";)", ";-)",
        ":(", ":-(",
        ":3", ":-3",
        "<3",
        "lol"
    ]
    
    static func analyzeStyle(text: String) -> TypingStyle {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .neutral }
        
        let lowercased = trimmed.lowercased()
        let tokens = tokenize(lowercased)
        let wordCount = tokens.count
        
        let punctuationCount = countPunctuation(in: trimmed)
        let punctuationDensity = wordCount > 0 ? Double(punctuationCount) / Double(wordCount) : 0.0
        
        let sentences = splitSentences(trimmed)
        let averageSentenceLength = averageSentenceWordCount(sentences: sentences, tokens: tokens)
        
        let unicodeEmojiCount = countEmojis(in: trimmed)
        let textualEmojiCount = countTextualEmojis(in: trimmed)
        let emojiCount = unicodeEmojiCount + textualEmojiCount
        let emojiUsageFrequency = wordCount > 0 ? Double(emojiCount) / Double(max(wordCount, 1)) : 0.0
        
        let contractionCount = countContractions(in: lowercased)
        let contractionUsage = wordCount > 0 ? Double(contractionCount) / Double(wordCount) : 0.0
        
        let exclamationCount = trimmed.filter { $0 == "!" }.count
        let questionCount = trimmed.filter { $0 == "?" }.count
        let exclamationFrequency = wordCount > 0 ? Double(exclamationCount) / Double(wordCount) : 0.0
        let questionFrequency = wordCount > 0 ? Double(questionCount) / Double(wordCount) : 0.0
        
        let capitalizationPattern = detectCapitalizationPattern(text: trimmed, tokens: tokens)
        
        let casualHits = tokens.filter { casualLexicon.contains($0) }.count
        let formalHits = tokens.filter { formalLexicon.contains($0) }.count
        
        var formality = 0.6
        formality -= min(0.3, contractionUsage * 1.2)
        formality -= min(0.25, emojiUsageFrequency * 2.0)
        formality -= min(0.2, Double(casualHits) * 0.06)
        formality += min(0.2, Double(formalHits) * 0.05)
        formality -= min(0.1, exclamationFrequency * 1.5)
        formality = clamp(formality)
        
        if capitalizationPattern == .lowercase {
            formality = clamp(formality - 0.15)
        }
        
        let uppercaseRatio = uppercaseTokenRatio(tokens: tokens)
        let energy = computeEnergyLevel(
            punctuationDensity: punctuationDensity,
            exclamationFrequency: exclamationFrequency,
            questionFrequency: questionFrequency,
            averageSentenceLength: averageSentenceLength,
            uppercaseRatio: uppercaseRatio,
            wordCount: wordCount,
            emojiDensity: emojiUsageFrequency
        )
        
        return TypingStyle(
            formalityScore: formality,
            capitalizationPattern: capitalizationPattern,
            punctuationDensity: clamp(punctuationDensity),
            averageSentenceLength: averageSentenceLength,
            emojiUsageFrequency: clamp(emojiUsageFrequency),
            contractionUsage: clamp(contractionUsage),
            exclamationFrequency: clamp(exclamationFrequency),
            questionFrequency: clamp(questionFrequency),
            energyLevel: clamp(energy),
            emojiCount: emojiCount,
            wordCount: wordCount,
            sampleText: trimmed
        )
    }
    
    private static func tokenize(_ text: String) -> [String] {
        return text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
    
    private static func countPunctuation(in text: String) -> Int {
        return text.unicodeScalars.reduce(into: 0) { count, scalar in
            if punctuationCharacters.contains(scalar) {
                count += 1
            }
        }
    }
    
    private static func splitSentences(_ text: String) -> [String] {
        let delimiters = CharacterSet(charactersIn: ".!?\n")
        return text
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    private static func averageSentenceWordCount(sentences: [String], tokens: [String]) -> Double {
        guard !sentences.isEmpty else { return Double(tokens.count) }
        let counts = sentences.map { sentence -> Int in
            sentence
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .count
        }
        let total = counts.reduce(0, +)
        return counts.isEmpty ? Double(tokens.count) : Double(total) / Double(counts.count)
    }
    
    private static func countEmojis(in text: String) -> Int {
        return text.unicodeScalars.reduce(into: 0) { count, scalar in
            let value = scalar.value
            if emojiRanges.contains(where: { $0.contains(value) }) {
                count += 1
            }
        }
    }
    
    private static func countTextualEmojis(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let normalized = text.lowercased()
        var total = 0
        for pattern in textualEmojiPatterns {
            let trimmedPattern = pattern.replacingOccurrences(of: " ", with: "")
            if trimmedPattern.isEmpty { continue }
            total += max(0, normalized.components(separatedBy: trimmedPattern).count - 1)
        }
        return total
    }
    
    private static func countContractions(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        var result = 0
        for pattern in contractionPatterns {
            let occurrences = text.components(separatedBy: pattern).count - 1
            result += max(0, occurrences)
        }
        return result
    }
    
    private static func detectCapitalizationPattern(text: String, tokens: [String]) -> TypingStyle.CapitalizationPattern {
        guard !tokens.isEmpty else { return .proper }
        
        if text == text.lowercased() {
            return .lowercase
        }
        
        let uppercaseTokens = tokens.filter { token in
            guard let first = token.first else { return false }
            let isUpper = String(first).uppercased() == String(first) && String(first).lowercased() != String(first)
            let othersLower = token.dropFirst().lowercased() == token.dropFirst()
            return isUpper && othersLower
        }
        let ratio = Double(uppercaseTokens.count) / Double(tokens.count)
        if ratio > 0.6 {
            return .proper
        }
        return .mixed
    }
    
    private static func uppercaseTokenRatio(tokens: [String]) -> Double {
        guard !tokens.isEmpty else { return 0.0 }
        let uppercaseTokens = tokens.filter { token in
            guard let first = token.first else { return false }
            let hasUppercase = String(first).uppercased() == String(first) && String(first).lowercased() != String(first)
            return hasUppercase && token.dropFirst().contains { char in
                let letter = String(char)
                return letter.uppercased() == letter && letter.lowercased() != letter
            }
        }
        return Double(uppercaseTokens.count) / Double(tokens.count)
    }
    
    private static func computeEnergyLevel(
        punctuationDensity: Double,
        exclamationFrequency: Double,
        questionFrequency: Double,
        averageSentenceLength: Double,
        uppercaseRatio: Double,
        wordCount: Int,
        emojiDensity: Double
    ) -> Double {
        let punctuationSignal = min(1.0, (punctuationDensity * 0.7) + (exclamationFrequency * 3.0) + (questionFrequency * 2.5))
        let sentenceLengthSignal = 1.0 - min(1.0, averageSentenceLength / 25.0)
        let uppercaseSignal = min(1.0, uppercaseRatio * 1.5)
        let emojiSignal = min(1.0, emojiDensity * 4.0)
        var energy = (punctuationSignal * 0.4) + (sentenceLengthSignal * 0.32) + (uppercaseSignal * 0.16) + (emojiSignal * 0.12)
        if wordCount < 6 {
            energy = (energy * 0.6) + 0.2
        }
        return clamp(energy)
    }
    
    static func primaryTopic(from text: String) -> String? {
        let tokens = tokenize(text.lowercased())
        guard !tokens.isEmpty else { return nil }
        let stopWords: Set<String> = [
            "the", "and", "with", "this", "that", "have", "about", "there", "their", "would",
            "could", "should", "might", "been", "from", "into", "while", "which", "where",
            "those", "these", "thing", "stuff", "maybe", "really", "just", "still", "yeah",
            "okay", "gonna", "wanna", "like", "you", "your", "they", "them", "some", "what",
            "when", "need", "want", "also"
        ]
        let filtered = tokens.filter { token in
            guard token.count > 2 else { return false }
            return !stopWords.contains(token)
        }
        guard !filtered.isEmpty else { return nil }
        let counts = Dictionary(grouping: filtered, by: { $0 }).mapValues { $0.count }
        guard let top = counts.sorted(by: { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.count > rhs.key.count
            }
            return lhs.value > rhs.value
        }).first else { return nil }
        return top.key.capitalized
    }
    
    private static func clamp(_ value: Double) -> Double {
        return min(max(value, 0.0), 1.0)
    }
}

