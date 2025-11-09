//
//  ContextualCreateSheet.swift
//  Cloutmate
//
//  Context-aware creation sheet that adapts to current tab
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct ContextualCreateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let currentTab: TabIdentifier
    
    @State private var mostUsedActions: [String] = []
    @State private var recentlyCreated: String?
    @State private var previousEmotionalState: EmotionalState = .calm
    @State private var previousEmotionalIntensity: Double = 0.7
    
    // If current tab is AI Assistant, use a default tab for context
    private var effectiveTab: TabIdentifier {
        if currentTab == .aiAssistant {
            return .home // Default to home, could be enhanced to track last non-AI tab
        }
        return currentTab
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Create")
                            .font(.system(size: 28, weight: .bold))
                        Text("Choose what to create")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Action buttons grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(actionsForTab, id: \.id) { action in
                            CreateActionButton(
                                action: action,
                                isMostUsed: mostUsedActions.contains(action.type),
                                isRecentlyCreated: recentlyCreated == action.type,
                                onTap: {
                                    handleAction(action)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(glassColorSystem.backgroundColor())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        restoreEmotionalState()
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            setupEmotionalTinting()
            loadSmartDefaults()
        }
    }
    
    private var actionsForTab: [CreateAction] {
        switch effectiveTab {
        case .inbox:
            return [
                CreateAction(type: "Quick Capture", icon: "bolt.fill", color: .kosmicBlue),
                CreateAction(type: "New Note", icon: "note.text", color: .kosmicPurple),
                CreateAction(type: "Voice Memo", icon: "mic.fill", color: .orange)
            ]
        case .notes:
            return [
                CreateAction(type: "New Note", icon: "note.text", color: .kosmicPurple),
                CreateAction(type: "Quick Capture", icon: "bolt.fill", color: .kosmicBlue),
                CreateAction(type: "Voice Memo", icon: "mic.fill", color: .orange)
            ]
        case .tasks:
            return [
                CreateAction(type: "Task", icon: "checkmark.circle.fill", color: .kosmicBlue),
                CreateAction(type: "Subtask", icon: "list.bullet", color: .kosmicGreen),
                CreateAction(type: "Routine Builder", icon: "arrow.triangle.2.circlepath", color: .kosmicPurple)
            ]
        case .drafts:
            return [
                CreateAction(type: "New Draft", icon: "doc.text", color: .kosmicPurple),
                CreateAction(type: "Draft From AI", icon: "sparkles", color: .kosmicBlue),
                CreateAction(type: "Draft From Note", icon: "note.text", color: .kosmicGreen)
            ]
        case .projects:
            return [
                CreateAction(type: "New Project", icon: "folder.fill", color: .kosmicBlue)
            ]
        case .posts:
            // Now shows artifacts instead of social media posts
            return [
                CreateAction(type: "New Artifact", icon: "doc.text.fill", color: .kosmicBlue),
                CreateAction(type: "Quick Capture", icon: "bolt.fill", color: .orange)
            ]
        case .resources:
            return [
                CreateAction(type: "Import Resource", icon: "square.and.arrow.down", color: .kosmicBlue),
                CreateAction(type: "Save Link", icon: "link", color: .kosmicPurple),
                CreateAction(type: "Capture Text", icon: "text.cursor", color: .kosmicGreen)
            ]
        case .calendar:
            return [
                CreateAction(type: "New Task", icon: "checkmark.circle.fill", color: .kosmicBlue),
                CreateAction(type: "Reflection", icon: "brain.head.profile", color: .kosmicPurple),
                CreateAction(type: "Journal Entry", icon: "book.fill", color: .kosmicGreen)
            ]
        case .journal:
            return [
                CreateAction(type: "Morning Reflection", icon: "sunrise.fill", color: .kosmicBlue),
                CreateAction(type: "Evening Reflection", icon: "moon.fill", color: .kosmicPurple),
                CreateAction(type: "Free Write", icon: "pencil", color: .kosmicGreen)
            ]
        default:
            return [
                CreateAction(type: "New Note", icon: "note.text", color: .kosmicPurple),
                CreateAction(type: "Task", icon: "checkmark.circle.fill", color: .kosmicBlue),
                CreateAction(type: "New Project", icon: "folder.fill", color: .kosmicGreen)
            ]
        }
    }
    
    private func handleAction(_ action: CreateAction) {
        // Track usage
        CreateActionUsageTracker.shared.recordUsage(
            tab: effectiveTab,
            actionType: action.type,
            modelContext: modelContext
        )
        
        // Haptic feedback
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
        
        // Dismiss parent sheet first
        restoreEmotionalState()
        dismiss()
        
        // Post notification to show child sheet from MainWindowView
        // Use a slight delay to ensure parent sheet is dismissed first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch action.type {
            case "New Note":
                NotificationCenter.default.post(name: .showCreateNote, object: nil)
            case "Task", "Subtask":
                NotificationCenter.default.post(name: .showCreateTask, object: nil)
            case "New Project":
                NotificationCenter.default.post(name: .showCreateProject, object: nil)
            case "New Draft":
                NotificationCenter.default.post(name: .openDraftEditor, object: nil)
            case "Draft From AI":
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.aiAssistant)
                NotificationCenter.default.post(name: .openDraftEditor, object: "ai-assistant")
            case "Draft From Note":
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.notes)
                NotificationCenter.default.post(name: .openDraftEditor, object: "note-reference")
            case "New Artifact":
                NotificationCenter.default.post(name: .showArtifactComposer, object: nil)
            case "Quick Capture":
                NotificationCenter.default.post(name: .openInboxCapture, object: nil)
            case "Voice Memo":
                NotificationCenter.default.post(name: .showVoiceMemo, object: nil)
            case "Import Resource", "Save Link", "Capture Text":
                NotificationCenter.default.post(name: .showResourceImport, object: nil)
            case "Routine Builder":
                // TODO: Implement routine builder
                NotificationCenter.default.post(name: .showCreateTask, object: nil)
            case "Reflection":
                // Create reflection artifact
                NotificationCenter.default.post(name: .showArtifactComposer, object: nil)
            case "Journal Entry":
                // Create journal entry (could be a note or artifact)
                NotificationCenter.default.post(name: .showCreateNote, object: nil)
            case "Morning Reflection":
                NotificationCenter.default.post(name: .openJournalEntry, object: JournalTemplate.morning)
            case "Evening Reflection":
                NotificationCenter.default.post(name: .openJournalEntry, object: JournalTemplate.evening)
            case "Free Write":
                NotificationCenter.default.post(name: .openJournalEntry, object: JournalTemplate.freeWrite)
            default:
                break
            }
        }
    }
    
    private func setupEmotionalTinting() {
        // Save current state
        previousEmotionalState = glassColorSystem.emotionalState
        previousEmotionalIntensity = glassColorSystem.emotionalIntensity
        
        // Apply contextual tinting
        let targetState = emotionalStateForTab(effectiveTab)
        glassColorSystem.updateEmotionalState(targetState, intensity: 0.7)
    }
    
    private func restoreEmotionalState() {
        glassColorSystem.updateEmotionalState(previousEmotionalState, intensity: previousEmotionalIntensity)
    }
    
    private func emotionalStateForTab(_ tab: TabIdentifier) -> EmotionalState {
        switch tab {
        case .inbox, .notes:
            return .calm
        case .tasks:
            return .focused
        case .projects, .posts:
            return .energized
        case .journal:
            return .reflective
        default:
            return .calm
        }
    }
    
    private func loadSmartDefaults() {
        mostUsedActions = CreateActionUsageTracker.shared.mostUsedActions(
            in: effectiveTab,
            timeRange: .lastWeek,
            limit: 2,
            modelContext: modelContext
        )
        
        recentlyCreated = CreateActionUsageTracker.shared.recentlyCreatedType(
            in: effectiveTab,
            modelContext: modelContext
        )
    }
}

