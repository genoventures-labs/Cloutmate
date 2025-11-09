//
//  FocusModeView.swift
//  Cloutmate
//
//  Phase 4: Focus Mode MVP
//  UI for starting, managing, and completing focus sessions
//

import SwiftUI
import SwiftData
import Combine
import CloutmateShared

struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeSession: FocusSession?
    @State private var recentSessions: [FocusSession] = []
    @State private var suggestedTargets: [PriorityItem] = []
    
    @State private var showStartSheet = false
    @State private var showCompleteSheet = false
    @State private var newObjective = ""
    @State private var selectedDuration: TimeInterval = 1800  // 30 min
    @State private var completionNotes = ""
    @State private var sessionCompleted = true
    
    @State private var currentTime = Date()
    @State private var pendingSessionParams: PendingFocusSessionParams?
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Mode")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Deep work sessions with intelligent priority targeting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if activeSession == nil {
                    Button(action: { showStartSheet = true }) {
                        Label("Start Session", systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Active Session
                    if let session = activeSession {
                        ActiveSessionCard(
                            session: session,
                            currentTime: currentTime,
                            onComplete: { showCompleteSheet = true },
                            onAbandon: abandonSession
                        )
                        .padding(.horizontal)
                    }
                    
                    // Suggested Focus Targets
                    if !suggestedTargets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Focus Targets")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            ForEach(suggestedTargets.prefix(5)) { target in
                                SuggestedTargetRow(target: target, onSelect: {
                                    newObjective = target.title
                                    showStartSheet = true
                                })
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Recent Sessions
                    if !recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            ForEach(recentSessions.prefix(5)) { session in
                                SessionHistoryRow(session: session)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .task {
            refreshData()
        }
        .sheet(isPresented: $showStartSheet) {
            StartSessionSheet(
                objective: $newObjective,
                duration: $selectedDuration,
                onStart: startSession
            )
        }
        .sheet(isPresented: $showCompleteSheet) {
            CompleteSessionSheet(
                notes: $completionNotes,
                completed: $sessionCompleted,
                onComplete: completeSession
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .startPendingFocusSession)) { notification in
            // Store the pending session parameters
            if let params = notification.object as? PendingFocusSessionParams {
                pendingSessionParams = params
                // Try to start immediately if no active session
                tryStartPendingSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .currentTabUpdated)) { notification in
            // When tab switches to Focus Mode, try to start pending session
            if let tab = notification.object as? TabIdentifier,
               tab == .focusMode {
                tryStartPendingSession()
            }
        }
        .onAppear {
            // Also try when view appears (in case notification arrived before view loaded)
            tryStartPendingSession()
        }
    }
    
    private func refreshData() {
        activeSession = FocusSessionService.shared.getActiveSession(modelContext: modelContext)
        recentSessions = FocusSessionService.shared.getRecentSessions(limit: 10, modelContext: modelContext)
        suggestedTargets = FocusSessionService.shared.suggestFocusTargets(limit: 5, modelContext: modelContext)
    }
    
    private func tryStartPendingSession() {
        // Only start if we have pending params, no active session, and we're on Focus Mode tab
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
            activeSession = session
            pendingSessionParams = nil // Clear pending params after starting
            refreshData() // Refresh to show the new session
        } catch {
            print("Failed to start pending focus session: \(error)")
            pendingSessionParams = nil // Clear on error too
        }
    }
    
    private func startSession() {
        do {
            let session = try FocusSessionService.shared.startSession(
                objective: newObjective,
                plannedDuration: selectedDuration,
                modelContext: modelContext
            )
            activeSession = session
            newObjective = ""
            showStartSheet = false
        } catch {
            print("Failed to start session: \(error)")
        }
    }
    
    private func completeSession() {
        do {
            _ = try FocusSessionService.shared.commitSession(
                completed: sessionCompleted,
                notes: completionNotes.isEmpty ? nil : completionNotes,
                modelContext: modelContext
            )
            completionNotes = ""
            sessionCompleted = true
            showCompleteSheet = false
            refreshData()
        } catch {
            print("Failed to complete session: \(error)")
        }
    }
    
    private func abandonSession() {
        do {
            _ = try FocusSessionService.shared.abandonSession(
                reason: "User cancelled",
                modelContext: modelContext
            )
            refreshData()
        } catch {
            print("Failed to abandon session: \(error)")
        }
    }
}

// MARK: - Active Session Card

private struct ActiveSessionCard: View {
    let session: FocusSession
    let currentTime: Date
    let onComplete: () -> Void
    let onAbandon: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(session.objective)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Timer
                VStack {
                    Text(timeRemaining)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(isOvertime ? .red : .primary)
                    
                    Text(isOvertime ? "Overtime" : "Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(isOvertime ? Color.red : Color.kosmicBlue)
                        .frame(width: progressWidth(totalWidth: geometry.size.width), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kosmicGreen)
                
                Button(action: onAbandon) {
                    Label("Abandon", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var timeRemaining: String {
        let remaining = session.plannedDuration - session.elapsedTime
        let absRemaining = abs(remaining)
        let minutes = Int(absRemaining / 60)
        let seconds = Int(absRemaining.truncatingRemainder(dividingBy: 60))
        let sign = remaining < 0 ? "-" : ""
        return String(format: "\(sign)%d:%02d", minutes, seconds)
    }
    
    private var isOvertime: Bool {
        return session.elapsedTime > session.plannedDuration
    }
    
    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        let progress = min(1.0, session.elapsedTime / session.plannedDuration)
        return totalWidth * progress
    }
}

// MARK: - Suggested Target Row

private struct SuggestedTargetRow: View {
    let target: PriorityItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(target.objectType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", target.score * 100))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor)
                    }
                    
                    Text(target.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !target.detail.isEmpty {
                        Text(target.detail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Image(systemName: "arrow.right.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var scoreColor: Color {
        if target.score > 0.7 {
            return .red
        } else if target.score > 0.5 {
            return .orange
        } else if target.score > 0.3 {
            return .yellow
        } else {
            return .kosmicBlue
        }
    }
}

// MARK: - Session History Row

private struct SessionHistoryRow: View {
    let session: FocusSession
    
    var body: some View {
        HStack {
            // Status Icon
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundColor(statusColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.objective)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(session.completionSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private var statusIcon: String {
        switch session.status {
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle.fill"
        case .active: return "clock.fill"
        }
    }
    
    private var statusColor: Color {
        switch session.status {
        case .completed: return .kosmicGreen
        case .abandoned: return .red
        case .active: return .kosmicBlue
        }
    }
}

// MARK: - Start Session Sheet

private struct StartSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var objective: String
    @Binding var duration: TimeInterval
    let onStart: () -> Void
    
    let durations: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("2 hours", 7200)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Start Focus Session")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What will you focus on?")
                    .font(.headline)
                
                TextField("e.g., Write blog post on AI tools", text: $objective)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.headline)
                
                Picker("Duration", selection: $duration) {
                    ForEach(durations, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Start Session") {
                    onStart()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(objective.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

// MARK: - Complete Session Sheet

private struct CompleteSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var notes: String
    @Binding var completed: Bool
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Complete Focus Session")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Did you complete your objective?")
                    .font(.headline)
                
                Picker("Completion Status", selection: $completed) {
                    Text("Yes, completed").tag(true)
                    Text("Partial progress").tag(false)
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Session notes (optional)")
                    .font(.headline)
                
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .border(Color.secondary.opacity(0.2))
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Complete Session") {
                    onComplete()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

// MARK: - Preview

#Preview {
    FocusModeView()
        .modelContainer(for: [FocusSession.self, PriorityScore.self], inMemory: true)
}

