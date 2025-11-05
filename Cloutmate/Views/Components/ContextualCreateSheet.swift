//
//  ContextualCreateSheet.swift
//  Cloutmate
//
//  Context-aware creation sheet that adapts to current tab
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ContextualCreateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let currentTab: TabIdentifier
    
    @State private var showCreateNote = false
    @State private var showCreateTask = false
    @State private var showCreateProject = false
    @State private var showComposer = false
    @State private var showQuickCapture = false
    @State private var showVoiceMemo = false
    
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
            .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showCreateNote) {
            CreateNoteSheet()
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskSheet()
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectSheet()
        }
        .sheet(isPresented: $showComposer) {
            ComposerWindow()
        }
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureView()
        }
        .sheet(isPresented: $showVoiceMemo) {
            VoiceMemoSheet()
        }
    }
    
    private var actionsForTab: [CreateAction] {
        switch effectiveTab {
        case .inbox:
            return [
                CreateAction(type: "New Note", icon: "note.text", color: .kosmicPurple),
                CreateAction(type: "Quick Capture", icon: "bolt.fill", color: .kosmicBlue),
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
        case .projects:
            return [
                CreateAction(type: "New Project", icon: "folder.fill", color: .kosmicBlue)
            ]
        case .posts:
            // Should not be shown, but handle gracefully
            return [
                CreateAction(type: "Social Post", icon: "square.and.pencil", color: .orange),
                CreateAction(type: "Content Draft", icon: "doc.text", color: .kosmicBlue),
                CreateAction(type: "Campaign Template", icon: "slider.horizontal.3", color: .kosmicPurple)
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
        
        // Show appropriate sheet
        switch action.type {
        case "New Note":
            showCreateNote = true
        case "Task", "Subtask":
            showCreateTask = true
        case "New Project":
            showCreateProject = true
        case "Social Post", "Content Draft", "Campaign Template":
            showComposer = true
        case "Quick Capture":
            showQuickCapture = true
        case "Voice Memo":
            showVoiceMemo = true
        case "Routine Builder":
            // TODO: Implement routine builder
            showCreateTask = true
        default:
            break
        }
        
        // Dismiss sheet after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            restoreEmotionalState()
            dismiss()
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

