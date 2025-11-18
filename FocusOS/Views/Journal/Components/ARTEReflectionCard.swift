//
//  ARTEReflectionCard.swift
//  FocusOS
//
//  ARTE reflection summary card for Journal Detail Drawer
//

import SwiftUI
import SwiftData
import FocusOSShared

struct ARTEReflectionCard: View {
    let journal: Journal
    let emotionalState: EmotionalStateDetection?
    let snapshot: AnalyticsSnapshot?
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                        .font(.headline)
                    
                    Text("ARTE Reflection")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                // Emotional state
                if let detection = emotionalState {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Emotional State:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(detection.state.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(stateColor(detection.state))
                        }
                        
                        // Confidence bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [stateColor(detection.state), stateColor(detection.state).opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(detection.confidence), height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        if let secondary = detection.secondaryState {
                            Text("Also feeling: \(secondary.rawValue.capitalized)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Summary from snapshot
                if let snapshot = snapshot {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day Summary:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(summaryText(from: snapshot))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(16)
        }
    }
    
    private func stateColor(_ state: EmotionalState) -> Color {
        switch state {
        case .focused: return .kosmicBlue
        case .reflective: return .kosmicPurple
        case .calm: return .cyan
        case .energized: return .kosmicGreen
        case .fatigued: return .orange
        }
    }
    
    private func summaryText(from snapshot: AnalyticsSnapshot) -> String {
        var parts: [String] = []
        
        if snapshot.tasksCompleted > 0 {
            parts.append("\(snapshot.tasksCompleted) tasks completed")
        }
        
        if snapshot.focusSessionsCount > 0 {
            parts.append("\(snapshot.focusSessionsCount) focus sessions")
        }
        
        let trend = snapshot.emotionalTrend
        switch trend {
        case .improving:
            parts.append("mood improving")
        case .declining:
            parts.append("mood declining")
        case .volatile:
            parts.append("mood variable")
        case .stable:
            parts.append("mood stable")
        }
        
        return parts.isEmpty ? "No activity recorded" : parts.joined(separator: " • ")
    }
}

#Preview {
    ARTEReflectionCard(
        journal: Journal(title: "Test", content: "Test content"),
        emotionalState: EmotionalStateDetection(state: .focused, confidence: 0.85, secondaryState: .calm),
        snapshot: nil
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