struct CreateAction {
    let id = UUID()
    let type: String
    let icon: String
    let color: Color
}

struct CreateActionButton: View {
    let action: CreateAction
    let isMostUsed: Bool
    let isRecentlyCreated: Bool
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(action.color)
                }
                
                VStack(spacing: 4) {
                    Text(action.type)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if isMostUsed {
                        Text("✨ Most used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if isRecentlyCreated {
                        Text("🕐 Recently created")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isMostUsed ? glassColorSystem.cardElevated() : glassColorSystem.cardColor())
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isMostUsed ? action.color.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isMostUsed ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMostUsed)
    }
}

struct VoiceMemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var content = ""
    @State private var isRecording = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $content)
                    .font(.body)
                    .frame(minHeight: 200)
                    .glassPanel(tier: .contentCard, cornerRadius: 8)
                
                HStack {
                    VoiceInputButton(text: $content)
                    Spacer()
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create Note") {
                        createNoteFromVoiceMemo()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(content.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Voice Memo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
    }
    
    private func createNoteFromVoiceMemo() {
        let title = content.prefix(50).description
        let note = Note(title: title, markdown: content)
        note.author = .user
        modelContext.insert(note)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ContextualCreateSheet(currentTab: .inbox)
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [CreateActionUsage.self])
}

