//
//  ContextualCreateSheet.swift
//  FocusOS
//
//  Context-aware creation sheet that adapts to current tab
//

import SwiftUI
import SwiftData
import AppKit
import FocusOSShared

struct ContextualCreateDrawer: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // Backdrop
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer
                VStack(spacing: 0) {
                            V2DrawerScaffold(
                                accentGradient: accentGradient,
                                showsSidebar: false,
                                header: { headerContent },
                                content: { drawerContent },
                                sidebar: { EmptyView() }
                            )
            }
                        .frame(width: 680)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
        .onAppear {
            setupEmotionalTinting()
            loadSmartDefaults()
        }
        .onDisappear {
            restoreEmotionalState()
        }
    }
        }
    }
    
    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
            Text("Create")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
            Text("Choose what to create")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(glassColorSystem.textSecondary())
        }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface
            ) {
                closeDrawer()
            }
            .accessibilityLabel("Close")
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        actionGrid
    }
    
    private var actionGrid: some View {
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
    }
    
    private func closeDrawer() {
                        restoreEmotionalState()
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private var actionsForTab: [CreateAction] {
        switch effectiveTab {
        case .inbox:
            return [
                CreateAction(type: "Quick Capture", icon: "bolt.fill", color: Color.kosmicBlue),
                CreateAction(type: "New Note", icon: "note.text", color: Color.kosmicPurple),
                CreateAction(type: "Voice Memo", icon: "mic.fill", color: .orange)
            ]
        case .notes:
            return [
                CreateAction(type: "New Note", icon: "note.text", color: Color.kosmicPurple),
                CreateAction(type: "Quick Capture", icon: "bolt.fill", color: Color.kosmicBlue),
                CreateAction(type: "Voice Memo", icon: "mic.fill", color: .orange)
            ]
        case .tasks:
            return [
                CreateAction(type: "Task", icon: "checkmark.circle.fill", color: Color.kosmicBlue),
                CreateAction(type: "Subtask", icon: "list.bullet", color: Color.kosmicGreen),
                CreateAction(type: "Routine Builder", icon: "arrow.triangle.2.circlepath", color: Color.kosmicPurple)
            ]
        case .drafts:
            return [
                CreateAction(type: "New Draft", icon: "doc.text", color: Color.kosmicPurple),
                CreateAction(type: "Draft From AI", icon: "sparkles", color: Color.kosmicBlue),
                CreateAction(type: "Draft From Note", icon: "note.text", color: Color.kosmicGreen)
            ]
        case .projects:
            return [
                CreateAction(type: "New Project", icon: "folder.fill", color: Color.kosmicBlue)
            ]
        case .posts:
            return [
                CreateAction(type: "New Artifact", icon: "doc.text.fill", color: Color.kosmicBlue),
                CreateAction(type: "Quick Capture", icon: "bolt.fill", color: .orange)
            ]
        case .resources:
            return [
                CreateAction(type: "Import Resource", icon: "square.and.arrow.down", color: Color.kosmicBlue),
                CreateAction(type: "Save Link", icon: "link", color: Color.kosmicPurple),
                CreateAction(type: "Capture Text", icon: "text.cursor", color: Color.kosmicGreen)
            ]
        case .calendar:
            return [
                CreateAction(type: "New Task", icon: "checkmark.circle.fill", color: Color.kosmicBlue),
                CreateAction(type: "Reflection", icon: "brain.head.profile", color: Color.kosmicPurple),
                CreateAction(type: "Journal Entry", icon: "book.fill", color: Color.kosmicGreen)
            ]
        case .journal:
            return [
                CreateAction(type: "Morning Reflection", icon: "sunrise.fill", color: Color.kosmicBlue),
                CreateAction(type: "Evening Reflection", icon: "moon.fill", color: Color.kosmicPurple),
                CreateAction(type: "Free Write", icon: "pencil", color: Color.kosmicGreen)
            ]
        default:
            return [
                CreateAction(type: "New Note", icon: "note.text", color: Color.kosmicPurple),
                CreateAction(type: "Task", icon: "checkmark.circle.fill", color: Color.kosmicBlue),
                CreateAction(type: "New Project", icon: "folder.fill", color: Color.kosmicGreen)
            ]
        }
    }
    
    private func handleAction(_ action: CreateAction) {
        CreateActionUsageTracker.shared.recordUsage(
            tab: effectiveTab,
            actionType: action.type,
            modelContext: modelContext
        )
        
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
        
        closeDrawer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
                NotificationCenter.default.post(name: .showCreateTask, object: nil)
            case "Reflection":
                NotificationCenter.default.post(name: .showArtifactComposer, object: nil)
            case "Journal Entry":
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
        previousEmotionalState = glassColorSystem.emotionalState
        previousEmotionalIntensity = glassColorSystem.emotionalIntensity
        
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
        DashboardTile(accent: action.color) {
        Button(action: onTap) {
            VStack(spacing: 12) {
                    Image(systemName: action.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(action.color)
                        .frame(width: 56, height: 56)
                
                VStack(spacing: 4) {
                    Text(action.type)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    
                    if isMostUsed {
                        Text("✨ Most used")
                            .font(.caption2)
                                .foregroundStyle(glassColorSystem.textSecondary())
                    } else if isRecentlyCreated {
                        Text("🕐 Recently created")
                            .font(.caption2)
                                .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        }
        .scaleEffect(isMostUsed ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMostUsed)
    }
}

struct VoiceMemoView: View {
    let onClose: () -> Void
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
                        onClose()
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
                        onClose()
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
        onClose()
    }
}

#Preview {
    StatefulPreviewWrapper(true) { binding in
        ContextualCreateDrawer(isPresented: binding, currentTab: .inbox)
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [CreateActionUsage.self])
}
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    
    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }
    
    var body: some View {
        content($value)
    }
}

