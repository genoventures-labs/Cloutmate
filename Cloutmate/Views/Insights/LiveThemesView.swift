//
//  LiveThemesView.swift
//  Cloutmate
//
//  Phase 5: Narrative Engine - Live Themes Brain Map
//  Visualizes active concepts with dynamic relevance scores
//

import SwiftUI
import SwiftData

struct LiveThemesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var aliveConcepts: [ConceptNode] = []
    @State private var allConcepts: [ConceptNode] = []
    @State private var showAllConcepts = false
    @State private var isGeneratingStory = false
    @State private var latestStory: StoryToken?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Themes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your conceptual brain map—what's alive in your workspace")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: generateWeeklySummary) {
                        Label("Generate Weekly Story", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGeneratingStory)
                }
                .padding()
                
                Divider()
                
                // Alive Concepts
                if !aliveConcepts.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🔥 Alive Concepts (Relevance > 30%)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ForEach(aliveConcepts, id: \.id) { concept in
                            ConceptCard(concept: concept)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // All Concepts Toggle
                if !allConcepts.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Button(action: { showAllConcepts.toggle() }) {
                        HStack {
                            Text(showAllConcepts ? "Hide Dormant Concepts" : "Show All Concepts")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: showAllConcepts ? "chevron.up" : "chevron.down")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    if showAllConcepts {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(allConcepts.filter { !$0.isAlive }, id: \.id) { concept in
                                ConceptCard(concept: concept)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // Latest Story
                if let story = latestStory {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📖 Latest Weekly Story")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        StoryPreviewCard(story: story)
                            .padding(.horizontal)
                    }
                }
                
                // Empty State
                if aliveConcepts.isEmpty && allConcepts.isEmpty {
                    EmptyStateView()
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .frame(minWidth: 700, minHeight: 500)
        .task {
            refreshData()
        }
    }
    
    private func refreshData() {
        aliveConcepts = ConceptTracker.shared.getAliveConcepts(modelContext: modelContext)
        allConcepts = ConceptTracker.shared.getTopConcepts(limit: 50, modelContext: modelContext)
        latestStory = NarrativeEngine.shared.getRecentStories(limit: 1, modelContext: modelContext).first
    }
    
    private func generateWeeklySummary() {
        isGeneratingStory = true
        
        Task {
            do {
                let story = try NarrativeEngine.shared.generateWeeklySummary(modelContext: modelContext)
                await MainActor.run {
                    latestStory = story
                    isGeneratingStory = false
                }
            } catch {
                await MainActor.run {
                    print("Failed to generate story: \(error)")
                    isGeneratingStory = false
                }
            }
        }
    }
}

// MARK: - Concept Card

private struct ConceptCard: View {
    let concept: ConceptNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Alive indicator
                Text(concept.isAlive ? "🔥" : "💤")
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(concept.concept)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("\(concept.mentionCount) mentions across \(Set(concept.contextTypes).count) contexts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Relevance Score
                VStack {
                    Text(String(format: "%.0f%%", concept.relevanceWeight * 100))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(relevanceColor)
                    
                    Text("Relevance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Score Breakdown
            HStack(spacing: 16) {
                ScoreComponent(
                    label: "Recency",
                    score: concept.recencyScore,
                    color: .kosmicBlue
                )
                
                ScoreComponent(
                    label: "Frequency",
                    score: concept.frequencyScore,
                    color: .kosmicGreen
                )
                
                ScoreComponent(
                    label: "Emotional",
                    score: concept.emotionalImpactScore,
                    color: .orange
                )
                
                ScoreComponent(
                    label: "Usage",
                    score: concept.usageScore,
                    color: .kosmicPurple
                )
            }
            
            // Context Tags
            FlowLayout(spacing: 8) {
                ForEach(Array(Set(concept.contextTypes)), id: \.self) { context in
                    Text(context.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                }
            }
            
            // Emotional Tone
            if abs(concept.emotionalValence) > 0.1 {
                HStack {
                    Text(emotionalIndicator)
                        .font(.caption)
                    
                    Text(emotionalDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(concept.isAlive ? Color.accentColor.opacity(0.05) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(concept.isAlive ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var relevanceColor: Color {
        if concept.relevanceWeight > 0.7 {
            return .red
        } else if concept.relevanceWeight > 0.5 {
            return .orange
        } else if concept.relevanceWeight > 0.3 {
            return .yellow
        } else {
            return .kosmicBlue
        }
    }
    
    private var emotionalIndicator: String {
        if concept.emotionalValence > 0.3 {
            return "✨"
        } else if concept.emotionalValence < -0.3 {
            return "⚠️"
        } else {
            return "📌"
        }
    }
    
    private var emotionalDescription: String {
        if concept.emotionalValence > 0.3 {
            return "Positive energy"
        } else if concept.emotionalValence < -0.3 {
            return "Challenging tone"
        } else {
            return "Neutral tone"
        }
    }
}

// MARK: - Score Component

private struct ScoreComponent: View {
    let label: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.0f", score * 100))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Story Preview Card

private struct StoryPreviewCard: View {
    let story: StoryToken
    @State private var showFullStory = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(story.title)
                    .font(.headline)
                
                Spacer()
                
                Text(story.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(story.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            if !story.topConcepts.isEmpty {
                HStack {
                    Text("Themes:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(story.topConcepts.prefix(5), id: \.self) { concept in
                        Text(concept)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.kosmicBlue.opacity(0.2)))
                    }
                }
            }
            
            Button(action: { showFullStory = true }) {
                Text("Read Full Story")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.kosmicBlue.opacity(0.05))
        )
        .sheet(isPresented: $showFullStory) {
            StoryReaderView(story: story)
        }
    }
}

// MARK: - Story Reader View

private struct StoryReaderView: View {
    let story: StoryToken
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(story.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                Text(LocalizedStringKey(story.markdown))
                    .padding()
            }
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Themes Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("As you work in tasks, notes, and journal entries, concepts will emerge and be tracked here with dynamic relevance scores.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    LiveThemesView()
        .modelContainer(for: [ConceptNode.self, StoryToken.self], inMemory: true)
}

