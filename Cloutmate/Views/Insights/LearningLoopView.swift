//
//  LearningLoopView.swift
//  Cloutmate
//
//  Phase 6.1 - AI Feedback & Learning Metrics
//

import SwiftUI
import SwiftData
import Charts

struct LearningLoopView: View {
    @Environment(\.modelContext) private var modelContext
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @State private var feedbackEvents: [AIFeedbackEvent] = []
    @State private var learningInsights: [String] = []
    @State private var narrativeSummaries: [StoryToken] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Learning Score Overview
                if let snapshot = snapshot {
                    GroupBox {
                        VStack(spacing: 16) {
                            Label("Learning Score", systemImage: "brain")
                                .font(.headline)
                            
                            HStack(spacing: 40) {
                                VStack {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                                            .frame(width: 120, height: 120)
                                        
                                        Circle()
                                            .trim(from: 0, to: snapshot.learningScore)
                                            .stroke(
                                                Color.kosmicBlue,
                                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                            )
                                            .frame(width: 120, height: 120)
                                            .rotationEffect(.degrees(-90))
                                        
                                        VStack {
                                            Text("\(Int(snapshot.learningScore * 100))")
                                                .font(.system(size: 40, weight: .bold))
                                            Text("Score")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "hand.thumbsup.fill")
                                            .foregroundColor(.kosmicGreen)
                                        Text("Positive Events")
                                        Spacer()
                                        Text("\(snapshot.positiveEvents)")
                                            .font(.headline)
                                    }
                                    
                                    HStack {
                                        Image(systemName: "hand.thumbsdown.fill")
                                            .foregroundColor(.red)
                                        Text("Negative Events")
                                        Spacer()
                                        Text("\(snapshot.negativeEvents)")
                                            .font(.headline)
                                    }
                                    
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .foregroundColor(.kosmicBlue)
                                        Text("Total Feedback")
                                        Spacer()
                                        Text("\(snapshot.feedbackEventsCount)")
                                            .font(.headline)
                                    }
                                }
                            }
                            .padding()
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                
                // Feedback Distribution
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Feedback Distribution", systemImage: "chart.pie")
                            .font(.headline)
                        
                        if !feedbackEvents.isEmpty {
                            let actionTypes = Dictionary(grouping: feedbackEvents, by: { $0.actionName })
                            
                            Chart(actionTypes.sorted(by: { $0.value.count > $1.value.count }), id: \.key) { actionType, events in
                                SectorMark(
                                    angle: .value("Count", events.count),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(colorForEventType(actionType))
                            }
                            .transaction { $0.animation = nil }
                            .frame(height: 250)
                            
                            // Legend
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(actionTypes.sorted(by: { $0.value.count > $1.value.count }), id: \.key) { actionType, events in
                                    HStack {
                                        Circle()
                                            .fill(colorForEventType(actionType))
                                            .frame(width: 8, height: 8)
                                        Text(actionType.capitalized)
                                            .font(.caption)
                                        Spacer()
                                        Text("\(events.count)")
                                            .font(.caption.bold())
                                    }
                                }
                            }
                            .padding(.top)
                        } else {
                            ContentUnavailableView(
                                "No Feedback Data",
                                systemImage: "chart.pie",
                                description: Text("Interact with Aurora to generate feedback events")
                            )
                            .frame(height: 250)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Recent Feedback Events
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Recent Feedback Events", systemImage: "list.bullet")
                            .font(.headline)
                        
                        if !feedbackEvents.isEmpty {
                            ForEach(feedbackEvents.prefix(10), id: \.id) { event in
                                FeedbackEventRow(event: event)
                                
                                if event.id != feedbackEvents.prefix(10).last?.id {
                                    Divider()
                                }
                            }
                        } else {
                            Text("No feedback events yet")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Narrative Summaries (Phase 5)
                if !narrativeSummaries.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Weekly Learning Summaries", systemImage: "book.pages")
                                .font(.headline)
                            
                            ForEach(narrativeSummaries.prefix(5), id: \.id) { story in
                                NarrativeSummaryCard(story: story)
                                
                                if story.id != narrativeSummaries.prefix(5).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                
                // Learning Insights
                if !learningInsights.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Key Insights", systemImage: "lightbulb.fill")
                                .font(.headline)
                            
                            ForEach(learningInsights, id: \.self) { insight in
                                HStack(alignment: .top) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(insight)
                                        .font(.body)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .task {
            loadData()
        }
        .onChange(of: timeRange) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        let (startDate, endDate) = timeRange.dateRange
        
        // Load feedback events
        let feedbackDescriptor = FetchDescriptor<AIFeedbackEvent>(
            predicate: #Predicate { event in
                event.createdAt >= startDate && event.createdAt <= endDate
            },
            sortBy: [SortDescriptor(\AIFeedbackEvent.createdAt, order: .reverse)]
        )
        feedbackEvents = (try? modelContext.fetch(feedbackDescriptor)) ?? []
        
        // Load narrative summaries
        let storyDescriptor = FetchDescriptor<StoryToken>(
            sortBy: [SortDescriptor(\StoryToken.startDate, order: .reverse)]
        )
        narrativeSummaries = (try? modelContext.fetch(storyDescriptor)) ?? []
        
        // Generate learning insights
        generateLearningInsights()
    }
    
    private func generateLearningInsights() {
        var insights: [String] = []
        
        // Analyze feedback patterns
        if !feedbackEvents.isEmpty {
            // Use items affected as a proxy for activity level
            let totalItems = feedbackEvents.reduce(0) { $0 + $1.itemsAffected }
            let avgItems = Double(totalItems) / Double(feedbackEvents.count)
            
            if avgItems > 5 {
                insights.append("You've been highly productive, affecting an average of \(String(format: "%.1f", avgItems)) items per action.")
            }
            
            // Analyze action types
            let actionTypes = Dictionary(grouping: feedbackEvents, by: { $0.actionName })
            if let mostCommon = actionTypes.max(by: { $0.value.count < $1.value.count }) {
                insights.append("Your most common activity is '\(mostCommon.key)' with \(mostCommon.value.count) actions.")
            }
        }
        
        // Analyze narrative trends
        if narrativeSummaries.count >= 2 {
            insights.append("You've maintained consistent reflection with \(narrativeSummaries.count) weekly summaries.")
        }
        
        learningInsights = insights
    }
    
    private func colorForEventType(_ eventType: String) -> Color {
        let hash = eventType.hash
        let colors: [Color] = [.kosmicBlue, .kosmicGreen, .orange, .kosmicPurple, .red, .pink, .cyan]
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Feedback Event Row

struct FeedbackEventRow: View {
    let event: AIFeedbackEvent
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.kosmicBlue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.actionName.capitalized)
                    .font(.headline)
                
                Text(event.resultMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(event.itemsAffected)")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.kosmicBlue.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Narrative Summary Card

struct NarrativeSummaryCard: View {
    let story: StoryToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(story.title)
                    .font(.headline)
                
                Spacer()
                
                Text(story.startDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(story.summary)
                .font(.body)
                .foregroundColor(.secondary)
            
            if !story.topConcepts.isEmpty {
                HStack {
                    ForEach(story.topConcepts.prefix(5), id: \.self) { concept in
                        Text(concept)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.kosmicPurple.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LearningLoopView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [AIFeedbackEvent.self, StoryToken.self])
}

