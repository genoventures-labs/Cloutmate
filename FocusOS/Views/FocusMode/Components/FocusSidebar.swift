//
//  FocusSidebar.swift
//  FocusOS
//
//  Focus Mode V2 - Session Sidebar (Aurora Companion)
//

import SwiftUI
import SwiftData
import FocusOSShared

struct FocusSidebar: View {
    let session: FocusSession?
    let onLogTone: (EmotionalState) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var latestForecast: FocusForecast?
    @State private var showTonePicker = false
    @State private var showEndOfSessionSummary = false
    @State private var inactivityTimer: Timer?
    @State private var lastActivityTime = Date()
    @State private var previousTone: EmotionalState = .calm
    @State private var toneImprovementPulse: CGFloat = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Live ARTE Monitor
                liveARTEMonitor
                
                // Session Reflection
                sessionReflection
                
                // Predictive Cognition Tips
                predictiveCognitionTips
                
                // Linked Entities
                if let session = session {
                    linkedEntities(session: session)
                }
                
                // End-of-Session Summary
                if showEndOfSessionSummary, let session = session {
                    endOfSessionSummary(session: session)
                }
            }
            .padding(20)
        }
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .onAppear {
            loadLatestForecast()
            startInactivityTimer()
        }
        .onChange(of: session) { _, _ in
            lastActivityTime = Date()
            if session == nil {
                showEndOfSessionSummary = false
                stopInactivityTimer()
            } else {
                startInactivityTimer()
            }
        }
        .onChange(of: ReactiveThemeManager.shared.currentState) { oldValue, newValue in
            checkToneImprovement(from: oldValue, to: newValue)
        }
        .sheet(isPresented: $showTonePicker) {
            tonePickerSheet
        }
    }
    
    // MARK: - Live ARTE Monitor
    
    @ViewBuilder
    private var liveARTEMonitor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(glassColorSystem.emotionalAccent())
                Text("Live ARTE Monitor")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(ReactiveThemeManager.shared.currentState.rawValue.capitalized)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(glassColorSystem.emotionalAccent())
                
                // Adaptive gradient bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        glassColorSystem.emotionalAccent(),
                                        glassColorSystem.emotionalAccent().opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(ReactiveThemeManager.shared.confidence), height: 8)
                    }
                }
                .frame(height: 8)
                
                Text("Confidence: \(Int(ReactiveThemeManager.shared.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(glassColorSystem.emotionalAccent().opacity(0.1))
        )
        .overlay(
            Group {
                if toneImprovementPulse > 0 {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color.kosmicGreen.opacity(0.3 + toneImprovementPulse * 0.3),
                            lineWidth: 2
                        )
                }
            }
        )
    }
    
    // MARK: - Session Reflection
    
    @ViewBuilder
    private var sessionReflection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.kosmicPurple)
                Text("Session Reflection")
                    .font(.headline)
                Spacer()
            }
            
            Button(action: {
                showTonePicker = true
            }) {
                HStack {
                    Text("How are you feeling right now?")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    // MARK: - Predictive Cognition Tips
    
    @ViewBuilder
    private var predictiveCognitionTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.kosmicBlue)
                Text("Predictive Cognition")
                    .font(.headline)
                Spacer()
            }
            
            if let forecast = latestForecast {
                VStack(alignment: .leading, spacing: 8) {
                    if let nextWindow = forecast.nextFocusWindowStart {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.kosmicBlue)
                            Text("Peak cognitive energy expected at \(nextWindow.formatted(date: .omitted, time: .shortened)).")
                                .font(.subheadline)
                        }
                    }
                    
                    if forecast.fatigueRisk > 0.65 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("High fatigue risk detected. Consider taking a break.")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Text("Focus Stability: \(Int(forecast.focusStability * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No forecast available yet. Continue working to build predictions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    // MARK: - Linked Entities
    
    @ViewBuilder
    private func linkedEntities(session: FocusSession) -> some View {
        if let targetId = session.targetObjectId,
           let targetType = session.targetObjectType {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "link.circle.fill")
                        .foregroundColor(.kosmicPurple)
                    Text("Linked Entity")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: iconForType(targetType))
                        .font(.caption)
                        .foregroundColor(.kosmicBlue)
                    Text("\(targetType.capitalized): \(session.objective)")
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.05))
            )
        }
    }
    
    // MARK: - End-of-Session Summary
    
    @ViewBuilder
    private func endOfSessionSummary(session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.kosmicGreen)
                Text("Session Summary")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration: \(session.durationFormatted)")
                    .font(.subheadline)
                
                Text("Status: \(session.completed ? "Completed" : "Partial")")
                    .font(.subheadline)
                
                if !session.itemsCompleted.isEmpty {
                    Text("Items finished: \(session.itemsCompleted.count)")
                        .font(.subheadline)
                }
                
                if let notes = session.notes, !notes.isEmpty {
                    Text("Notes: \(notes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.kosmicGreen.opacity(0.1))
        )
    }
    
    // MARK: - Tone Picker Sheet
    
    @ViewBuilder
    private var tonePickerSheet: some View {
        VStack(spacing: 20) {
            Text("How are you feeling?")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(EmotionalState.allCases, id: \.self) { tone in
                    Button(action: {
                        onLogTone(tone)
                        showTonePicker = false
                    }) {
                        HStack {
                            Text(tone.rawValue.capitalized)
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    // MARK: - Helpers
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "task": return "checkmark.circle.fill"
        case "project": return "folder.fill"
        case "note": return "note.text"
        default: return "doc.fill"
        }
    }
    
    private func loadLatestForecast() {
        latestForecast = CognitionPredictor.shared.fetchLatestForecast(modelContext: modelContext)
    }
    
    private func startInactivityTimer() {
        stopInactivityTimer()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { _ in
            if session != nil {
                showEndOfSessionSummary = true
            }
        }
    }
    
    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    private func checkToneImprovement(from oldTone: EmotionalState, to newTone: EmotionalState) {
        // Simple heuristic: moving from fatigued/reflective to calm/focused/energized is improvement
        let improved = (oldTone == .fatigued || oldTone == .reflective) &&
                      (newTone == .calm || newTone == .focused || newTone == .energized)
        
        if improved {
            withAnimation(
                Animation.easeInOut(duration: 1.0)
                    .repeatCount(3, autoreverses: true)
            ) {
                toneImprovementPulse = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                toneImprovementPulse = 0
            }
        }
    }
}

#Preview {
    FocusSidebar(
        session: nil,
        onLogTone: { _ in }
    )
    .environmentObject(GlassColorSystem())
    .padding()
    .modelContainer(for: [FocusSession.self, FocusForecast.self])
}

