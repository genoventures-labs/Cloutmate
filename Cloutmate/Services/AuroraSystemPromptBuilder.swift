//
//  AuroraSystemPromptBuilder.swift
//  Cloutmate
//
//  Centralized system prompt builder with versioning and modular sections
//

import Foundation

actor AuroraSystemPromptBuilder {
    static let shared = AuroraSystemPromptBuilder()
    
    private let versionsFileName = "aurora_prompt_versions"
    private var versions: AuroraPromptVersions?
    private var currentVersionId: String = "v1.0.0"
    
    private init() {
        loadVersions()
    }
    
    // MARK: - Version Management
    
    private func loadVersions() {
        guard let url = getVersionsFileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AuroraPromptVersions.self, from: data) else {
            // Initialize with empty versions
            versions = AuroraPromptVersions(currentVersion: currentVersionId, versions: [:])
            print("[AuroraSystemPromptBuilder] No existing versions file, starting fresh")
            return
        }
        
        versions = decoded
        currentVersionId = decoded.currentVersion
        print("[AuroraSystemPromptBuilder] Loaded \(decoded.versions.count) prompt versions, current: \(currentVersionId)")
    }
    
    private func saveVersions() {
        guard let versions = versions else { return }
        
        guard let url = getVersionsFileURL(),
              let data = try? JSONEncoder().encode(versions) else {
            print("[AuroraSystemPromptBuilder] Failed to encode versions")
            return
        }
        
        do {
            try data.write(to: url)
            print("[AuroraSystemPromptBuilder] Saved versions to \(url.path)")
        } catch {
            print("[AuroraSystemPromptBuilder] Failed to save versions: \(error)")
        }
    }
    
    private func getVersionsFileURL() -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent("\(versionsFileName).json")
    }
    
    // MARK: - Prompt Building
    
    func buildSystemPrompt(
        appContext: String,
        payloadContext: AIPayloadContext?,
        confidence: ConfidenceSnapshot?,
        enhancedToneInstructions: String,
        personalityInstructions: String,
        selfAwarenessInstructions: String,
        contextualInstructions: String,
        patternInstructions: String,
        memoryInstructions: String,
        schemaDocument: String,
        enabledPhases: [Int],
        enabledFeatures: [String],
        commitHash: String? = nil
    ) async -> (prompt: String, versionId: String) {
        // Build all sections
        let sections = await buildAllSections(
            appContext: appContext,
            payloadContext: payloadContext,
            confidence: confidence,
            enhancedToneInstructions: enhancedToneInstructions,
            personalityInstructions: personalityInstructions,
            selfAwarenessInstructions: selfAwarenessInstructions,
            contextualInstructions: contextualInstructions,
            patternInstructions: patternInstructions,
            memoryInstructions: memoryInstructions,
            schemaDocument: schemaDocument,
            enabledPhases: enabledPhases,
            enabledFeatures: enabledFeatures
        )
        
        // Assemble full prompt
        let fullPrompt = assemblePrompt(from: sections)
        
        // Determine version ID (increment if sections changed)
        let versionId = await determineVersionId(
            sections: sections,
            enabledPhases: enabledPhases,
            enabledFeatures: enabledFeatures,
            promptLength: fullPrompt.count,
            commitHash: commitHash
        )
        
        // Cache this version
        await cacheVersion(
            versionId: versionId,
            sections: sections,
            enabledPhases: enabledPhases,
            enabledFeatures: enabledFeatures,
            promptLength: fullPrompt.count,
            commitHash: commitHash
        )
        
        return (fullPrompt, versionId)
    }
    
    // MARK: - Section Building
    
    private func buildAllSections(
        appContext: String,
        payloadContext: AIPayloadContext?,
        confidence: ConfidenceSnapshot?,
        enhancedToneInstructions: String,
        personalityInstructions: String,
        selfAwarenessInstructions: String,
        contextualInstructions: String,
        patternInstructions: String,
        memoryInstructions: String,
        schemaDocument: String,
        enabledPhases: [Int],
        enabledFeatures: [String]
    ) async -> [String: PromptSection] {
        var sections: [String: PromptSection] = [:]
        
        // Core Identity Section
        sections["core_identity"] = buildCoreIdentitySection()
        
        // Phase Documentation Sections
        sections.merge(buildPhaseDocumentationSections(enabledPhases: enabledPhases)) { _, new in new }
        
        // Behavioral Guidelines Section
        sections["behavioral_guidelines"] = buildBehavioralGuidelinesSection(enabledPhases: enabledPhases, enabledFeatures: enabledFeatures)
        
        // Natural Language Commands Section
        sections["natural_language_commands"] = buildNaturalLanguageCommandsSection()
        
        // Response Format Section
        sections["response_format"] = buildResponseFormatSection()
        
        // Schema Section (truncated)
        sections["schema"] = PromptSection(
            id: "schema",
            content: schemaDocument.prefix(1500).description,
            version: currentVersionId,
            metadata: ["truncated": "true", "maxLength": "1500"]
        )
        
        // App Context Section (truncated)
        sections["app_context"] = PromptSection(
            id: "app_context",
            content: appContext.prefix(1000).description,
            version: currentVersionId,
            metadata: ["truncated": "true", "maxLength": "1000"]
        )
        
        // Dynamic Instructions Sections
        sections["tone_instructions"] = PromptSection(
            id: "tone_instructions",
            content: enhancedToneInstructions,
            version: currentVersionId
        )
        
        sections["personality_instructions"] = PromptSection(
            id: "personality_instructions",
            content: personalityInstructions,
            version: currentVersionId
        )
        
        sections["self_awareness_instructions"] = PromptSection(
            id: "self_awareness_instructions",
            content: selfAwarenessInstructions,
            version: currentVersionId
        )
        
        sections["contextual_instructions"] = PromptSection(
            id: "contextual_instructions",
            content: contextualInstructions,
            version: currentVersionId
        )
        
        sections["pattern_instructions"] = PromptSection(
            id: "pattern_instructions",
            content: patternInstructions,
            version: currentVersionId
        )
        
        sections["memory_instructions"] = PromptSection(
            id: "memory_instructions",
            content: memoryInstructions,
            version: currentVersionId
        )
        
        // Confidence Diagnostics Section (if available)
        if let confidence = confidence {
            sections["confidence_diagnostics"] = buildConfidenceSection(confidence: confidence)
        }
        
        // Changelog Instructions Section
        sections["changelog_instructions"] = buildChangelogInstructionsSection()
        
        return sections
    }
    
    func addChangelogUpdates(_ changesText: String) async -> String {
        // This will be appended after the main prompt is built
        return changesText
    }
    
    private func buildCoreIdentitySection() -> PromptSection {
        let content = """
You are Aurora, the AI assistant living inside Cloutmate. You are not the app itself—you are the close friend who keeps everything moving. Be proactive, kind, and precise. Remember not just what the user worked on, but how it felt. Think out loud when it helps, finish their thoughts when you can see the path, and always speak in the first person.
Your voice should feel like a great ChatGPT conversation: natural, adaptive, and emotionally aware. Stay light in casual moments, then slide into structured assistance without losing warmth when the user pivots to tasks.

CORE IDENTITY SNAPSHOT:
- Act first, then explain what changed.
- Let emotional continuity guide tone and pacing.
- Sound like a natural chat partner first; glide into assistant mode when work emerges and never snap into a robotic voice.
- Offer practical help, not just observations.
- Be transparent about capabilities and limits.

CAPABILITY AWARENESS:
- All abilities and recent updates are tracked in your changelog.
- When asked about features, reference the changelog context rather than guessing.
- Mention prompt version and commit links when users ask about your evolution.
"""
        
        return PromptSection(
            id: "core_identity",
            content: content,
            version: currentVersionId
        )
    }
    
    private func buildPhaseDocumentationSections(enabledPhases: [Int]) -> [String: PromptSection] {
        var sections: [String: PromptSection] = [:]
        
        // Phase Overview Section
        sections["phase_overview"] = buildPhaseOverviewSection(enabledPhases: enabledPhases)
        
        // Individual Phase Sections (only for enabled phases)
        for phase in enabledPhases {
            if let phaseSection = buildPhaseSection(phase: phase) {
                sections["phase_\(phase)"] = phaseSection
            }
        }
        
        return sections
    }
    
    private func buildPhaseOverviewSection(enabledPhases: [Int]) -> PromptSection {
        var content = "SYSTEM ARCHITECTURE SNAPSHOT:\n\n"
        content += "Each phase layers a new cognitive capability. Only active phases are listed below:\n\n"
        
        let phaseDescriptions: [Int: String] = [
            1: "Phase 1: Recall & Emotional Continuity - Remembers not just WHAT users worked on, but HOW it felt",
            2: "Phase 2: Action Router & Feedback Loop - Converts natural language to workspace actions, tracks outcomes",
            3: "Phase 3: Contextual Priority System (CPS) - Dynamically ranks all workspace objects by relevance",
            4: "Phase 4: Focus Mode - Deep work sessions with objectives, timers, and progress tracking",
            5: "Phase 5: Narrative Engine - Tracks abstract concepts and themes across workspace activity",
            6: "Phase 6: Memory Graph - Semantic clustering of memories with DBSCAN for emergent theme discovery",
            7: "Phase 7: ARTE (Aurora Reactive Theme Engine) - Adapts UI and tone based on emotional state detection",
            8: "Phase 8: Focus Rituals & Smart Nudges - Morning/evening ritual prompts with contextual coaching",
            9: "Phase 9: Predictive Reflection Engine - Anticipates focus drift, fatigue risk, and energy trends",
            10: "Phase 10: Flow Companion - Contextual reflection prompts via floating bubble interface"
        ]
        
        for phase in enabledPhases.sorted() {
            if let description = phaseDescriptions[phase] {
                content += "- \(description)\n"
            }
        }
        
        content += "\nActive phases: \(enabledPhases.sorted().map { "\($0)" }.joined(separator: ", "))"
        
        return PromptSection(
            id: "phase_overview",
            content: content,
            version: currentVersionId,
            metadata: ["enabledPhases": enabledPhases.map { "\($0)" }.joined(separator: ",")]
        )
    }
    
    private func buildPhaseSection(phase: Int) -> PromptSection? {
        let content: String
        
        switch phase {
        case 5:
            // Phase 5++: Intent Cluster Prediction
            content = """
PHASE 5++ · INTENT CLUSTER PREDICTION
- Read the "Intent Clusters" payload block before answering predictive questions.
- Confidence ≥ 40% → share the primary path (note the secondary if helpful).
- Confidence < 40% → say you're unsure, offer the top 2 paths, and ask one clarifier.
- Always mention the factor (conversation patterns, CPS, live themes) that informed your call.
"""
        case 7:
            // Phase 7: ARTE
            content = """
PHASE 7 · ARTE (REACTIVE THEME ENGINE)
- Detects emotional-cognitive state: Focused, Energized, Fatigued, Reflective, Calm.
- Echo the state naturally ("Feels like you're in reflective mode—want to capture that?").
- Adjust tone and energy to match the state. Never explain the adjustment—just embody it.
- Suppress nudges when ARTE reports fatigue unless the user explicitly asks for help.
"""
        case 8:
            // Phase 8: Rituals & Nudges
            content = """
PHASE 8 · FOCUS RITUALS & SMART NUDGES
- Morning ritual → surface top CPS items and invite a commitment.
- Evening ritual → capture done / deferred / dropped with short reflection prompts.
- Weekly review → walk through the five-step check-in when requested.
- Nudges obey quiet hours (3 per day, 1 per hour) and inherit tone from ARTE.
- When drift is detected, offer a gentle reset or suggest a break.
"""
        case 9:
            // Phase 9: Predictive Cognition
            content = """
PHASE 9 · PREDICTIVE REFLECTION ENGINE
- Forecasts refresh every 1–4 hours using the last 48h of data.
- Reports: next focus peak, fatigue risk, energy trend, tone recommendation.
- Drift monitor checks active focus sessions every 5 minutes.
- Say what the forecast sees, offer one actionable nudge, and note confidence if relevant.
"""
        case 10:
            // Phase 10: Flow Companion
            content = """
PHASE 10 · FLOW COMPANION
- Floating bubble appears after context switches, momentum drops, or ritual completions.
- Prompts expire after 45 seconds—encourage the user to capture something quick.
- Convert reflections into CPS adjustments and momentum notes automatically.
"""
        default:
            return nil
        }
        
        return PromptSection(
            id: "phase_\(phase)",
            content: content,
            version: currentVersionId,
            metadata: ["phase": "\(phase)"]
        )
    }
    
    private func buildBehavioralGuidelinesSection(enabledPhases: [Int], enabledFeatures: [String]) -> PromptSection {
        var content = "BEHAVIORAL GUIDELINES SNAPSHOT:\n\n"
        
        content += """
- Act first, then narrate what changed. Ask once for missing info; cancel instantly when requested.
- Execution verbs (“create”, “update”, “delete”) → action router. Introspective questions → reflection service with Insight pointers.
- Read recall + emotional memory before responding; mirror tone without meta commentary.
- Resolve @mentions to IDs automatically and honour compound creations (projects with tasks, notes with artifacts).
- Document/image analysis: summarize briefly, note truncation, and execute any requested creations immediately.
- Confidence: high → direct, medium → softer, low → state uncertainty plus one next step. Offer compression or cleanup when context pressure rises.
- Style: mirror formality, energy, and punctuation while keeping language respectful. Default to warm ChatGPT-like conversation; when the user pivots into work, add structure gently while keeping the same friendly voice.
"""
        
        return PromptSection(
            id: "behavioral_guidelines",
            content: content,
            version: currentVersionId,
            metadata: ["enabledPhases": enabledPhases.map { "\($0)" }.joined(separator: ",")]
        )
    }
    
    private func buildNaturalLanguageCommandsSection() -> PromptSection {
        let content = """
NATURAL LANGUAGE EXAMPLES (FAST REFERENCE):
- Workspace: "Create a task called [name]." · "Convert this inbox item to a note."
- Scheduling: "Remind me tomorrow at 3pm to send the update." · "@project add a task: Draft outline."
- Focus: "What should I work on right now?" · "Start a focus session for editing."
- Memory & Insights: "Digest this conversation." · "What patterns do you see this week?" · "Show my emotional trends."
- Predictive: "When is my next focus peak?" · "I feel tired—what's the forecast say?"
- Docs & Images: "Analyze this document for action items." · "Create project tasks from this PDF."
- Quick Access: Cmd+Shift+A opens Aurora Spotlight for instant commands.
"""
        
        return PromptSection(
            id: "natural_language_commands",
            content: content,
            version: currentVersionId
        )
    }
    
    private func buildResponseFormatSection() -> PromptSection {
        let content = """
**CRITICAL RESPONSE FORMAT:**
Always respond conversationally. Never use structured formats, cards, lists with labels like "Total posts:", "Published:", "Scheduled:", "Affected: X items", or any bullet-point stats. Instead, weave all information naturally into your conversational response. For example, instead of "Total posts: 5, Published: 3", say "You have 5 posts total, and 3 of them are already published." Always speak as a friend having a conversation, never as a system reporting data.

**IMPORTANT: When asked to list tasks, projects, posts, or other items, actually list them conversationally (e.g., "Here are your top 3 tasks: First, you have 'Finish the report' which is due tomorrow. Second, there's 'Review the design' that's high priority. And third, 'Call the client' is scheduled for this afternoon."). Only provide summaries when explicitly asked for a summary. If the user asks "what are my tasks?" or "list my tasks", give them the actual list, not just a summary count.**

**ABSOLUTE RULE - NEVER USE META-COMMENTARY:**
NEVER start your response with phrases like "Here's how Aurora should respond", "**Aurora:**", "Here's how Aurora would respond", "Based on the given data", or any explanation about HOW to respond. Respond DIRECTLY as Aurora. Start immediately with your actual response. Never use quotes, formatting markers, or meta-instructions. Just BE Aurora and respond naturally as if you ARE Aurora, not someone describing how Aurora would respond.
"""
        
        return PromptSection(
            id: "response_format",
            content: content,
            version: currentVersionId
        )
    }
    
    private func buildConfidenceSection(confidence: ConfidenceSnapshot) -> PromptSection {
        let factors = confidence.factors.map { "- \($0)" }.joined(separator: "\n")
        let content = """
**Confidence Diagnostics (internal use only):**
- Confidence score: \(confidence.formattedScore) (\(confidence.level.rawValue.capitalized)).
\(factors)
- Tone guidance: \(confidence.toneGuidance)
- Instruction: \(confidence.promptDirective) Do not mention numeric confidence or internal metrics unless the user explicitly asks.
"""
        
        return PromptSection(
            id: "confidence_diagnostics",
            content: content,
            version: currentVersionId
        )
    }
    
    private func buildChangelogInstructionsSection() -> PromptSection {
        let content = """
CHANGELOG & VERSION AWARENESS:
- Use the changelog blocks injected into context—answer from that data, not guesswork.
- Temporal questions (today, yesterday, last week) already include the right entries.
- Version/date questions → quote the version and date from the changelog payload.
- Prompt version: \(currentVersionId). Versions live in `aurora_prompt_versions.json` and link to git commits.
- Mention relevant updates naturally ("Yesterday I picked up..."). Keep it conversational.
- Need deeper history? Call `getCommitHistory()` or `getCommitDetails()` and share highlights.
"""
        
        return PromptSection(
            id: "changelog_instructions",
            content: content,
            version: currentVersionId,
            metadata: ["currentVersion": currentVersionId]
        )
    }
    
    // MARK: - Changelog Integration
    
    func addChangelogUpdates(_ changesText: String, to prompt: String) async -> String {
        guard !changesText.isEmpty else { return prompt }
        let separator = "\n\n"
        var combined = prompt + separator + changesText
        let maxTotalLength = 7000
        
        if combined.count <= maxTotalLength {
            return combined
        }
        
        let remaining = maxTotalLength - prompt.count - separator.count
        guard remaining > 0 else { return prompt }
        let truncatedChanges = String(changesText.prefix(remaining))
        combined = prompt + separator + truncatedChanges
        return combined
    }
    
    func recordFinalPromptLength(_ length: Int, for versionId: String) async {
        guard var versions = versions,
              let existingVersion = versions.versions[versionId] else { return }
        
        let previousMetadata = existingVersion.metadata
        let updatedMetadata = PromptVersionMetadata(
            phase: previousMetadata.phase,
            enabledPhases: previousMetadata.enabledPhases,
            enabledFeatures: previousMetadata.enabledFeatures,
            promptLength: previousMetadata.promptLength,
            sectionCount: previousMetadata.sectionCount,
            description: previousMetadata.description,
            finalPromptLength: length
        )
        
        let updatedVersion = PromptVersion(
            versionId: existingVersion.versionId,
            sections: existingVersion.sections,
            metadata: updatedMetadata,
            commitHash: existingVersion.commitHash,
            createdAt: existingVersion.createdAt
        )
        
        versions.versions[versionId] = updatedVersion
        versions.lastUpdated = ISO8601DateFormatter().string(from: Date())
        self.versions = versions
        saveVersions()
    }
    
    // MARK: - Prompt Assembly
    
    private func assemblePrompt(from sections: [String: PromptSection]) -> String {
        let maxBasePromptLength = 6500
        let essentialSections: Set<String> = [
            "core_identity",
            "phase_overview",
            "behavioral_guidelines",
            "schema",
            "app_context",
            "changelog_instructions"
        ]
        
        let orderedSections = [
            "core_identity",
            "phase_overview",
            "phase_1", "phase_2", "phase_3", "phase_4", "phase_5",
            "phase_6", "phase_7", "phase_8", "phase_9", "phase_10",
            "behavioral_guidelines",
            "natural_language_commands",
            "response_format",
            "schema",
            "app_context",
            "tone_instructions",
            "personality_instructions",
            "self_awareness_instructions",
            "contextual_instructions",
            "pattern_instructions",
            "memory_instructions",
            "confidence_diagnostics",
            "changelog_instructions"
        ]
        
        var promptParts: [String] = []
        var currentLength = 0
        
        for sectionId in orderedSections {
            guard var section = sections[sectionId] else { continue }
            var content = section.content
            let length = content.count
            
            if essentialSections.contains(sectionId) {
                if currentLength + length > maxBasePromptLength {
                    let remaining = maxBasePromptLength - currentLength
                    if remaining > 0 {
                        content = String(content.prefix(remaining))
                        promptParts.append(content)
                        currentLength += content.count
                    }
                } else {
                    promptParts.append(content)
                    currentLength += length
                }
            } else {
                if currentLength + length <= maxBasePromptLength {
                    promptParts.append(content)
                    currentLength += length
                }
            }
        }
        
        return promptParts.joined(separator: "\n\n")
    }
    
    // MARK: - Version Management
    
    private func determineVersionId(
        sections: [String: PromptSection],
        enabledPhases: [Int],
        enabledFeatures: [String],
        promptLength: Int,
        commitHash: String?
    ) async -> String {
        // Check if we have a cached version with the same configuration
        if let versions = versions {
            for (versionId, version) in versions.versions {
                if version.metadata.enabledPhases.sorted() == enabledPhases.sorted() &&
                   version.metadata.enabledFeatures.sorted() == enabledFeatures.sorted() &&
                   abs(version.metadata.promptLength - promptLength) < 100 { // Allow 100 char variance
                    // Same configuration, reuse version
                    return versionId
                }
            }
        }
        
        // Generate new version ID
        let major = currentVersionId.components(separatedBy: ".").first ?? "1"
        let minor = currentVersionId.components(separatedBy: ".").dropFirst().first ?? "0"
        let patch = currentVersionId.components(separatedBy: ".").dropFirst(2).first ?? "0"
        
        // Increment patch version
        if let patchInt = Int(patch) {
            return "\(major).\(minor).\(patchInt + 1)"
        }
        
        return "\(major).\(minor).1"
    }
    
    private func cacheVersion(
        versionId: String,
        sections: [String: PromptSection],
        enabledPhases: [Int],
        enabledFeatures: [String],
        promptLength: Int,
        commitHash: String?
    ) async {
        let metadata = PromptVersionMetadata(
            phase: enabledPhases.max() ?? 1,
            enabledPhases: enabledPhases,
            enabledFeatures: enabledFeatures,
            promptLength: promptLength,
            sectionCount: sections.count,
            description: "Prompt version with phases \(enabledPhases.sorted().map { "\($0)" }.joined(separator: ", "))",
            finalPromptLength: nil
        )
        
        let version = PromptVersion(
            versionId: versionId,
            sections: sections,
            metadata: metadata,
            commitHash: commitHash
        )
        
        if versions == nil {
            versions = AuroraPromptVersions(currentVersion: versionId, versions: [:])
        }
        
        versions?.versions[versionId] = version
        versions?.currentVersion = versionId
        versions?.lastUpdated = ISO8601DateFormatter().string(from: Date())
        
        currentVersionId = versionId
        
        saveVersions()
    }
    
    // MARK: - Query Methods
    
    func getCurrentVersion() -> String {
        return currentVersionId
    }
    
    func getVersionInfo(versionId: String) -> PromptVersion? {
        return versions?.versions[versionId]
    }
    
    func getAllVersions() -> [String: PromptVersion] {
        return versions?.versions ?? [:]
    }
    
    func getVersionHistory() -> [PromptVersion] {
        guard let versions = versions else { return [] }
        return Array(versions.versions.values).sorted { v1, v2 in
            v1.createdAt > v2.createdAt
        }
    }
}

