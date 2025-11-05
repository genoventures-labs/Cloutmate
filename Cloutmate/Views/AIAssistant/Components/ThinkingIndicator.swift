//
//  ThinkingIndicator.swift
//  Cloutmate
//
//  Dynamic thinking indicator that shows what Aurora is doing
//

import SwiftUI

struct ThinkingIndicator: View {
    let activity: AIAssistantViewModel.ActivityType
    let sourceModel: GeminiService.SummarySource?
    
    @State private var displayedActivity: AIAssistantViewModel.ActivityType
    @State private var opacity: Double = 1.0
    
    init(activity: AIAssistantViewModel.ActivityType, sourceModel: GeminiService.SummarySource? = nil) {
        self.activity = activity
        self.sourceModel = sourceModel
        _displayedActivity = State(initialValue: activity)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Dynamic icon based on activity
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .symbolEffect(.pulse, options: .repeating.speed(0.6), isActive: true)
            
            // Dynamic text based on activity (with adaptive phrasing for offline)
            Text(activityText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .opacity(opacity)
        .onChange(of: activity) { oldValue, newValue in
            // Micro-delay smoothing: fade out, update, fade in
            if oldValue != newValue {
                withAnimation(.easeInOut(duration: 0.15)) {
                    opacity = 0.0
                }
                
                // Update content after fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    displayedActivity = newValue
                    withAnimation(.easeInOut(duration: 0.15)) {
                        opacity = 1.0
                    }
                }
            }
        }
        .onAppear {
            displayedActivity = activity
            opacity = 1.0
        }
    }
    
    private var iconName: String {
        switch displayedActivity {
        case .thinking:
            return "sparkles"
        case .analyzingDocument:
            return "doc.text.magnifyingglass"
        case .analyzingImage:
            return "photo"
        case .generatingResponse:
            return "brain.head.profile"
        case .creatingTasks:
            return "checklist"
        case .creatingProject:
            return "folder.badge.plus"
        case .creatingNote:
            return "note.text"
        case .creatingPost:
            return "square.and.pencil"
        case .reflecting:
            return "chart.line.uptrend.xyaxis"
        case .searching:
            return "magnifyingglass"
        }
    }
    
    private var iconColor: Color {
        switch displayedActivity {
        case .thinking:
            return .kosmicBlue
        case .analyzingDocument:
            return .kosmicPurple
        case .analyzingImage:
            return .kosmicBlue
        case .generatingResponse:
            return .kosmicBlue
        case .creatingTasks:
            return .kosmicGreen
        case .creatingProject:
            return .kosmicPurple
        case .creatingNote:
            return .orange
        case .creatingPost:
            return .kosmicBlue
        case .reflecting:
            return .kosmicPurple
        case .searching:
            return .kosmicBlue
        }
    }
    
    private var activityText: String {
        // Adaptive phrasing: softer tone for offline fallback
        let isOffline = sourceModel == .offline || sourceModel == .appleLLM
        
        switch displayedActivity {
        case .thinking:
            return "Thinking..."
        case .analyzingDocument:
            return isOffline ? "Gathering what I can from the document..." : "Analyzing document..."
        case .analyzingImage:
            return isOffline ? "Looking at the image..." : "Analyzing image..."
        case .generatingResponse:
            return isOffline ? "Putting together a response..." : "Crafting response..."
        case .creatingTasks:
            return "Creating tasks..."
        case .creatingProject:
            return "Setting up project..."
        case .creatingNote:
            return "Creating note..."
        case .creatingPost:
            return "Drafting post..."
        case .reflecting:
            return "Reflecting on patterns..."
        case .searching:
            return "Searching..."
        }
    }
}

// MARK: - Idle Indicator

struct IdleIndicator: View {
    @State private var pulsePhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.kosmicBlue.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating.speed(0.3), isActive: true)
            
            Text("Ready when you are")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .opacity(0.5 + 0.3 * Darwin.cos(pulsePhase))
        .onAppear {
            withAnimation(
                Animation.linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
            ) {
                pulsePhase = .pi * 2
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ThinkingIndicator(activity: .thinking)
        ThinkingIndicator(activity: .analyzingDocument, sourceModel: .offline)
        ThinkingIndicator(activity: .analyzingImage)
        ThinkingIndicator(activity: .generatingResponse)
        ThinkingIndicator(activity: .creatingTasks)
        ThinkingIndicator(activity: .creatingProject)
        ThinkingIndicator(activity: .reflecting)
        IdleIndicator()
    }
    .padding()
}

