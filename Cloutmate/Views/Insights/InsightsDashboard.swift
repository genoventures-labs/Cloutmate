//
//  InsightsDashboard.swift
//  Cloutmate
//
//  Phase 6.1 - Intelligence Layer Visibility
//  Main container for all analytics and insights views
//

import SwiftUI
import SwiftData

enum InsightsTab: String, CaseIterable {
    case overview = "Overview"
    case productivity = "Productivity"
    case emotional = "Emotional"
    case memoryGraph = "Memory Graph"
    case learning = "Learning"
    case content = "Content"
    case automation = "Automation"
    
    var icon: String {
        switch self {
        case .overview: return "chart.bar.doc.horizontal"
        case .productivity: return "checkmark.circle"
        case .emotional: return "heart.text.square"
        case .memoryGraph: return "brain.head.profile"
        case .learning: return "chart.line.uptrend.xyaxis"
        case .content: return "megaphone"
        case .automation: return "gearshape.2"
        }
    }
}

struct InsightsDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: InsightsTab = .overview
    @State private var timeRange: AnalyticsTimeRange = .thisWeek
    @State private var analyticsSnapshot: AnalyticsSnapshot?
    @State private var isLoading = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(InsightsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(AnalyticsTimeRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                            Button(range.rawValue) {
                                timeRange = range
                                refreshData()
                            }
                        }
                    } label: {
                        Label("Time Range", systemImage: "calendar")
                    }
                }
            }
        } detail: {
            Group {
                if isLoading {
                    ProgressView("Loading insights...")
                } else {
                    detailView
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: refreshData) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            refreshData()
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .overview:
            if let snapshot = analyticsSnapshot {
                OverviewView(snapshot: snapshot, timeRange: timeRange)
            } else {
                ContentUnavailableView(
                    "No Data Available",
                    systemImage: "chart.bar",
                    description: Text("Start using Cloutmate to see insights")
                )
            }
            
        case .productivity:
            ProductivityMetricsView(
                snapshot: analyticsSnapshot,
                timeRange: timeRange
            )
            
        case .emotional:
            EmotionalHeatmapView(
                snapshot: analyticsSnapshot,
                timeRange: timeRange
            )
            
        case .memoryGraph:
            ConceptGraphView()
            
        case .learning:
            LearningLoopView(
                snapshot: analyticsSnapshot,
                timeRange: timeRange
            )
            
        case .content:
            ContentAnalyticsView(
                snapshot: analyticsSnapshot,
                timeRange: timeRange
            )
            
        case .automation:
            AutomationDashboardView()
        }
    }
    
    private func refreshData() {
        isLoading = true
        
        Task {
            let snapshot = AnalyticsEngine.shared.generateSnapshot(
                for: timeRange,
                modelContext: modelContext
            )
            
            await MainActor.run {
                analyticsSnapshot = snapshot
                isLoading = false
            }
        }
    }
}

// MARK: - Overview View

struct OverviewView: View {
    let snapshot: AnalyticsSnapshot
    let timeRange: AnalyticsTimeRange
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Header Stats
                HStack(spacing: 16) {
                    StatCard(
                        title: "Completion Rate",
                        value: "\(Int(snapshot.completionRate * 100))%",
                        icon: "checkmark.circle.fill",
                        color: .kosmicGreen
                    )
                    
                    StatCard(
                        title: "Focus Time",
                        value: "\(snapshot.totalFocusMinutes)m",
                        icon: "timer",
                        color: .kosmicBlue
                    )
                    
                    StatCard(
                        title: "Learning Score",
                        value: "\(Int(snapshot.learningScore * 100))%",
                        icon: "brain",
                        color: .kosmicPurple
                    )
                }
                .padding(.horizontal)
                
                // Productivity Summary
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Productivity", systemImage: "chart.bar")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(snapshot.tasksCompleted)")
                                    .font(.title2.bold())
                                Text("Tasks Completed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("\(snapshot.focusSessionsCount)")
                                    .font(.title2.bold())
                                Text("Focus Sessions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !snapshot.topPriorityItems.isEmpty {
                            Divider()
                            
                            Text("Top Priority Items")
                                .font(.caption.bold())
                            
                            ForEach(snapshot.topPriorityItems.prefix(3), id: \.self) { item in
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(item)
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Emotional State
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Emotional State", systemImage: "heart")
                            .font(.headline)
                        
                        HStack {
                            EmotionBadge(emotion: snapshot.dominantEmotion)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(snapshot.emotionalTrend.rawValue.capitalized)
                                    .font(.subheadline.bold())
                                Text("Trend")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Memory Graph Stats (Phase 6)
                if snapshot.activeThemes > 0 {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Memory Graph", systemImage: "brain.head.profile")
                                .font(.headline)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(snapshot.activeThemes)")
                                        .font(.title2.bold())
                                    Text("Active Themes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading) {
                                    Text("\(snapshot.memoryNodes)")
                                        .font(.title2.bold())
                                    Text("Memory Nodes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading) {
                                    Text("\(snapshot.conceptCount)")
                                        .font(.title2.bold())
                                    Text("Concepts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                
                // Content Performance
                if snapshot.postsPublished > 0 {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Content Performance", systemImage: "megaphone")
                                .font(.headline)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(snapshot.postsPublished)")
                                        .font(.title2.bold())
                                    Text("Posts Published")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading) {
                                    Text(String(format: "%.1f", snapshot.avgEngagement))
                                        .font(.title2.bold())
                                    Text("Avg Engagement")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct EmotionBadge: View {
    let emotion: EmotionType
    
    var body: some View {
        HStack {
            Image(systemName: emotionIcon)
                .foregroundColor(emotionColor)
            Text(emotion.rawValue.capitalized)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(emotionColor.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var emotionIcon: String {
        switch emotion {
        case .joyful, .excited: return "face.smiling"
        case .neutral, .calm: return "minus.circle"
        case .frustrated, .anxious: return "exclamationmark.triangle"
        default: return "circle"
        }
    }
    
    private var emotionColor: Color {
        switch emotion {
        case .joyful, .excited: return .kosmicGreen
        case .neutral, .calm: return .kosmicBlue
        case .frustrated, .anxious: return .orange
        default: return .gray
        }
    }
}

#Preview {
    InsightsDashboard()
        .modelContainer(for: [
            Post.self,
            AIConversation.self,
            FocusSession.self
        ])
}

