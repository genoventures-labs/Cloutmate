//
//  UnifiedFocusModeView.swift
//  Cloutmate
//
//  Focus Mode V2 - Unified Main View
//

import SwiftUI
import SwiftData
import AppKit
import Combine
import CloutmateShared

struct UnifiedFocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var activeSession: FocusSession?
    @State private var selectedFilter: FocusFilter = .session
    @State private var durationMode: DurationMode = .pomodoro
    @State private var showObjectiveDrawer = false
    @State private var showAnalyticsDrawer = false
    @State private var showAuroraInsights = false
    @State private var streakCount: Int = 0
    @State private var cpsScore: Double?
    @State private var currentTime = Date()
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var lastRefreshTime = Date()
    @State private var pendingSessionParams: PendingFocusSessionParams?
    
    // Objective drawer state
    @State private var objective: String = ""
    @State private var selectedDuration: TimeInterval = 1800
    @State private var reflectAfterSession: Bool = true
    
    // Calm Mode
    @State private var isCalmModeEnabled: Bool = UserDefaults.standard.bool(forKey: "focusCalmModeEnabled")
    @State private var breathingPhase: CGFloat = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                FocusHeaderView(
                    activeSession: activeSession,
                    selectedFilter: selectedFilter,
                    onFilterChange: { selectedFilter = $0 },
                    onStartSession: {
                        showObjectiveDrawer = true
                    },
                    onPauseSession: pauseSession,
                    onEndSession: endSession,
                    onSetObjective: {
                        showObjectiveDrawer = true
                    },
                    onOpenAuroraInsights: {
                        showAuroraInsights = true
                    }
                )
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
                
                // Main Content
                HStack(spacing: 20) {
                    // Session Panel (Left)
                    VStack {
                        FocusSessionPanel(
                            session: activeSession,
                            streakCount: streakCount,
                            cpsScore: cpsScore,
                            durationMode: durationMode,
                            onDurationModeChange: { durationMode = $0 }
                        )
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Sidebar (Right)
                    FocusSidebar(
                        session: activeSession,
                        onLogTone: logTone
                    )
                    .frame(width: 320)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .coordinateSpace(name: "scroll")
        .onReceive(timer) { _ in
            currentTime = Date()
            // Periodically refresh to catch expired sessions (every 30 seconds)
            if currentTime.timeIntervalSince(lastRefreshTime) >= 30 {
                refreshData()
                lastRefreshTime = currentTime
            }
        }
        .task {
            refreshData()
        }
        .onAppear {
            // Refresh on appear to catch any stale sessions
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionStarted)) { notification in
            // Immediately refresh when a session starts
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionStatusChanged)) { _ in
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startPendingFocusSession)) { notification in
            // Handle pending session from task/project cards
            // Open drawer with pre-filled values instead of starting immediately
            if let params = notification.object as? PendingFocusSessionParams {
                pendingSessionParams = params
                // Pre-fill the drawer with the pending session params
                objective = params.objective
                selectedDuration = params.plannedDuration
                // Only open drawer if we're already on the Focus Mode tab
                // Don't auto-open when switching tabs - let user manually start
            }
        }
        .sheet(isPresented: $showObjectiveDrawer) {
            FocusObjectiveDrawer(
                objective: $objective,
                selectedDuration: $selectedDuration,
                reflectAfterSession: $reflectAfterSession,
                onSave: { obj, dur, targetId, targetType, reflect in
                    // User confirmed - start the session
                    startSession(
                        objective: obj,
                        duration: dur,
                        targetObjectId: targetId,
                        targetObjectType: targetType,
                        reflectAfterSession: reflect
                    )
                    // Clear pending params after starting
                    pendingSessionParams = nil
                }
            )
            .onDisappear {
                // If drawer is dismissed without saving, clear pending params
                pendingSessionParams = nil
            }
        }
        .sheet(isPresented: $showAnalyticsDrawer) {
            FocusAnalyticsDrawer()
        }
        .sheet(isPresented: $showAuroraInsights) {
            FocusAnalyticsDrawer()
        }
    }
    
    // MARK: - Actions
    
    private func startSession(
        objective: String,
        duration: TimeInterval,
        targetObjectId: UUID?,
        targetObjectType: String?,
        reflectAfterSession: Bool
    ) {
        do {
            let session = try FocusSessionService.shared.startSession(
                objective: objective,
                plannedDuration: duration,
                targetObjectId: targetObjectId,
                targetObjectType: targetObjectType,
                modelContext: modelContext
            )
            activeSession = session
            refreshData()
            
            // Haptic feedback
            let generator = NSHapticFeedbackManager.defaultPerformer
            generator.perform(.generic, performanceTime: .default)
        } catch {
            print("Failed to start session: \(error)")
        }
    }
    
    private func pauseSession() {
        // Note: FocusSessionService doesn't have a pause method yet
        // For now, we'll just update the UI state
        // In a full implementation, we'd add pause/resume to the service
    }
    
    private func endSession() {
        guard let session = activeSession else { return }
        
        // Show completion sheet or directly end
        do {
            _ = try FocusSessionService.shared.commitSession(
                completed: true,
                notes: nil,
                modelContext: modelContext
            )
            activeSession = nil
            refreshData()
            
            // Haptic feedback
            let generator = NSHapticFeedbackManager.defaultPerformer
            generator.perform(.generic, performanceTime: .default)
        } catch {
            print("Failed to end session: \(error)")
        }
    }
    
    private func logTone(_ tone: EmotionalState) {
        // Log tone to journal/insights
        // For now, we'll create a simple journal entry
        // In a full implementation, we'd use AdaptiveJournalService
        
        // Haptic feedback
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
    }
    
    private func refreshData() {
        // Always refresh active session from database
        let fetchedSession = FocusSessionService.shared.getActiveSession(modelContext: modelContext)
        
        // Update if session changed (nil to session, session to nil, or different session)
        if fetchedSession?.id != activeSession?.id {
            activeSession = fetchedSession
        }
        
        streakCount = FocusSessionService.shared.getStreakCount(modelContext: modelContext)
        
        if let session = activeSession,
           let targetId = session.targetObjectId {
            cpsScore = PriorityEngine.shared.getScoreValue(for: targetId, modelContext: modelContext)
        } else {
            cpsScore = nil
        }
    }
    
    private func tryStartPendingSession() {
        // Only start if we have pending params and no active session
        guard let params = pendingSessionParams,
              activeSession == nil else {
            return
        }
        
        // Start the session with the provided parameters
        do {
            let session = try FocusSessionService.shared.startSession(
                objective: params.objective,
                plannedDuration: params.plannedDuration,
                targetObjectId: params.targetObjectId,
                targetObjectType: params.targetObjectType,
                modelContext: modelContext
            )
            // Update state immediately
            activeSession = session
            pendingSessionParams = nil // Clear pending params after starting
            
            // Force immediate refresh to ensure UI updates
            DispatchQueue.main.async {
                self.refreshData()
            }
        } catch {
            print("Failed to start pending focus session: \(error)")
            pendingSessionParams = nil // Clear on error too
        }
    }
    
    // MARK: - Calm Mode
    
    @ViewBuilder
    private var breathingDotIndicator: some View {
        Circle()
            .fill(Color.kosmicBlue.opacity(0.6))
            .frame(width: 12 + breathingPhase * 4, height: 12 + breathingPhase * 4)
            .opacity(0.7 + breathingPhase * 0.3)
    }
    
    private func startBreathingAnimation() {
        guard !reduceMotion else { return }
        withAnimation(
            Animation.easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
        ) {
            breathingPhase = 1.0
        }
    }
}

#Preview {
    UnifiedFocusModeView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [FocusSession.self])
}

