//
//  EmotionAnalyzer.swift
//  Cloutmate
//
//  Lightweight emotional tone heuristics for Aurora's recall layer.
//

import Foundation

enum EmotionTone: String, CaseIterable, Sendable {
    case joyful, excited, calm, focused, grateful, hopeful, empathetic, reflective, relieved
    case frustrated, overwhelmed, confused, disappointed, determined, neutral
    
    var valence: Double {
        switch self {
        case .joyful, .excited, .calm, .focused, .grateful, .hopeful, .empathetic, .relieved, .determined:
            return 1.0
        case .frustrated, .overwhelmed, .confused, .disappointed:
            return -1.0
        case .reflective, .neutral:
            return 0.0
        }
    }
}

struct EmotionalSnapshot: Sendable {
    let primaryEmotion: EmotionTone
    let secondaryEmotion: EmotionTone?
    let valence: Double // -1.0 ... 1.0
    let intensity: Double // 0.0 ... 1.0
    let keywords: [String]
    
    static let neutral = EmotionalSnapshot(
        primaryEmotion: .neutral,
        secondaryEmotion: nil,
        valence: 0.0,
        intensity: 0.0,
        keywords: []
    )
}

enum EmotionAnalyzer {
    private static let phraseLexicon: [EmotionTone: [String]] = [
        .joyful: ["so happy", "feels great", "loving this", "made my day"],
        .excited: ["can't wait", "super excited", "hyped up", "pumped for"],
        .calm: ["all good", "feels calm", "nice and easy", "steady going"],
        .focused: ["locked in", "dialed in", "heads down", "laser focus"],
        .grateful: ["thank you", "appreciate it", "grateful for", "thanks so much"],
        .hopeful: ["feeling hopeful", "looks promising", "optimistic about"],
        .empathetic: ["here for you", "got your back", "understand how", "with you"],
        .relieved: ["huge relief", "glad that's done", "finally finished", "breathing again"],
        .determined: ["let's crush", "make it happen", "keep pushing", "stay on track"],
        .frustrated: ["so annoyed", "really frustrated", "driving me crazy", "ugh this"],
        .overwhelmed: ["too much", "so stressed", "burned out", "at capacity"],
        .confused: ["not sure", "don't get it", "unclear about", "lost on"],
        .disappointed: ["pretty bummed", "let down", "not great", "sad about"],
        .reflective: ["learned that", "noticing that", "looking back", "realized"],
        .neutral: []
    ]
    
    private static let singleWordLexicon: [EmotionTone: [String]] = [
        .joyful: ["happy", "joy", "great", "love", "awesome", "yay", "glad", "delight"],
        .excited: ["excited", "thrilled", "stoked", "pumped", "energized", "buzzing"],
        .calm: ["calm", "steady", "chill", "ok", "fine", "balanced"],
        .focused: ["focused", "productive", "progress", "aligned", "intentional"],
        .grateful: ["grateful", "thankful", "appreciate", "thanks", "gratitude"],
        .hopeful: ["hopeful", "optimistic", "positive", "bright"],
        .empathetic: ["supportive", "caring", "gentle", "warm"],
        .relieved: ["relieved", "phew", "finally", "whew"],
        .determined: ["determined", "driven", "motivated", "committed"],
        .frustrated: ["frustrated", "annoyed", "irritated", "mad", "angry", "fed", "ugh"],
        .overwhelmed: ["overwhelmed", "stressed", "anxious", "tired", "exhausted", "burned"],
        .confused: ["confused", "uncertain", "puzzled", "lost", "unsure"],
        .disappointed: ["disappointed", "sad", "bummed", "upset"],
        .reflective: ["reflective", "curious", "pondering", "considering", "insight"],
        .neutral: ["okay", "alright", "fine"]
    ]
    
    private static let positiveTones: Set<EmotionTone> = [.joyful, .excited, .calm, .focused, .grateful, .hopeful, .empathetic, .relieved, .determined]
    private static let negativeTones: Set<EmotionTone> = [.frustrated, .overwhelmed, .confused, .disappointed]
    
    static func analyzeTone(text: String) -> EmotionalSnapshot {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .neutral }
        
        let lower = trimmed.lowercased()
        var scores: [EmotionTone: Double] = [:]
        var matchedKeywords: [String] = []
        
        for (tone, phrases) in phraseLexicon {
            for phrase in phrases where lower.contains(phrase) {
                scores[tone, default: 0.0] += 2.5
                matchedKeywords.append(phrase)
            }
        }
        
        let tokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let tokenSet = Set(tokens)
        for (tone, words) in singleWordLexicon {
            for word in words where tokenSet.contains(word) {
                scores[tone, default: 0.0] += 1.0
                matchedKeywords.append(word)
            }
        }
        
        // punctuation cues
        let exclamations = Double(trimmed.filter { $0 == "!" }.count)
        let questions = Double(trimmed.filter { $0 == "?" }.count)
        if exclamations > 0 {
            scores[.excited, default: 0.0] += exclamations * 0.4
        }
        if questions > 0 {
            scores[.confused, default: 0.0] += questions * 0.3
        }
        
        // uppercase weighting
        let uppercaseCount = trimmed.filter { $0.isUppercase }.count
        if uppercaseCount > 4 {
            scores[.determined, default: 0.0] += 0.3
        }
        
        let sorted = scores.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value > rhs.value
        }
        
        guard let primaryPair = sorted.first, primaryPair.value > 0 else {
            return .neutral
        }
        
        let primary = primaryPair.key
        let secondary = sorted.dropFirst().first(where: { $0.value > 0.2 })?.key
        
        let positiveScore = sorted.filter { positiveTones.contains($0.key) }.reduce(0.0) { $0 + $1.value }
        let negativeScore = sorted.filter { negativeTones.contains($0.key) }.reduce(0.0) { $0 + $1.value }
        let totalScore = positiveScore + negativeScore
        
        let valence: Double
        if totalScore == 0 {
            valence = primary.valence
        } else {
            valence = max(-1.0, min(1.0, (positiveScore - negativeScore) / max(1.0, totalScore)))
        }
        
        let baseIntensity = min(1.0, (positiveScore + negativeScore) / 6.0)
        let punctuationBoost = min(0.3, (exclamations * 0.1) + (questions * 0.05))
        let intensity = max(0.1, min(1.0, baseIntensity + punctuationBoost))
        
        let uniqueKeywords = Array(NSOrderedSet(array: matchedKeywords)).compactMap { $0 as? String }
        
        return EmotionalSnapshot(
            primaryEmotion: primary,
            secondaryEmotion: secondary,
            valence: valence,
            intensity: intensity,
            keywords: uniqueKeywords
        )
    }
    
    nonisolated static func aggregate(snippets: [RecallSnippet]) -> (emotion: String, score: Double)? {
        let meaningful = snippets.filter { !$0.emotion.isEmpty }
        guard !meaningful.isEmpty else { return nil }
        
        var emotionWeights: [String: Double] = [:]
        var scoreTotal: Double = 0
        for snippet in meaningful {
            emotionWeights[snippet.emotion, default: 0] += abs(snippet.emotionScore)
            scoreTotal += snippet.emotionScore
        }
        
        let dominant = emotionWeights.max { $0.value < $1.value }?.key ?? "neutral"
        let average = scoreTotal / Double(meaningful.count)
        return (emotion: dominant, score: average)
    }
}
