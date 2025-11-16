//
//  JournalAIService.swift
//  Cloutmate
//
//  AI Service for Journal Entries
//

import Foundation

actor JournalAIService {
    static let shared = JournalAIService()
    private let coreResponseService = CoreResponseService.shared
    
    private init() {}
    
    // MARK: - Context-Aware Prompt Suggestions
    
    func generateContextualPrompt(
        entryType: JournalEntryType,
        recentEntries: [Journal]? = nil
    ) async -> String {
        let timeOfDay = getTimeOfDay()
        let prompt = buildContextualPrompt(
            for: entryType,
            timeOfDay: timeOfDay,
            recentEntries: recentEntries ?? []
        )
        return prompt
    }
    
    // MARK: - Content Generation
    
    func generateJournalContent(
        from prompt: String,
        entryType: JournalEntryType,
        mood: JournalMood? = nil,
        context: String = ""
    ) async throws -> String {
        let systemPrompt = buildSystemPrompt(for: entryType, context: context)
        
        // Determine tone from mood and entry type
        let tone = mood.map { AuroraToneKit.tone(for: $0, entryType: entryType) } ?? .reflective
        
        do {
            let fullPrompt = "\(systemPrompt)\n\nUser prompt: \(prompt)\n\nGenerate journal content:"
            let response = try await coreResponseService.generateResponse(
                for: fullPrompt,
                context: context,
                toneContext: tone
            )
            return response
        } catch {
            return "Unable to generate content at this time."
        }
    }
    
    // MARK: - Entry Analysis
    
    func analyzeJournalEntries(_ entries: [Journal]) async throws -> String {
        guard !entries.isEmpty else {
            return "No entries to analyze."
        }
        
        let entriesText = entries.prefix(20).map { entry in
            """
            Title: \(entry.title)
            Type: \(entry.entryType)
            Mood: \(entry.mood)
            Content: \(entry.content.prefix(200))
            Date: \(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
            """
        }.joined(separator: "\n\n")
        
        let prompt = """
        Analyze these journal entries and provide insights on:
        1. Patterns or themes that emerge
        2. Emotional trends (from mood selections)
        3. Entry type distribution
        4. Notable observations or recommendations
        
        Entries:
        \(entriesText)
        
        Provide a concise analysis in 3-5 bullet points:
        """
        
        // Use reflective tone for journal analysis
        let tone = AuroraTone.reflective
        
        do {
            let response = try await coreResponseService.generateResponse(
                for: prompt,
                context: "",
                toneContext: tone
            )
            return response
        } catch {
            return "Unable to analyze entries at this time."
        }
    }
    
    // MARK: - Reflection Prompts
    
    func suggestReflectionPrompt(for mood: JournalMood?) async -> String {
        let timeOfDay = getTimeOfDay()
        let prompts = reflectionPromptsFor(mood: mood, timeOfDay: timeOfDay)
        return prompts.randomElement() ?? "Write about what's on your mind today."
    }
    
    // MARK: - Content Idea Generation
    
    func generateContentIdeas(linkedTo areaOrProject: String? = nil) async throws -> String {
        let context = areaOrProject.map { " for \($0)" } ?? ""
        
        let prompt = """
        Generate 5 creative content ideas\(context). Each idea should be:
        - Specific and actionable
        - Engaging and authentic
        - Ready to develop into social media content
        
        Format as a numbered list (1. 2. 3. etc.):
        """
        
        // Use creative flow tone for content ideas
        let tone = AuroraTone.creativeFlow
        
        do {
            let response = try await coreResponseService.generateResponse(
                for: prompt,
                context: "",
                toneContext: tone
            )
            return response
        } catch {
            return "Unable to generate ideas at this time."
        }
    }
    
    // MARK: - Entry Summaries
    
    func summarizeEntries(_ entries: [Journal], count: Int = 10) async throws -> String {
        let recentEntries = Array(entries.prefix(count))
        let entriesText = recentEntries.map { entry in
            """
            \(entry.entryDate.formatted(date: .abbreviated, time: .omitted)): \(entry.title)
            \(entry.content.prefix(100))
            """
        }.joined(separator: "\n\n")
        
        let prompt = """
        Summarize these journal entries in 2-3 sentences, highlighting key themes, moments, and insights.
        
        Entries:
        \(entriesText)
        
        Summary:
        """
        
        // Use reflective tone for summaries
        let tone = AuroraTone.reflective
        
        do {
            let response = try await coreResponseService.generateResponse(
                for: prompt,
                context: "",
                toneContext: tone
            )
            return response
        } catch {
            return "Unable to summarize entries at this time."
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
    
    private func buildContextualPrompt(
        for entryType: JournalEntryType,
        timeOfDay: String,
        recentEntries: [Journal]
    ) -> String {
        switch entryType {
        case .reflection:
            return "Write about something you learned or experienced today."
        case .contentIdea:
            return "Brainstorm content ideas that would resonate with your audience."
        case .projectTracker:
            return "Document your progress and insights from recent work."
        }
    }
    
    private func buildSystemPrompt(for entryType: JournalEntryType, context: String) -> String {
        var prompt = "You are a helpful AI assistant helping with journal entries. "
        
        switch entryType {
        case .reflection:
            prompt += "Generate authentic, introspective personal reflection content. Be thoughtful and encouraging."
        case .contentIdea:
            prompt += "Generate creative, engaging content ideas for social media. Focus on authenticity and audience engagement."
        case .projectTracker:
            prompt += "Help document project progress and insights. Be specific and actionable."
        }
        
        if !context.isEmpty {
            prompt += "\n\nContext: \(context)"
        }
        
        return prompt
    }
    
    private func reflectionPromptsFor(mood: JournalMood?, timeOfDay: String) -> [String] {
        switch mood {
        case .grateful:
            return [
                "What are you grateful for today?",
                "Write about something or someone that made you smile today.",
                "What small moment from today brought you joy?"
            ]
        case .motivated:
            return [
                "What goal are you working towards today?",
                "What progress did you make today?",
                "What's driving you forward right now?"
            ]
        case .creative:
            return [
                "What creative idea has been on your mind?",
                "Describe something inspiring you encountered today.",
                "What would you create if you had all the resources?"
            ]
        case .contemplative:
            return [
                "What insight did you gain today?",
                "What question have you been pondering?",
                "What lesson did you learn recently?"
            ]
        default:
            return [
                "What's on your mind today?",
                "Write about your day.",
                "What stood out to you today?"
            ]
        }
    }
}

