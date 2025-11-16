//
//  FocusModeView.swift
//  Cloutmate
//
//  V2: Focus Mode - Aurora Adaptive Environment
//  Immersive focus sessions with adaptive visuals and breathing rhythm
//

import SwiftUI
import SwiftData
import Combine
import CloutmateShared

struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var activeSession: FocusSession?
    @State private var recentSessions: [FocusSession] = []
    @State private var suggestedTargets: [PriorityItem] = []
    
    // V2: Entry screen and customization
    @State private var showCustomizeDrawer = false
    @State private var showLastSessionSummary = false
    @State private var breathingEnabled = false
    @State private var defaultBreathingEnabled = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // V2: Session management
    @State private var newObjective = ""
    @State private var selectedDuration: TimeInterval = 1800  // 30 min
    @State private var selectedTargetId: UUID?
    @State private var selectedTargetType: String?
    
    // V2: Completion
    @State private var showCompletionDrawer = false
    @State private var completedSession: FocusSession?
    @State private var sessionMetrics: FocusSessionMetrics?
    
    @State private var currentTime = Date()
    @State private var pendingSessionParams: PendingFocusSessionParams?
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if activeSession == nil {
                // Entry Screen (Idle State)
                entryScreen
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if let session = activeSession {
                // Active Session View
                FocusModeActiveView(
                    session: session,
                    breathingEnabled: breathingEnabled,
                    onPause: pauseSession,
                    onResume: resumeSession,
                    onSkip: skipSession,
                    onEnd: endSession
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Customization Drawer
            if showCustomizeDrawer {
                customizationDrawer
            }
            
            // Completion Drawer
            if showCompletionDrawer, let session = completedSession, let metrics = sessionMetrics {
                FocusModeCompletionDrawer(
                    isPresented: $showCompletionDrawer,
                    session: session,
                    metrics: metrics,
                    onAddReflection: { reflection in
                        addReflection(reflection, to: session)
                    },
                    onReturnHome: {
                        returnToEntry()
                    },
                    onStartAnother: {
                        startAnotherSession(from: session)
                    }
                )
            }
            
            // Last Session Summary Drawer
            if showLastSessionSummary, let lastSession = recentSessions.first {
                lastSessionSummaryDrawer(for: lastSession)
            }
            
            // Error Alert
            if showError, let error = errorMessage {
                errorAlert(message: error)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .task {
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startPendingFocusSession)) { notification in
            if let params = notification.object as? PendingFocusSessionParams {
                pendingSessionParams = params
                tryStartPendingSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .currentTabUpdated)) { notification in
            if let tab = notification.object as? TabIdentifier,
               tab == .focusMode {
                tryStartPendingSession()
            }
        }
        .onAppear {
            tryStartPendingSession()
            loadBreathingPreference()
        }
    }
    
    // MARK: - Entry Screen
    
    private var entryScreen: some View {
        ZStack {
            // Dark gradient background with light shimmer
            ZStack {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                // Static light shimmer overlay
                AuroraPalette.linearGradient(for: colorScheme)
                    .opacity(0.12)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Title and subtitle
                VStack(spacing: 12) {
                    Text("Focus Mode")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 4)
                    
                    Text("Enter your deep work environment")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    GlassButton(
                        "Start Session",
                        icon: "play.fill",
                        style: .pill,
                        role: .primary
                    ) {
                        // If no objective is set, open customization drawer
                        if newObjective.isEmpty {
                            showCustomizeDrawer = true
                        } else {
                            startSession()
                        }
                    }
                    .frame(width: 200)
                    
                    GlassButton(
                        "Customize Session",
                        icon: "slider.horizontal.3",
                        style: .pill,
                        role: .accent
                    ) {
                        showCustomizeDrawer = true
                    }
                    .frame(width: 200)
                    
                    if let lastSession = recentSessions.first {
                        GlassButton(
                            "Last Session Summary",
                            icon: "chart.bar.fill",
                            style: .pill,
                            role: .surface
                        ) {
                            showLastSessionSummary = true
                        }
                        .frame(width: 200)
                    }
                }
                
                Spacer()
            }
            .padding(60)
        }
    }
    
    // MARK: - Customization Drawer
    
    private var customizationDrawer: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeCustomization()
                    }
                    .transition(.opacity)
                
                // Drawer
                VStack(spacing: 0) {
                    V2DrawerScaffold(
                        accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                        showsSidebar: false,
                        header: {
                            HStack {
                                Text("Customize Session")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                
                                Spacer()
                                
                                GlassButton(
                                    nil,
                                    icon: "xmark",
                                    style: .iconOnly,
                                    role: .surface
                                ) {
                                    closeCustomization()
                                }
                            }
                        },
                        content: {
                            VStack(alignment: .leading, spacing: 24) {
                                // Duration
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Duration")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    
                                    Picker("Duration", selection: $selectedDuration) {
                                        Text("15 min").tag(900.0)
                                        Text("30 min").tag(1800.0)
                                        Text("45 min").tag(2700.0)
                                        Text("1 hour").tag(3600.0)
                                        Text("2 hours").tag(7200.0)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                // Breathing rhythm toggle
                                DashboardTile(accent: .kosmicPurple) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Breathing Rhythm")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundStyle(glassColorSystem.textPrimary())
                                            
                                            Text("Sync with Aurora's Luminance Field")
                                                .font(.caption)
                                                .foregroundStyle(glassColorSystem.textSecondary())
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $breathingEnabled)
                                            .labelsHidden()
                                    }
                                }
                                
                                // Objective input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("What will you focus on?")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    
                                    TextField("e.g., Write blog post on AI tools", text: $newObjective)
                                        .textFieldStyle(.plain)
                                        .font(.body)
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                
                                // Start button
                                GlassButton(
                                    "Start Session",
                                    icon: "play.fill",
                                    style: .pill,
                                    role: .primary
                                ) {
                                    closeCustomization()
                                    startSession()
                                }
                                .disabled(newObjective.isEmpty)
                            }
                            .padding(.vertical, 8)
                        },
                        sidebar: { EmptyView() }
                    )
                }
                .frame(width: 500)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Methods
    
    private func refreshData() {
        activeSession = FocusSessionService.shared.getActiveSession(modelContext: modelContext)
        
        // Get recent sessions (excluding active ones, only completed/abandoned)
        let activeStatusRaw = "active"
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.statusRaw != activeStatusRaw
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        recentSessions = (try? modelContext.fetch(descriptor)) ?? []
        
        suggestedTargets = FocusSessionService.shared.suggestFocusTargets(limit: 5, modelContext: modelContext)
    }
    
    private func loadBreathingPreference() {
        // Load from UserDefaults or settings
        defaultBreathingEnabled = UserDefaults.standard.bool(forKey: "focusMode.breathingEnabled")
        breathingEnabled = defaultBreathingEnabled
    }
    
    private func saveBreathingPreference() {
        UserDefaults.standard.set(breathingEnabled, forKey: "focusMode.breathingEnabled")
    }
    
    private func startSession() {
        guard !newObjective.isEmpty else {
            showCustomizeDrawer = true
            return
        }
        
        // Check if Focus Mode is enabled
        let config = AIConfigService.shared.config
        guard config.featureFlags.focusModeEnabled else {
            errorMessage = "Focus Mode is not enabled. Please enable it in Settings → AI Configuration."
            showError = true
            return
        }
        
        do {
            let session = try FocusSessionService.shared.startSession(
                objective: newObjective,
                plannedDuration: selectedDuration,
                targetObjectId: selectedTargetId,
                targetObjectType: selectedTargetType,
                modelContext: modelContext
            )
            activeSession = session
            newObjective = ""
            showCustomizeDrawer = false
            
            // Save breathing preference
            saveBreathingPreference()
        } catch FocusSessionError.featureDisabled {
            errorMessage = "Focus Mode is not enabled. Please enable it in Settings → AI Configuration."
            showError = true
        } catch FocusSessionError.sessionAlreadyActive {
            errorMessage = "A focus session is already active. Please complete or abandon it first."
            showError = true
            refreshData() // Refresh to show the active session
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func pauseSession() {
        do {
            try FocusSessionService.shared.pauseSession(modelContext: modelContext)
            refreshData()
        } catch {
            print("Failed to pause session: \(error)")
        }
    }
    
    private func resumeSession() {
        do {
            try FocusSessionService.shared.resumeSession(modelContext: modelContext)
            refreshData()
        } catch {
            print("Failed to resume session: \(error)")
        }
    }
    
    private func skipSession() {
        do {
            _ = try FocusSessionService.shared.abandonSession(
                reason: "User skipped",
                modelContext: modelContext
            )
            refreshData()
        } catch {
            print("Failed to skip session: \(error)")
        }
    }
    
    private func endSession() {
        guard let session = activeSession else { return }
        
        do {
            let completed = try FocusSessionService.shared.commitSession(
                completed: true,
                notes: nil,
                itemsCompleted: [],
                modelContext: modelContext
            )
            
            // Calculate metrics
            let metrics = FocusSessionService.shared.calculateSessionMetrics(
                for: completed,
                modelContext: modelContext
            )
            
            // Check for early end and deliver nudge if needed
            if completed.actualDuration < completed.plannedDuration * 0.5 {
                SmartNudgeService.shared.deliverEarlyEndNudge(
                    session: completed,
                    plannedDuration: completed.plannedDuration,
                    actualDuration: completed.actualDuration,
                    modelContext: modelContext
                )
            }
            
            // Deliver post-session summary nudge
            SmartNudgeService.shared.deliverPostSessionNudge(
                session: completed,
                stabilityPercentage: metrics.focusStabilityPercentage,
                modelContext: modelContext
            )
            
            completedSession = completed
            sessionMetrics = metrics
            activeSession = nil
            
            // Refresh data to update recent sessions list
            refreshData()
            
            // Show completion drawer
            withAnimation(GlassMotion.Easing.modalOpen) {
                showCompletionDrawer = true
            }
        } catch {
            print("Failed to end session: \(error)")
        }
    }
    
    private func addReflection(_ reflection: String, to session: FocusSession) {
        // Update session notes with reflection
        session.notes = reflection
        do {
            try modelContext.save()
        } catch {
            print("Failed to save reflection: \(error)")
        }
    }
    
    private func returnToEntry() {
        completedSession = nil
        sessionMetrics = nil
        refreshData()
    }
    
    private func startAnotherSession(from previousSession: FocusSession) {
        // Pre-fill with previous objective
        newObjective = previousSession.objective
        selectedDuration = previousSession.plannedDuration
        selectedTargetId = previousSession.targetObjectId
        selectedTargetType = previousSession.targetObjectType
        
        completedSession = nil
        sessionMetrics = nil
        
        // Start new session
        startSession()
    }
    
    private func closeCustomization() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            showCustomizeDrawer = false
        }
    }
    
    private func tryStartPendingSession() {
        guard let params = pendingSessionParams,
              activeSession == nil else {
            return
        }
        if params.shouldAutoStart {
            do {
                let session = try FocusSessionService.shared.startSession(
                    objective: params.objective,
                    plannedDuration: params.plannedDuration,
                    targetObjectId: params.targetObjectId,
                    targetObjectType: params.targetObjectType,
                    modelContext: modelContext
                )
                activeSession = session
            } catch {
                print("Failed to start pending focus session: \(error)")
            }
            pendingSessionParams = nil
            refreshData()
        } else {
            newObjective = params.objective
            selectedDuration = params.plannedDuration
            pendingSessionParams = nil
            showCustomizeDrawer = true
        }
    }
    
    // MARK: - Last Session Summary Drawer
    
    @ViewBuilder
    private func lastSessionSummaryDrawer(for session: FocusSession) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(GlassMotion.Easing.modalOpen) {
                            showLastSessionSummary = false
                        }
                    }
                    .transition(.opacity)
                
                // Drawer
                VStack(spacing: 0) {
                    V2DrawerScaffold(
                        accentGradient: AuroraPalette.linearGradient(for: colorScheme),
                        showsSidebar: false,
                        header: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Last Session Summary")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    
                                    Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
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
                                    withAnimation(GlassMotion.Easing.modalOpen) {
                                        showLastSessionSummary = false
                                    }
                                }
                            }
                        },
                        content: {
                            VStack(alignment: .leading, spacing: 24) {
                                // Session Details
                                DashboardTile(accent: session.status == .completed ? .kosmicGreen : .kosmicBlue) {
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Image(systemName: session.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(session.status == .completed ? .kosmicGreen : .red)
                                            
                                            Text(session.objective)
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundStyle(glassColorSystem.textPrimary())
                                        }
                                        
                                        HStack(spacing: 24) {
                                            statCard(
                                                label: "Duration",
                                                value: session.durationFormatted,
                                                color: .kosmicBlue
                                            )
                                            
                                            statCard(
                                                label: "Status",
                                                value: session.status == .completed ? "Completed" : "Abandoned",
                                                color: session.status == .completed ? .kosmicGreen : .red
                                            )
                                        }
                                        
                                        if let notes = session.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.body)
                                                .foregroundStyle(glassColorSystem.textSecondary())
                                                .padding(.top, 8)
                                        }
                                    }
                                }
                                
                                // Metrics if available
                                if let stability = session.stabilityIndex {
                                    DashboardTile(accent: .kosmicPurple) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Session Metrics")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundStyle(glassColorSystem.textPrimary())
                                            
                                            HStack(spacing: 24) {
                                                statCard(
                                                    label: "Stability",
                                                    value: "\(Int(stability))%",
                                                    color: stability >= 70 ? .kosmicGreen : stability >= 40 ? .kosmicBlue : .red
                                                )
                                                
                                                if let avgLF = session.averageLF {
                                                    statCard(
                                                        label: "Emotional Avg",
                                                        value: String(format: "%.2f", avgLF),
                                                        color: .kosmicPurple
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        },
                        sidebar: { EmptyView() }
                    )
                }
                .frame(width: 500)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Error Alert
    
    @ViewBuilder
    private func errorAlert(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showError = false
                        errorMessage = nil
                    }
                }
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text("Focus Mode Setup Required")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                GlassButton(
                    "OK",
                    icon: "checkmark",
                    style: .pill,
                    role: .primary
                ) {
                    withAnimation {
                        showError = false
                        errorMessage = nil
                    }
                }
                .frame(width: 120)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(glassColorSystem.backgroundElevated().opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Helper Views
    
    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(glassColorSystem.textSecondary())
        }
    }
}

#Preview {
    FocusModeView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [FocusSession.self, PriorityScore.self], inMemory: true)
}



