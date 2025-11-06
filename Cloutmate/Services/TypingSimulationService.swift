//
//  TypingSimulationService.swift
//  Cloutmate
//
//  Simulates human-like typing patterns for Aurora's responses
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TypingSimulationService {
    static let shared = TypingSimulationService()
    
    // Typing speed profiles (words per minute)
    private enum TypingSpeed {
        case slow      // 30 WPM - complex thoughts
        case normal    // 60 WPM - standard responses
        case fast      // 90 WPM - quick acknowledgments
        case veryFast  // 120 WPM - enthusiastic responses
        
        var wordsPerMinute: Double {
            switch self {
            case .slow: return 30
            case .normal: return 60
            case .fast: return 90
            case .veryFast: return 120
            }
        }
        
        var millisecondsPerWord: UInt64 {
            let wordsPerSecond = wordsPerMinute / 60.0
            let secondsPerWord = 1.0 / wordsPerSecond
            return UInt64(secondsPerWord * 1_000_000_000) // Convert to nanoseconds
        }
    }
    
    // Determine typing speed based on message complexity
    private func typingSpeed(for message: String) -> TypingSpeed {
        let wordCount = message.split(separator: " ").count
        let hasComplexPunctuation = message.contains("—") || message.contains("...") || message.contains("?")
        let isLong = wordCount > 100
        
        if wordCount < 10 {
            return .veryFast
        } else if wordCount < 30 && !hasComplexPunctuation {
            return .fast
        } else if isLong || hasComplexPunctuation {
            return .slow
        } else {
            return .normal
        }
    }
    
    // Calculate pause durations based on punctuation
    private func pauseDuration(after character: Character) -> UInt64 {
        switch character {
        case ".", "!", "?":
            return 800_000_000 // 800ms pause after sentence endings
        case ",", ";", ":":
            return 300_000_000 // 300ms pause after commas
        case "\n":
            return 500_000_000 // 500ms pause after line breaks
        default:
            return 0
        }
    }
    
    // Simulate backspace/typo correction (10% chance on longer words)
    private func shouldSimulateCorrection(word: String) -> Bool {
        guard word.count > 6 else { return false }
        return Double.random(in: 0...1) < 0.1 // 10% chance
    }
    
    /// Stream a message word by word with natural typing patterns
    func streamMessage(
        _ message: String,
        onWord: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) async {
        let speed = typingSpeed(for: message)
        let words = message.split(separator: " ").map { String($0) }
        var displayedText = ""
        
        for (index, word) in words.enumerated() {
            // Check if we should simulate a typo correction
            if shouldSimulateCorrection(word: word) && index > 0 {
                // Show backspace effect
                let partialWord = String(word.prefix(word.count / 2))
                onWord(partialWord)
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms pause
                
                // Show corrected word
                onWord(word)
                try? await Task.sleep(nanoseconds: speed.millisecondsPerWord)
            } else {
                // Normal word display
                displayedText += (displayedText.isEmpty ? "" : " ") + word
                onWord(displayedText)
                
                // Natural pause after word
                try? await Task.sleep(nanoseconds: speed.millisecondsPerWord)
            }
            
            // Add punctuation-based pauses
            if index < words.count - 1 {
                let nextWord = words[index + 1]
                if let lastChar = displayedText.last {
                    let pause = pauseDuration(after: lastChar)
                    if pause > 0 {
                        try? await Task.sleep(nanoseconds: pause)
                    }
                }
            }
        }
        
        // Final pause before completion
        try? await Task.sleep(nanoseconds: 200_000_000)
        onComplete()
    }
    
    /// Stream a message in chunks (for longer messages)
    func streamMessageChunked(
        _ message: String,
        chunkSize: Int = 5, // words per chunk
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) async {
        let speed = typingSpeed(for: message)
        let words = message.split(separator: " ").map { String($0) }
        var displayedText = ""
        
        for chunkStart in stride(from: 0, to: words.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, words.count)
            let chunk = words[chunkStart..<chunkEnd]
            
            let chunkText = chunk.joined(separator: " ")
            displayedText += (displayedText.isEmpty ? "" : " ") + chunkText
            onChunk(displayedText)
            
            // Pause between chunks
            let chunkPauseDuration = speed.millisecondsPerWord * UInt64(chunk.count)
            try? await Task.sleep(nanoseconds: chunkPauseDuration)
            
            // Additional pause if this chunk ends with punctuation
            if let lastChar = chunkText.last {
                let punctuationPause = pauseDuration(after: lastChar)
                if punctuationPause > 0 {
                    try? await Task.sleep(nanoseconds: punctuationPause)
                }
            }
        }
        
        onComplete()
    }
    
    /// Estimate typing duration for a message (for UI planning)
    func estimateTypingDuration(for message: String) -> TimeInterval {
        let speed = typingSpeed(for: message)
        let words = message.split(separator: " ").count
        let baseTime = Double(words) * (Double(speed.millisecondsPerWord) / 1_000_000_000.0)
        
        // Add pause time for punctuation
        let punctuationCount = message.filter { ",.;:!?".contains($0) }.count
        let pauseTime = Double(punctuationCount) * 0.3 // 300ms per punctuation
        
        return baseTime + pauseTime
    }
}

