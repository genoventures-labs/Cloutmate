//
//  JournalDetailDrawer.swift
//  Cloutmate
//
//  Journal detail drawer with ARTE reflection and Focus Gravity sidebar
//

import SwiftUI
import SwiftData
import CloutmateShared
import AppKit

enum JournalTemplate {
    case morning
    case evening
    case freeWrite
    
    var content: String {
        switch self {
        case .morning:
            return "Today I intend to…"
        case .evening:
            return "Today I learned…"
        case .freeWrite:
            return ""
        }
    }
}

struct JournalDetailDrawer: View {
    @Bindable var journal: Journal
    @Binding var isPresented: Bool
    
    let template: JournalTemplate?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var editingMood: JournalMood = .none
    @State private var editingEntryType: JournalEntryType = .reflection
    
    @State private var aiSummary: String?
    @State private var isGeneratingSummary = false
    @State private var isSummaryExpanded = true
    
    @State private var emotionalState: EmotionalStateDetection?
    @State private var dailySnapshot: AnalyticsSnapshot?
    @State private var showAuroraChat = false
    
    @FocusState private var isContentFocused: Bool
    
    init(journal: Journal, isPresented: Binding<Bool>, template: JournalTemplate? = nil) {
        self.journal = journal
        self._isPresented = isPresented
        self.template = template
    }
    
