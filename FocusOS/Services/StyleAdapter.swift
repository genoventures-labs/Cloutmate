//
//  StyleAdapter.swift
//  FocusOS
//
//  Converts typing style metrics into natural-language instructions for Aurora.
//

import Foundation

enum StyleAdapter {
    static func instructions(
        currentStyle: TypingStyle?,
        persistentProfile: UserPreferences?
    ) -> String? {
        guard currentStyle != nil || persistentProfile != nil else { return nil }
        let style = currentStyle ?? TypingStyle.neutral
        let updates = persistentProfile?.styleUpdateCount ?? 0
        let hasHistory = (persistentProfile != nil) && updates > 0
        var persistentWeight: Double = hasHistory ? 0.5 : 0.0
        
        if hasHistory, let profile = persistentProfile {
            let sampleWordCount = max(0, style.wordCount)
            let sampleConfidence = min(1.0, Double(sampleWordCount) / 16.0)
            let reliabilityGuard = 0.6 + (0.4 * (1.0 - sampleConfidence))
            persistentWeight *= reliabilityGuard
            
            let persistentFormality = clamp(profile.formalityScore, min: 0.0, max: 1.0)
            let persistentEnergy = clamp(profile.energyLevel, min: 0.0, max: 1.0)
            let formalityGap = persistentFormality - clamp(style.formalityScore, min: 0.0, max: 1.0)
            
            if formalityGap > 0.12 {
                let adjustment = min(0.25, formalityGap * (0.5 + sampleConfidence * 0.3))
                persistentWeight -= adjustment
            }
            
            if style.formalityScore < 0.35 {
                let casualBias = 0.35 - style.formalityScore
                persistentWeight -= min(0.15, casualBias * 0.45)
            }
            
            let energyGap = abs(persistentEnergy - clamp(style.energyLevel, min: 0.0, max: 1.0))
            if energyGap > 0.25 {
                persistentWeight -= min(0.1, energyGap * 0.25)
            }
        }
        
        persistentWeight = clamp(persistentWeight, min: 0.18, max: 0.6)
        let currentWeight = clamp(1.0 - persistentWeight, min: 0.4, max: 0.82)
        
        let formality = weightedAverage(
            current: style.formalityScore,
            persistent: persistentProfile?.formalityScore,
            currentWeight: currentWeight,
            persistentWeight: persistentWeight
        )
        let punctuationDensity = weightedAverage(
            current: style.punctuationDensity,
            persistent: persistentProfile?.punctuationDensity,
            currentWeight: currentWeight,
            persistentWeight: persistentWeight
        )
        let emojiFrequency = weightedAverage(
            current: style.emojiUsageFrequency,
            persistent: persistentProfile?.emojiUsageFrequency,
            currentWeight: currentWeight,
            persistentWeight: persistentWeight
        )
        let contractionUsage = weightedAverage(
            current: style.contractionUsage,
            persistent: persistentProfile?.contractionUsageFrequency,
            currentWeight: currentWeight,
            persistentWeight: persistentWeight
        )
        let exclamationFrequency = weightedAverage(
            current: style.exclamationFrequency,
            persistent: persistentProfile?.exclamationFrequency,
            currentWeight: currentWeight,
            persistentWeight: persistentWeight
        )
        let sentenceLength = weightedAverage(
            current: normalizeSentenceLength(style.averageSentenceLength),
            persistent: normalizeSentenceLength(persistentProfile?.averageSentenceLength ?? style.averageSentenceLength),
            currentWeight: currentWeight,
            persistentWeight: persistentWeight
        )
        let energyLevel = weightedAverage(
            current: style.energyLevel,
            persistent: persistentProfile?.energyLevel,
            currentWeight: currentWeight,
            persistentWeight: persistentWeight
        )

        let capitalization = resolveCapitalization(
            current: style.capitalizationPattern,
            persistent: persistentProfile?.capitalizationPattern
        )

        var directives: [String] = []

        directives.append(toneDirective(for: formality, contractions: contractionUsage))

        let sampleText = style.sampleText.lowercased()
        let technicalKeywords = [
            "build", "compile", "error", "bug", "xcode", "swiftui", "debug", "crash",
            "syntax", "deploy", "git", "code", "function", "class", "api", "framework",
            "module", "package", "library", "schema", "database"
        ]
        let hasTechnicalContext = technicalKeywords.contains { keyword in
            sampleText.contains(keyword)
        }
        let shouldUseAbbreviations = formality < 0.5 && !hasTechnicalContext

        switch capitalization {
        case .lowercase:
            directives.append("Keep lowercase casing where the user does, avoiding overly formal capitalization.")
        case .proper:
            directives.append("Use proper capitalization and sentence openings to keep things tidy but still warm.")
        case .mixed:
            directives.append("Blend casual and proper casing the way the user does; stay relaxed but readable.")
        }

        if sentenceLength < 0.4 {
            directives.append("Favor short, quick sentences so it feels breezy.")
        } else if sentenceLength > 0.7 {
            directives.append("Let sentences run a bit longer so the pacing feels thoughtful.")
        }

        if punctuationDensity > 0.5 || exclamationFrequency > 0.08 {
            directives.append("Use lively punctuation (like ! or ?) when the energy calls for it, without overdoing it.")
        } else {
            directives.append("Keep punctuation light and let the cadence stay calm.")
        }

        if emojiFrequency > 0.07 {
            directives.append("Sprinkle in emoji occasionally (about one per message) when it enhances the vibe.")
        }

        if contractionUsage > 0.18 {
            directives.append("Lean on natural contractions to keep it sounding human and effortless.")
        } else if contractionUsage < 0.08 {
            directives.append("Stay mostly free of contractions so it reads polished.")
        }

        if shouldUseAbbreviations {
            directives.append("Use casual abbreviations when it fits (btw, rn, imo, lmk, ngl, tbh) and quick time shortcuts like mins or tm.")
        } else if hasTechnicalContext {
            directives.append("Skip casual abbreviations so the technical explanation stays clear.")
        }

        if energyLevel < 0.4 {
            directives.append("The user sounds low on energy, so respond within roughly fifteen percent of that vibe: slow the pacing, soften your language, and skip exclamation marks unless they ask for hype.")
        } else if energyLevel > 0.7 {
            directives.append("The user feels fired up, so stay within roughly fifteen percent of that energy by using brighter language and a livelier rhythm, adding exclamations when it feels natural.")
        }

        let isCasual = formality < 0.55
        if isCasual {
            directives.append("Let some sentences stay fragmentary for emphasis (like 'Totally.' or 'Makes sense.') and think out loud a bit when processing.")
            directives.append("Use connectors like so, anyway, also, plus to keep the flow chatty, and rely on parentheses for side thoughts instead of em dashes.")
        } else if hasTechnicalContext {
            directives.append("Stick with clear, complete sentences and add structured formatting (lists, inline code) when detailing steps or errors.")
        }

        directives.append("Never use em dashes; lean on commas or parentheses for asides instead.")

        let instruction = directives.joined(separator: " ")
        return instruction.isEmpty ? nil : instruction
    }

