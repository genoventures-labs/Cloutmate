//
//  RitualsViewV2.swift
//  FocusOS
//
//  Rituals V2: Unified ritual experience with guided steps, ARTE-adaptive visuals, and reflection
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct RitualsViewV2: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var ritualManager = FocusRitualManager.shared
    @StateObject private var smartNudgeService = SmartNudgeService.shared
    
    @State private var ritualType: FocusRitualType = .morning
    @State private var steps: [RitualStep] = []
    @State private var currentRitual: FocusRitual?
    @State private var isRitualActive = false
    @State private var completedSteps: Set<UUID> = []
    @State private var reflectionText: String?
    @State private var showJournalView = false
    @State private var showFocusGravityView = false
    @State private var showInsightsView = false
    @State private var ritualStartTime: Date?
    @State private var ritualDuration: TimeInterval = 0
    @State private var ritualTimerTask: Task<Void, Never>?
    @State private var isHoveredStep: UUID?
    @State private var isTimerPaused: Bool = false
    @State private var showBreathingModal: Bool = false
    @State private var showOutcomesDrawer: Bool = false
    @State private var showSummaryDrawer: Bool = false
    @State private var showGratitudeJournal: Bool = false
    @State private var showReflectionJournal: Bool = false
    @State private var currentBreathingStep: RitualStep?
    @State private var journalDraft: JournalDraft?
    @State private var ritualSummary: String?
    @State private var patternSuggestions: [RitualPatternSuggestion] = []
    
    var body: some View {
        ZStack {
            V2GlassContentScaffold(
                accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                showsSidebar: false,
                header: { headerBar },
                content: { ritualsContent },
                sidebar: { EmptyView() }
            )
            .opacity(drawerVisible ? 0 : 1)
            .allowsHitTesting(!drawerVisible)
            
            drawerOverlays
        }
        .onChange(of: ritualType) { _, newType in
            withAnimation(.easeInOut(duration: 0.24)) {
                loadSteps(for: newType)
            }
            Task {
                await loadCurrentRitual(for: newType)
            }
        }
        .task {
            loadSteps(for: ritualType)
            await loadCurrentRitual(for: ritualType)
        }
        .sheet(isPresented: $showFocusGravityView) {
            FocusGravityView()
        }
        .sheet(isPresented: $showInsightsView) {
            InsightsView()
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Rituals",
            subtitle: headerSubtitle,
            leadingAccessory: {
                ritualTypeSelector
            },
            trailingAccessory: {
                if let nudge = smartNudgeService.latestNudge,
                   nudge.trigger == .reflectionReminder {
                    nudgeIndicator
                }
            }
        )
    }
    
    private var headerSubtitle: String {
        if isRitualActive {
            let completed = completedSteps.count
            let total = steps.count
            let durationText = isTimerPaused ? "\(formatDuration(ritualDuration)) (paused)" : formatDuration(ritualDuration)
            return "\(completed)/\(total) steps • \(durationText)"
        } else if let ritual = currentRitual, ritual.status == .completed {
            return "Completed • \(ritual.streakCount)-day streak"
        } else {
            return ritualType == .morning ? "Set your morning intention" : "Reflect on your day"
        }
    }
    
    private var ritualTypeSelector: some View {
        HStack(spacing: 8) {
            ForEach(FocusRitualType.allCases, id: \.self) { type in
                ritualTypeButton(for: type)
            }
        }
        .frame(width: 240)
    }
    
    private func ritualTypeButton(for type: FocusRitualType) -> some View {
        let isSelected = ritualType == type
        let accentColor = typeAccentColor(for: type)
        let backgroundOpacity = isSelected ? 0.26 : 0.12
        let strokeOpacity = isSelected ? 0.55 : 0.24
        
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                ritualType = type
            }
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
        } label: {
            HStack(spacing: 6) {
                Image(systemName: type == .morning ? "sunrise.fill" : "moon.stars.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(type.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accentColor.opacity(backgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accentColor.opacity(strokeOpacity), lineWidth: isSelected ? 1.4 : 1)
            )
            .foregroundStyle(isSelected ? Color.white : glassColorSystem.textSecondary())
            .shadow(color: accentColor.opacity(isSelected ? 0.20 : 0.0), radius: isSelected ? 12 : 0, y: isSelected ? 6 : 0)
        }
        .buttonStyle(.plain)
    }
    
    private var nudgeIndicator: some View {
        Button {
            // Handle nudge tap
        } label: {
            Image(systemName: "bell.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(glassColorSystem.emotionalAccent())
                .padding(8)
                .background(
                    Circle()
                        .fill(glassColorSystem.emotionalAccent().opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .help("You have a reflection reminder")
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var ritualsContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            if let nudge = smartNudgeService.latestNudge,
               nudge.trigger == .reflectionReminder {
                nudgeCard(nudge)
            }
            
            // Pattern suggestions
            if !patternSuggestions.isEmpty && !isRitualActive {
                patternSuggestionsCard
            }
            
            ritualProgressCard
            
            if isRitualActive {
                ritualStepsSection
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            if !isRitualActive && !completedSteps.isEmpty && steps.allSatisfy({ completedSteps.contains($0.id) }) {
                reflectionSection
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            ritualHistorySection
        }
        .animation(.easeInOut(duration: 0.24), value: isRitualActive)
        .animation(.easeInOut(duration: 0.24), value: ritualType)
    }
    
    private var patternSuggestionsCard: some View {
        DashboardTile(accent: AuroraToneKit.accentColor(for: AuroraToneKit.tone(for: ritualType)), padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuroraToneKit.accentColor(for: AuroraToneKit.tone(for: ritualType)))
                    
                    Text("Insight")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                ForEach(patternSuggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.message)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Spacer()
                            
                            Button("Dismiss") {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    patternSuggestions.removeAll { $0.id == suggestion.id }
                                }
                            }
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(glassColorSystem.backgroundElevated().opacity(0.5))
                    )
                }
            }
        }
    }
    
    // MARK: - Ritual Progress Card
    
    private var ritualProgressCard: some View {
        DashboardTile(accent: typeAccentColor(for: ritualType), padding: 24) {
            VStack(spacing: 20) {
                if isRitualActive {
                    activeRitualView
                } else if let ritual = currentRitual, ritual.status == .completed {
                    completedRitualView(ritual: ritual)
                } else {
                    idleRitualView
                }
            }
        }
    }
    
    private var idleRitualView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(typeAccentGradient(for: ritualType).opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: ritualType == .morning ? "sunrise.fill" : "moon.stars.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(typeAccentGradient(for: ritualType))
            }
            
            VStack(spacing: 8) {
                Text("Start \(ritualType.displayName)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text(ritualType == .morning 
                     ? "Begin your morning focus ritual" 
                     : "Begin your evening reflection")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .multilineTextAlignment(.center)
            }
            
            GlassButton(
                "Start Ritual",
                icon: "play.fill",
                style: .pill,
                role: .primary
            ) {
                startRitual()
            }
        }
    }
    
    private var activeRitualView: some View {
        VStack(spacing: 20) {
            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(glassColorSystem.borderColor().opacity(0.2), lineWidth: 10)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        typeAccentGradient(for: ritualType),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.35, bounce: 0.4), value: progress)
                
                VStack(spacing: 4) {
                    Text(formatDuration(ritualDuration))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .monospacedDigit()
                    
                    Text("\(completedSteps.count)/\(steps.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            
            VStack(spacing: 12) {
                Text("Ritual in progress")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Step \(completedSteps.count + 1) of \(steps.count)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                if isTimerPaused {
                    Text("Timer paused")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary().opacity(0.7))
                }
            }
            
            HStack(spacing: 12) {
                if ritualStartTime != nil {
                    GlassButton(
                        isTimerPaused ? "Resume" : "Pause",
                        icon: isTimerPaused ? "play.fill" : "pause.fill",
                        style: .pill,
                        role: .accent
                    ) {
                        if isTimerPaused {
                            resumeRitual()
                        } else {
                            pauseRitual()
                        }
                    }
                }
                
                GlassButton(
                    "End Early",
                    icon: "stop.fill",
                    style: .pill,
                    role: .surface
                ) {
                    endRitualEarly()
                }
            }
        }
    }
    
    private func completedRitualView(ritual: FocusRitual) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.kosmicGreen.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.kosmicGreen)
            }
            
            VStack(spacing: 8) {
                Text("Ritual Complete")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("\(ritual.streakCount) day streak")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kosmicGreen)
            }
        }
    }
    
    // MARK: - Ritual Steps
    
    private var ritualStepsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Ritual Steps")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Spacer()
                
                Text("\(completedSteps.count)/\(steps.count) complete")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            VStack(spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    interactiveStepCard(step: step, index: index)
                }
            }
        }
    }
    
    private func interactiveStepCard(step: RitualStep, index: Int) -> some View {
        let isCompleted = completedSteps.contains(step.id)
        let isHovered = isHoveredStep == step.id
        let isInteractive = !isCompleted && canInteractWithStep(step)
        
        return DashboardTile(
            accent: isCompleted ? Color.kosmicGreen : typeAccentColor(for: ritualType),
            padding: 20
        ) {
            HStack(spacing: 16) {
                // Step number/check indicator
                ZStack {
                    Circle()
                        .fill(isCompleted 
                              ? AnyShapeStyle(Color.kosmicGreen.opacity(0.2))
                              : AnyShapeStyle(typeAccentGradient(for: ritualType).opacity(0.15)))
                        .frame(width: 44, height: 44)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.kosmicGreen)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(typeAccentColor(for: ritualType))
                    }
                }
                .animation(.spring(duration: 0.25), value: isCompleted)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: step.type.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isCompleted ? Color.kosmicGreen : typeAccentColor(for: ritualType))
                        
                        Text(step.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                            .strikethrough(isCompleted)
                    }
                    
                    Text(step.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(2)
                    
                    if isInteractive && !isCompleted {
                        Text("Tap to open")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(typeAccentColor(for: ritualType).opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Interactive completion button
                Button {
                    withAnimation(.spring(duration: 0.25, bounce: 0.4)) {
                        if isCompleted {
                            completedSteps.remove(step.id)
                        } else {
                            handleStepTap(step)
                        }
                    }
                    #if canImport(UIKit)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    #endif
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(isCompleted ? Color.kosmicGreen : glassColorSystem.textSecondary())
                        .symbolEffect(.bounce, value: isCompleted)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    isCompleted 
                    ? AnyShapeStyle(Color.kosmicGreen.opacity(0.4))
                    : AnyShapeStyle(typeAccentGradient(for: ritualType).opacity(isHovered ? 0.6 : 0.3)),
                    lineWidth: isCompleted ? 1.6 : (isHovered ? 1.2 : 0.8)
                )
                .animation(.spring(duration: 0.2), value: isCompleted)
                .animation(.spring(duration: 0.2), value: isHovered)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: (isCompleted ? Color.kosmicGreen : typeAccentColor(for: ritualType)).opacity(isHovered ? 0.25 : 0.12),
            radius: isHovered ? 16 : 10,
            x: 0,
            y: isHovered ? 8 : 4
        )
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) {
                isHoveredStep = hovering ? step.id : nil
            }
        }
        .onTapGesture {
            if isInteractive && !isCompleted {
                handleStepTap(step)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 && !isCompleted {
                        // Swipe left to complete
                        withAnimation(.spring(duration: 0.25, bounce: 0.4)) {
                            handleStepComplete(step)
                        }
                    }
                }
        )
    }
    
    private func canInteractWithStep(_ step: RitualStep) -> Bool {
        switch step.type {
        case .breathing, .taskPreview, .gratitude, .intention:
            return true
        case .summary:
            return false // Auto-triggered
        }
    }
    
    private func handleStepTap(_ step: RitualStep) {
        switch step.type {
        case .breathing:
            currentBreathingStep = step
            showBreathingModal = true
        case .taskPreview:
            if ritualType == .morning {
                // Morning: Navigate to Focus Gravity
                handleStepComplete(step)
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusGravity)
            } else {
                // Evening: Open outcomes drawer
                handleStepComplete(step)
                showOutcomesDrawer = true
            }
        case .gratitude:
            handleStepComplete(step)
            openGratitudeJournal()
        case .intention:
            if ritualType == .evening {
                // Evening: Open reflection journal
                handleStepComplete(step)
                openReflectionJournal()
            } else {
                // Morning: Just complete
                handleStepComplete(step)
            }
        case .summary:
            // Auto-triggered when all steps done
            break
        }
    }
    
    private func openGratitudeJournal() {
        let tone = AuroraToneKit.tone(for: ritualType)
        let title = ritualType == .morning ? "Gratitude Reflection" : "Evening Gratitude"
        let prompt = ritualType == .morning
            ? "What are you grateful for today? What's one thing that's going well?"
            : "What went well today? What are you grateful for?"
        
        journalDraft = JournalDraft(
            title: title,
            content: prompt,
            entryDate: Date(),
            entryType: .reflection,
            mood: .none,
            tags: ["ritual", ritualType.rawValue, "gratitude"]
        )
        showGratitudeJournal = true
    }
    
    private func openReflectionJournal() {
        let title = "Daily Reflection - \(Date().formatted(date: .abbreviated, time: .omitted))"
        let prompt = "How did today go? What did you accomplish?"
        
        journalDraft = JournalDraft(
            title: title,
            content: prompt,
            entryDate: Date(),
            entryType: .reflection,
            mood: .none,
            tags: ["ritual", "evening", "reflection"]
        )
        showReflectionJournal = true
    }
    
    // MARK: - Reflection Section
    
    private var reflectionSection: some View {
        ReflectionSummaryView(
            ritualType: ritualType,
            reflectionText: reflectionText,
            onJournalTap: {
                withAnimation(GlassMotion.Easing.modalOpen) {
                    showJournalView = true
                }
            }
        )
    }
    
    // MARK: - History Section
    
    private var ritualHistorySection: some View {
        RitualHistoryView(ritualType: ritualType)
    }
    
    // MARK: - Nudge Card
    
    @ViewBuilder
    private func nudgeCard(_ nudge: SmartNudge) -> some View {
        DashboardTile(accent: glassColorSystem.emotionalAccent(), padding: 20) {
            HStack(spacing: 14) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(glassColorSystem.emotionalAccent())
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(glassColorSystem.emotionalAccent().opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(nudge.message)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    if let detail = nudge.detail {
                        Text(detail)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Drawer Overlays
    
    private var drawerVisible: Bool {
        showJournalView || showBreathingModal || showOutcomesDrawer || showSummaryDrawer || showGratitudeJournal || showReflectionJournal
    }
    
    @ViewBuilder
    private var drawerOverlays: some View {
        if showBreathingModal, let step = currentBreathingStep {
            BreathingExerciseModal(
                isPresented: $showBreathingModal,
                ritualType: ritualType,
                onComplete: {
                    handleStepComplete(step)
                },
                onSkip: {
                    handleStepComplete(step)
                }
            )
            .zIndex(1000)
        }
        
        if showOutcomesDrawer {
            DailyOutcomesDrawer(
                isPresented: $showOutcomesDrawer,
                ritualType: ritualType
            )
            .zIndex(999)
        }
        
        if showSummaryDrawer {
            RitualSummaryDrawer(
                isPresented: $showSummaryDrawer,
                ritualType: ritualType,
                summary: ritualSummary ?? "",
                onSaveToJournal: {
                    saveSummaryToJournal()
                }
            )
            .zIndex(998)
        }
        
        if showGratitudeJournal, let draft = journalDraft {
            JournalDetailDrawer(
                mode: .create,
                existingJournal: nil,
                template: nil,
                initialDraft: draft,
                isPresented: $showGratitudeJournal,
                onCommit: { committedDraft in
                    saveJournalDraft(committedDraft)
                    journalDraft = nil
                },
                onCancel: {
                    journalDraft = nil
                }
            )
            .zIndex(997)
        }
        
        if showReflectionJournal, let draft = journalDraft {
            JournalDetailDrawer(
                mode: .create,
                existingJournal: nil,
                template: nil,
                initialDraft: draft,
                isPresented: $showReflectionJournal,
                onCommit: { committedDraft in
                    saveJournalDraft(committedDraft)
                    journalDraft = nil
                },
                onCancel: {
                    journalDraft = nil
                }
            )
            .zIndex(996)
        }
        
        if showJournalView {
            AuroraDrawer(isPresented: $showJournalView, title: "Reflect & Journal", icon: "book.closed") {
                UnifiedJournalView()
                    .padding(.horizontal, -24)
            }
            .transition(.move(edge: .trailing))
            .zIndex(995)
        }
    }
    
    private func saveJournalDraft(_ draft: JournalDraft) {
        let journal = Journal(
            title: draft.title,
            content: draft.content,
            entryDate: draft.entryDate,
            entryType: draft.entryType,
            mood: draft.mood,
            tags: draft.tags,
            projectId: draft.projectId,
            areaId: draft.areaId,
            linkedNoteIds: draft.linkedNoteIds,
            linkedAreaIds: draft.linkedAreaIds
        )
        journal.author = draft.author
        modelContext.insert(journal)
        try? modelContext.save()
    }
    
    private func saveSummaryToJournal() {
        guard let summary = ritualSummary else { return }
        let journal = Journal(
            title: "\(ritualType.displayName) Summary - \(Date().formatted(date: .abbreviated, time: .omitted))",
            content: summary,
            entryDate: Date(),
            entryType: .reflection,
            mood: .none,
            tags: ["ritual", ritualType.rawValue, "summary"]
        )
        journal.author = .aurora
        modelContext.insert(journal)
        try? modelContext.save()
    }
    
    // MARK: - Helper Functions
    
    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(steps.count)
    }
    
    private func typeAccentColor(for type: FocusRitualType) -> Color {
        let tone = AuroraToneKit.tone(for: type)
        return AuroraToneKit.accentColor(for: tone)
    }
    
    private func typeAccentGradient(for type: FocusRitualType) -> LinearGradient {
        let tone = AuroraToneKit.tone(for: type)
        return AuroraToneKit.accentGradient(for: tone)
    }
    
    private func ritualMicroTone(for type: FocusRitualType) -> AuroraTone {
        AuroraToneKit.tone(for: type)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func loadSteps(for type: FocusRitualType) {
        steps = RitualStepConfiguration.steps(for: type)
        completedSteps.removeAll()
    }
    
    @MainActor
    private func loadCurrentRitual(for type: FocusRitualType) async {
        ritualManager.refreshRitualSchedule(modelContext: modelContext)
        
        let descriptor = FetchDescriptor<FocusRitual>()
        let allRituals = (try? modelContext.fetch(descriptor)) ?? []
        currentRitual = allRituals.first { $0.type == type }
        
        if let ritual = currentRitual {
            // DO NOT auto-start rituals - only set active if user explicitly started it in this session
            // isRitualActive = ritual.status == .inProgress  // REMOVED: Don't auto-start
            
            if ritual.status == .completed {
                var completionDescriptor = FetchDescriptor<RitualCompletion>(
                    sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
                )
                completionDescriptor.fetchLimit = 1
                if let latestCompletion = try? modelContext.fetch(completionDescriptor).first,
                   latestCompletion.ritualType == type {
                    reflectionText = latestCompletion.aiRecap ?? latestCompletion.userNotes
                }
            }
        } else {
            // Ensure ritual is not active if there's no current ritual
            isRitualActive = false
        }
        
        // Load pattern suggestions
        loadPatternSuggestions(for: type)
    }
    
    private func loadPatternSuggestions(for type: FocusRitualType) {
        // Get current Focus Gravity state
        let priorityItems = PriorityEngine.shared.getTopObjects(limit: 10, modelContext: modelContext)
        let activeProjects = priorityItems.filter { $0.objectType == "project" }.count
        let highPriorityTasks = priorityItems.filter { $0.objectType == "task" }.count
        let hasProjectPeaks = !priorityItems.filter { $0.objectType == "project" }.isEmpty
        
        // Find matching patterns
        let patterns = RitualPatternLearner.shared.patternsMatchingCurrentState(
            for: type,
            activeProjects: activeProjects,
            highPriorityTasks: highPriorityTasks,
            hasProjectPeaks: hasProjectPeaks,
            modelContext: modelContext
        )
        
        // Generate suggestions
        patternSuggestions = RitualPatternLearner.shared.generateSuggestions(
            for: type,
            patterns: patterns,
            modelContext: modelContext
        )
    }
    
    private func startRitual() {
        guard let ritual = currentRitual else {
            let schedule = RitualSettings.shared.nextWindow(for: ritualType)
            let newRitual = FocusRitual(
                type: ritualType,
                scheduledFor: Date(),
                windowEnd: schedule.end
            )
            modelContext.insert(newRitual)
            currentRitual = newRitual
            ritualManager.triggerRitual(newRitual, modelContext: modelContext)
            isRitualActive = true
            ritualStartTime = nil
            isTimerPaused = false
            return
        }
        
        ritualManager.triggerRitual(ritual, modelContext: modelContext)
        isRitualActive = true
        ritualStartTime = nil
        isTimerPaused = false
        
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    private func pauseRitual() {
        stopRitualTimer()
        isTimerPaused = true
        
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    private func resumeRitual() {
        guard let startTime = ritualStartTime else { return }
        
        // Adjust start time to account for paused duration
        let pausedDuration = Date().timeIntervalSince(startTime) - ritualDuration
        ritualStartTime = Date().addingTimeInterval(-ritualDuration)
        
        isTimerPaused = false
        startRitualTimer()
        
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    private func endRitualEarly() {
        guard let ritual = currentRitual else { return }
        
        stopRitualTimer()
        isTimerPaused = false
        
        let completedCount = completedSteps.count
        let totalSteps = steps.count
        let outcome: RitualCompletionOutcome = completedCount >= totalSteps / 2 ? .completed : .deferred
        let finalDuration = ritualDuration
        
        let input = RitualCompletionInput(
            outcome: outcome,
            completedAt: Date(),
            duration: finalDuration,
            userNotes: nil,
            aiRecap: nil,
            highlights: ["Completed \(completedCount) of \(totalSteps) steps"],
            focusItemIds: [],
            taskStatusCounts: [:],
            cpsBoostApplied: false,
            momentumDelta: Double(completedCount) / Double(totalSteps) * 0.1,
            metadata: ["source": "rituals-v2", "completed_steps": "\(completedCount)"]
        )
        
        _ = ritualManager.completeRitual(ritual, input: input, modelContext: modelContext)
        isRitualActive = false
        ritualStartTime = nil
        
        generateReflection()
    }
    
    private func handleStepComplete(_ step: RitualStep) {
        if ritualStartTime == nil && completedSteps.isEmpty {
            ritualStartTime = Date()
            startRitualTimer()
        }
        
        completedSteps.insert(step.id)
        
        if steps.allSatisfy({ completedSteps.contains($0.id) }) {
            stopRitualTimer()
            completeRitual()
        }
    }
    
    private func completeRitual() {
        guard let ritual = currentRitual else { return }
        
        stopRitualTimer()
        isTimerPaused = false
        
        let finalDuration = ritualDuration
        
        // Capture step completion data
        let completedStepIds = steps.filter { completedSteps.contains($0.id) }.map { $0.id.uuidString }
        let skippedStepIds = steps.filter { !completedSteps.contains($0.id) }.map { $0.id.uuidString }
        let stepOrder = steps.enumerated().filter { completedSteps.contains($0.element.id) }.map { String($0.offset) }
        
        // Capture Focus Gravity metrics
        let priorityItems = PriorityEngine.shared.getTopObjects(limit: 10, modelContext: modelContext)
        let activeProjectCount = priorityItems.filter { $0.objectType == "project" }.count
        let highPriorityTaskCount = priorityItems.filter { $0.objectType == "task" }.count
        let projectIds = priorityItems.filter { $0.objectType == "project" }.map { $0.objectId.uuidString }
        
        // Build metadata
        var metadata: [String: String] = [
            "source": "rituals-v2",
            "completed_steps": completedStepIds.joined(separator: ","),
            "skipped_steps": skippedStepIds.joined(separator: ","),
            "completion_order": stepOrder.joined(separator: ","),
            "fg_active_projects": String(activeProjectCount),
            "fg_high_priority_tasks": String(highPriorityTaskCount),
            "fg_project_peaks": projectIds.joined(separator: ",")
        ]
        
        // Add step durations if available
        if let startTime = ritualStartTime {
            let totalDuration = finalDuration
            let avgStepDuration = completedStepIds.isEmpty ? 0 : totalDuration / Double(completedStepIds.count)
            metadata["avg_step_duration"] = String(format: "%.0f", avgStepDuration)
        }
        
        let input = RitualCompletionInput(
            outcome: .completed,
            completedAt: Date(),
            duration: finalDuration,
            userNotes: nil,
            aiRecap: nil,
            highlights: ["Completed all ritual steps"],
            focusItemIds: [],
            taskStatusCounts: [:],
            cpsBoostApplied: ritualType == .morning,
            momentumDelta: 0.15,
            metadata: metadata
        )
        
        _ = ritualManager.completeRitual(ritual, input: input, modelContext: modelContext)
        isRitualActive = false
        ritualStartTime = nil
        
        generateAuroraSummary()
        
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func generateAuroraSummary() {
        let tone = AuroraToneKit.tone(for: ritualType)
        let promptPrefix = AuroraToneKit.promptPrefix(for: tone)
        let toneDescription = AuroraToneKit.summaryTone(for: tone)
        
        // Get behavioral patterns for context
        let priorityItems = PriorityEngine.shared.getTopObjects(limit: 10, modelContext: modelContext)
        let activeProjects = priorityItems.filter { $0.objectType == "project" }.count
        let highPriorityTasks = priorityItems.filter { $0.objectType == "task" }.count
        let hasProjectPeaks = !priorityItems.filter { $0.objectType == "project" }.isEmpty
        
        let patterns = RitualPatternLearner.shared.patternsMatchingCurrentState(
            for: ritualType,
            activeProjects: activeProjects,
            highPriorityTasks: highPriorityTasks,
            hasProjectPeaks: hasProjectPeaks,
            modelContext: modelContext
        )
        
        // Build pattern context for Aurora
        var patternContext = ""
        if !patterns.isEmpty {
            let patternDescriptions = patterns.map { $0.description }.joined(separator: "; ")
            patternContext = " Behavioral context: The user shows these patterns: \(patternDescriptions). Reference these patterns naturally in your summary, focusing on 'how the user behaved' not just 'what was done.'"
        }
        
        let prompt = ritualType == .morning
            ? "Generate a brief, energetic morning summary (2-3 sentences) starting with '\(promptPrefix).' Focus on clarity, intention, and what they should prioritize today. Be forward-looking and motivational. Use a \(toneDescription) tone.\(patternContext) If patterns are mentioned, infer what they might mean for focus fatigue or momentum bursts."
            : "Generate a brief, gentle evening summary (2-3 sentences) starting with '\(promptPrefix).' Acknowledge what moved, what resisted, and offer gentle insight for tomorrow. Be reflective and calming. Use a \(toneDescription) tone.\(patternContext) If patterns are mentioned, infer what they might mean for focus fatigue or momentum bursts."
        
        _Concurrency.Task {
            do {
                let response = try await CoreResponseService.shared.generateResponse(
                    for: prompt,
                    modelContext: modelContext,
                    toneContext: tone
                )
                await MainActor.run {
                    ritualSummary = response
                    showSummaryDrawer = true
                }
            } catch {
                await MainActor.run {
                    ritualSummary = ritualType == .morning
                        ? "\(promptPrefix). Today is a fresh canvas—focus on clarity and intention. You've set the foundation with your morning ritual, now channel that energy into your top priorities."
                        : "\(promptPrefix). Today had its moments. Tomorrow is a fresh start—take what you learned and move forward with intention."
                    showSummaryDrawer = true
                }
            }
        }
    }
    
    private func startRitualTimer() {
        guard !isTimerPaused else { return }
        stopRitualTimer()
        guard let startTime = ritualStartTime else { return }
        
        // Use Task instead of Timer to avoid weak self issue
        ritualTimerTask = Task { @MainActor in
            while !isTimerPaused, let currentStartTime = ritualStartTime {
                ritualDuration = Date().timeIntervalSince(currentStartTime)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Check if task was cancelled
                if Task.isCancelled {
                    break
                }
            }
        }
    }
    
    private func stopRitualTimer() {
        ritualTimerTask?.cancel()
        ritualTimerTask = nil
    }
    
    private func generateReflection() {
        let prompt = ritualType == .morning
            ? "Generate a brief, encouraging morning reflection (1-2 sentences) for someone who completed their morning ritual. Focus on clarity and intention. Be warm and supportive."
            : "Generate a brief, reflective evening summary (1-2 sentences) for someone who completed their evening ritual. Acknowledge what moved and what resisted. Be gentle and insightful."
        
        _Concurrency.Task {
            do {
                let response = try await CoreResponseService.shared.generateResponse(
                    for: prompt,
                    modelContext: modelContext
                )
                await MainActor.run {
                    reflectionText = response
                }
            } catch {
                await MainActor.run {
                    reflectionText = ritualType == .morning
                        ? "You seem calmer than usual this morning — focus flow is building."
                        : "Today had its moments. Tomorrow is a fresh start."
                }
            }
        }
    }
}

#Preview {
    do {
        let container = try ModelContainer(
            for: FocusRitual.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return RitualsViewV2()
            .environmentObject(GlassColorSystem())
            .modelContainer(container)
    } catch {
        return Text("Preview unavailable")
    }
}