    private var focusGravityIntensity: Double {
        // Calculate engagement weight based on update frequency and age
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: journal.updatedAt, to: Date()).day ?? 0
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: journal.createdAt, to: Date()).day ?? 1
        
        // More recent updates = higher intensity
        let recencyScore = max(0, 1.0 - (Double(daysSinceUpdate) / 30.0))
        
        // More frequent updates = higher intensity
        let updateFrequency = Double(daysSinceCreation) > 0 ? Double(journal.content.count) / Double(daysSinceCreation) : 0.0
        let frequencyScore = min(1.0, updateFrequency / 100.0)
        
        return (recencyScore + frequencyScore) / 2.0
    }
    
    var body: some View {
                        HStack(spacing: 0) {
                            // Focus Gravity Sidebar
                            RoundedRectangle(cornerRadius: 0, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .kosmicBlue.opacity(focusGravityIntensity),
                                            .kosmicPurple.opacity(focusGravityIntensity * 0.8)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 4)
                            
                            // Main content
                            VStack(spacing: 0) {
                                // Header
                HStack(spacing: 12) {
                                    TextField("Journal Title", text: $editingTitle)
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.bold)
                                        .textFieldStyle(.plain)
                                    
                    if journal.author == .aurora {
                        AuroraAuthorBadge()
                    }
                    
                                    Spacer()
                                    
                                    Button(action: {
                                        saveJournal()
                                            isPresented = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .keyboardShortcut(.escape, modifiers: [])
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        // Entry metadata
                                        HStack(spacing: 16) {
                                            // Entry type picker
                                            Picker("Type", selection: $editingEntryType) {
                                                ForEach(JournalEntryType.allCases, id: \.self) { type in
                                                    Label(type.rawValue, systemImage: type.icon).tag(type)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            
                                            // Mood picker
                                            Picker("Mood", selection: $editingMood) {
                                                ForEach(JournalMood.allCases, id: \.self) { mood in
                                                    Text(mood.rawValue).tag(mood)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            
                                            Spacer()
                                            
                                            // Date
                                            Text(journal.entryDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal)
                                        .padding(.top, 8)
                                        
                                        // Body editor
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Content")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            TextEditor(text: $editingContent)
                                                .font(.body)
                                                .frame(minHeight: 200)
                                                .scrollContentBackground(.hidden)
                                                .focused($isContentFocused)
                                                .padding(8)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(8)
                                                .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: isContentFocused)
                                        }
                                        .padding(.horizontal)
                                        
                                        // Sidebar components
                                        VStack(spacing: 16) {
                                            // ARTE Reflection Card
                                            if let emotionalState = emotionalState {
                                                ARTEReflectionCard(
                                                    journal: journal,
                                                    emotionalState: emotionalState,
                                                    snapshot: dailySnapshot
                                                )
                                                .padding(.horizontal)
                                            }
                                            
                                            // Mood Radar Chart
                                            MoodRadarChart(
                                                calm: calculateMoodValue(for: .calm),
                                                creative: calculateMoodValue(for: .creative),
                                                chaotic: calculateMoodValue(for: .frustrated),
                                                restless: calculateMoodValue(for: .excited)
                                            )
                                            .padding(.horizontal)
                                            
                                            // AI Summary Section
                                            JournalAISummarySection(
                                                summary: aiSummary,
                                                isGenerating: isGeneratingSummary,
                                                isExpanded: $isSummaryExpanded,
                                                onRegenerate: generateSummary
                                            )
                                            .padding(.horizontal)
                                            
                                            // Ask Aurora button
                                            Button(action: {
                                                showAuroraChat = true
                                            }) {
                                                HStack {
                                                    Image(systemName: "sparkles")
                                                    Text("Ask Aurora")
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    LinearGradient(
                                                        colors: [.kosmicBlue, .kosmicPurple],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.horizontal)
                                        }
                                    }
                                    .padding(.vertical)
                                }
            }
                            }
        .frame(width: 700, height: 700)
        .background(glassColorSystem.backgroundColor())
        .onAppear {
            editingTitle = journal.title
            editingContent = template?.content ?? journal.content
            editingMood = journal.journalMood
            editingEntryType = journal.journalEntryType
            
            // Load ARTE and Focus Gravity data
            loadARTEData()
            loadFocusGravityData()
        }
        .onChange(of: editingTitle) { _, newValue in
            journal.title = newValue
            journal.updatedAt = Date()
        }
        .onChange(of: editingContent) { _, newValue in
            journal.content = newValue
            journal.updatedAt = Date()
        }
        .onChange(of: editingMood) { _, newValue in
            journal.journalMood = newValue
            journal.updatedAt = Date()
        }
        .onChange(of: editingEntryType) { _, newValue in
            journal.journalEntryType = newValue
            journal.updatedAt = Date()
        }
        .sheet(isPresented: $showAuroraChat) {
            AuroraJournalChatOverlay(journal: journal, isPresented: $showAuroraChat)
        }
        .task {
            // Auto-focus content field on open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isContentFocused = true
            }
        }
        .onDisappear {
            // Delete empty journals when sheet closes
            if journal.title.isEmpty && journal.content.isEmpty && journal.tags.isEmpty {
                modelContext.delete(journal)
                try? modelContext.save()
            }
        }
    }
    
    private func calculateMoodValue(for mood: JournalMood) -> Double {
        // Calculate mood values based on journal mood and ARTE data
        if journal.journalMood == mood {
            return 0.8
        }
        
        // Use emotional state to infer mood values
        if let detection = emotionalState {
            switch mood {
            case .calm:
                return detection.state == .calm ? 0.7 : 0.3
            case .creative:
                return detection.state == .reflective ? 0.6 : 0.2
            case .frustrated:
                return detection.state == .fatigued ? 0.5 : 0.1
            case .excited:
                return detection.state == .energized ? 0.7 : 0.2
            default:
                return 0.3
            }
        }
        
        return 0.3
    }
    
    private func loadARTEData() {
        _Concurrency.Task { @MainActor in
            // Get snapshot for entry date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: journal.entryDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? journal.entryDate
            
            let snapshot = await AnalyticsEngine.shared.generateSnapshot(
                for: .custom,
                customRange: (startOfDay, endOfDay),
                modelContext: modelContext
            )
            
            // Detect emotional state
            let detector = EmotionalStateDetector()
            let detection = detector.detectState(
                from: snapshot,
                modelContext: modelContext
            )
            
            emotionalState = detection
            dailySnapshot = snapshot
        }
    }
    
    private func loadFocusGravityData() {
        // Focus Gravity data is already calculated in focusGravityIntensity computed property
        // Additional Focus Gravity trend can be loaded here if needed
    }
    
    private func saveJournal() {
        journal.title = editingTitle.isEmpty ? "Untitled Entry" : editingTitle
        journal.content = editingContent
        journal.journalMood = editingMood
        journal.journalEntryType = editingEntryType
        journal.updatedAt = Date()
        
        try? modelContext.save()
        
        // Haptic feedback
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
        
        // Update Memory Graph
        updateMemoryGraph()
    }
    
    private func generateSummary() {
        guard !isGeneratingSummary else { return }
        
        isGeneratingSummary = true
        
        _Concurrency.Task { @MainActor in
            do {
                let ollamaService = OllamaBridgeService.shared
                
                // Create document descriptor
                let descriptor = DocumentDescriptor(
                    text: journal.content,
                    preview: String(journal.content.prefix(200)),
                    fileName: journal.title.isEmpty ? "Untitled Entry" : journal.title,
                    mimeType: "text/plain",
                    sizeInBytes: journal.content.utf8.count,
                    pageCount: nil,
                    sourceURL: nil
                )
                
                // Build app context
                let appContext = buildAppContext()
                
                // Analyze document
                let result = try await ollamaService.analyzeDocument(
                    descriptor: descriptor,
                    userPrompt: "Provide a concise reflection summary with key insights and emotional tone.",
                    appContext: appContext,
                    payloadContext: nil,
                    conversationMessages: nil,
                    currentMessageStyle: nil,
                    userStyleProfile: nil,
                    confidence: nil
                )
                
                aiSummary = result.summary
                journal.aiGeneratedContent = result.summary
                isGeneratingSummary = false
            } catch {
                aiSummary = "Unable to generate summary: \(error.localizedDescription)"
                isGeneratingSummary = false
            }
        }
    }
    
    private func buildAppContext() -> String {
        var context = "Journal Entry: \(journal.title)\n"
        context += "Mood: \(journal.journalMood.rawValue)\n"
        context += "Type: \(journal.journalEntryType.rawValue)\n"
        context += "Date: \(journal.entryDate.formatted(date: .abbreviated, time: .omitted))\n"
        return context
    }
    
    private func updateMemoryGraph() {
        _Concurrency.Task { @MainActor in
            // Register journal update with Recall Service
            AIRecallService.shared.registerUpdated(journal, modelContext: modelContext)
            
            // Link to related concepts/themes via tags
            if !journal.tags.isEmpty && AIConfigService.shared.config.featureFlags.memoryGraphEnabled {
                do {
                    // Find or create node for this journal entry
                    let node = try await MemoryGraphService.shared.findOrCreateNode(
                        for: journal,
                        modelContext: modelContext
                    )
                    
                    // Update node tags
                    node.tags = journal.tags
                    try? modelContext.save()
                } catch {
                    // Silently fail if Memory Graph is disabled or unavailable
                }
            }
        }
    }
}

// MARK: - AI Summary Section

struct JournalAISummarySection: View {
    let summary: String?
    let isGenerating: Bool
    @Binding var isExpanded: Bool
    let onRegenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(GlassMotion.Easing.spring) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("AI Summary")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if isGenerating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating summary...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                } else if let summary = summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    
                    Button(action: onRegenerate) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Regenerate")
                        }
                        .font(.caption)
                        .foregroundColor(.kosmicPurple)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onRegenerate) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Summary")
                        }
                        .font(.caption)
                        .foregroundColor(.kosmicPurple)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    JournalDetailDrawer(
        journal: Journal(title: "Sample Entry", content: "This is a sample journal entry."),
        isPresented: $isPresented
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Journal.self])
}