    private static func weightedAverage(
        current: Double,
        persistent: Double?,
        currentWeight: Double,
        persistentWeight: Double
    ) -> Double {
        guard let persistent else { return current }
        let totalWeight = currentWeight + persistentWeight
        guard totalWeight > 0 else { return current }
        return (current * currentWeight + persistent * persistentWeight) / totalWeight
    }

    private static func toneDirective(for formality: Double, contractions: Double) -> String {
        if formality < 0.4 {
            if contractions > 0.18 {
                return "Match the user's relaxed, conversational tone, sounding easygoing and friendly."
            }
            return "Keep the tone relaxed and informal, but still coherent and supportive."
        } else if formality < 0.65 {
            return "Use a balanced tone: warm, collaborative, and not overly formal."
        } else {
            return "Keep the delivery polished and professional while staying personable."
        }
    }

    private static func normalizeSentenceLength(_ length: Double) -> Double {
        let clamped = min(max(length, 1.0), 60.0)
        return (clamped - 1.0) / (60.0 - 1.0)
    }
    
    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        return min(max(value, minValue), maxValue)
    }

    private static func resolveCapitalization(
        current: TypingStyle.CapitalizationPattern,
        persistent: String?
    ) -> TypingStyle.CapitalizationPattern {
        if current != .mixed {
            return current
        }
        guard let persistent else { return .mixed }
        return TypingStyle.CapitalizationPattern(rawValue: persistent) ?? .mixed
    }
}

