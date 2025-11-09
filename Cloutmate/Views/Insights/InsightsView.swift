//
//  InsightsView.swift
//  Cloutmate
//
//  Personal Intelligence Dashboard
//  Your mirror - unified intelligence showing how you think, work, and evolve
//

import SwiftUI
import SwiftData
import Charts
import os.log
import CloutmateShared
import UniformTypeIdentifiers
import AppKit

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTimeRange: AnalyticsTimeRange = .thisWeek
    @State private var currentSnapshot: AnalyticsSnapshot?
    @State private var isLoading = false
    @State private var selectedViewType: InsightsViewType = .focus
    @State private var searchText: String = ""
    @State private var autoRefreshTimer: Timer?
    @State private var ritualTrend: [(Date, Double)] = []
    @State private var topConcepts: [(name: String, salience: Double, count: Int)] = []
    @State private var isBuildingGraph: Bool = false
    @State private var showingMemoryGraphInfo: Bool = false
    @State private var memoryGraphError: String?
    @State private var hasMemoryGraphData: Bool = false
    @State private var memoryGraphNodeCount: Int = 0
    @State private var memoryGraphThemeCount: Int = 0
    @State private var graphActivityMessage: String = "Building memory graph…"
    
    var body: some View {
        VStack(spacing: 0) {
            // Unified Header
            InsightsHeaderView(
                selectedTimeRange: $selectedTimeRange,
                selectedViewType: $selectedViewType,
                searchText: $searchText,
                onExport: {
                    exportWeeklyReflection()
                }
            )
            
            // Unified Dashboard
            UnifiedInsightsView(
                snapshot: currentSnapshot,
                timeRange: selectedTimeRange,
                searchText: searchText,
                selectedViewType: selectedViewType
            )
        }
        .task {
            await loadAnalytics()
            await checkMemoryGraphData()
            await MainActor.run {
                startAutoRefresh()
            }
        }
        .onChange(of: selectedTimeRange) { _, _ in
            _Concurrency.Task {
                await loadAnalytics()
            }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .overlay(alignment: .center) {
            if isBuildingGraph {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(graphActivityMessage)
                            .font(.system(size: 13))
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Time Range Picker
    
    private var timeRangePicker: some View {
        HStack(spacing: 8) {
            ForEach([AnalyticsTimeRange.today, .thisWeek, .thisMonth], id: \.self) { range in
                Button {
                    selectedTimeRange = range
                } label: {
                    Text(range.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedTimeRange == range ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTimeRange == range ? KosmicPalette.violet : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 🧠 Cognitive Overview
    
    private var cognitiveOverviewSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Current Mode Card
            GlassPanel(tier: .contentCard, cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundColor(KosmicPalette.cyan)
                        Text("Current Mode")
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                    }
                    
                    if let snapshot = currentSnapshot {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(getCurrentMode(from: snapshot))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(KosmicPalette.violet)
                            
                            Text(getModeDescription(from: snapshot))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    } else {
                        ProgressView()
                    }
                }
                .padding(20)
            }
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Emotional Pulse
                IntelligenceStatCard(
                    title: "Emotional Pulse",
                    value: formatEmotionalPulse(),
                    subtitle: "7-day average",
                    icon: "heart.circle.fill",
                    color: getEmotionalColor()
                )
                
                // Learning Loop
                IntelligenceStatCard(
                    title: "Learning Score",
                    value: String(format: "%.0f%%", currentSnapshot?.learningScore ?? 0.0),
                    subtitle: "Aurora's growth",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: KosmicPalette.cyan
                )
                
                // Active Themes
                IntelligenceStatCard(
                    title: "Active Themes",
                    value: "\(currentSnapshot?.activeThemes ?? 0)",
                    subtitle: "in memory graph",
                    icon: "network",
                    color: KosmicPalette.violet
                )
            }
            
            // ARTE Status Indicator (Phase 7)
            EmotionalStateIndicator()

            // Focus Ritual Metrics
            if currentSnapshot != nil {
                focusRitualsCard
            }
            
            // Aurora's Current Experiment
            if let snapshot = currentSnapshot, snapshot.feedbackEventsCount > 0 {
                GlassPanel(tier: .contentCard, cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(KosmicPalette.violet)
                            Text("Aurora's Current Experiment")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(getAuroraExperiment(from: snapshot))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                }
            }
        }
    }
    
    // MARK: - 🔍 Memory Graph
    
    private var memoryGraphSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Graph")
                        .font(.system(size: 24, weight: .bold))
                    Text("Your concepts and how they connect")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if hasMemoryGraphData {
                    Button {
                        _Concurrency.Task { await buildMemoryGraph() }
                    } label: {
                        Label("Rebuild", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .disabled(isBuildingGraph)
                }
            }
            
            Group {
                // Show build card if no data exists
                if !hasMemoryGraphData {
                    GlassPanel(tier: .contentCard, cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "network")
                                    .font(.system(size: 24))
                                    .foregroundColor(KosmicPalette.cyan)
                                Text("Build Your Memory Graph")
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                            }
                            Text("Connect tasks, notes, posts, and concepts into a knowledge map. This helps Aurora surface patterns and themes over time.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 12) {
                                Button {
                                    _Concurrency.Task { await buildMemoryGraph() }
                                } label: {
                                    HStack {
                                        Image(systemName: "wand.and.stars")
                                        Text("Build Memory Graph")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(KosmicPalette.violet)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showingMemoryGraphInfo = true
                                } label: {
                                    HStack {
                                        Image(systemName: "questionmark.circle")
                                        Text("What is this?")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                } else if memoryGraphThemeCount == 0 {
                    GlassPanel(tier: .contentCard, cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 24))
                                    .foregroundColor(KosmicPalette.cyan)
                                Text("No Themes Detected Yet")
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                            }
                            Text("We’ve indexed \(memoryGraphNodeCount) memories but haven’t found confident themes yet. Try extracting themes or rebuilding the graph to discover new patterns.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 12) {
                                Button {
                                    _Concurrency.Task { await runThemeExtraction() }
                                } label: {
                                    HStack {
                                        Image(systemName: "wand.and.rays")
                                        Text("Extract Themes")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(KosmicPalette.violet)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(isBuildingGraph)

                                Button {
                                    _Concurrency.Task { await buildMemoryGraph() }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Rebuild Graph")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(isBuildingGraph)
                            }
                        }
                        .padding(20)
                    }
                } else {
                    ConceptGraphView()
                        .frame(height: 600)
                }
            }
        }
    }
    
    // MARK: - 📈 Focus Analytics
    
    private var focusAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Analytics")
                        .font(.system(size: 24, weight: .bold))
                    Text("Your focus patterns and productivity rhythm")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            ProductivityMetricsView(
                snapshot: currentSnapshot,
                timeRange: selectedTimeRange
            )
        }
    }
    
    // MARK: - ❤️ Emotional Heatmap
    
    private var emotionalHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emotional Heatmap")
                        .font(.system(size: 24, weight: .bold))
                    Text("Your emotional landscape over time")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            EmotionalHeatmapView(
                snapshot: currentSnapshot,
                timeRange: selectedTimeRange
            )
        }
    }
    
    // MARK: - 🌀 Learning Loop
    
    private var learningLoopSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learning Loop")
                        .font(.system(size: 24, weight: .bold))
                    Text("What Aurora learns from you")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            LearningLoopView(
                snapshot: currentSnapshot,
                timeRange: selectedTimeRange
            )
        }
    }
    
    // MARK: - 🔗 Connections
    
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connections")
                        .font(.system(size: 24, weight: .bold))
                    Text("Recurring themes and concept evolution")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Top Recurring Motifs
            GlassPanel(tier: .contentCard, cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(KosmicPalette.violet)
                        Text("Recurring Motifs")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                    }
                    
                    if !topConcepts.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(topConcepts, id: \.name) { concept in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(concept.name)
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Mentioned \(concept.count) times")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(String(format: "%.1f", concept.salience))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(KosmicPalette.cyan)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.05))
                                )
                            }
                        }
                    } else {
                        Text("No themes detected yet. Continue working and reflecting.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(20)
            }
            
            // Theme Evolution Graph
            GlassPanel(tier: .contentCard, cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(KosmicPalette.cyan)
                        Text("Theme Evolution")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                    }
                    
                    if let snapshot = currentSnapshot {
                        Text("In the last \(selectedTimeRange.displayName.lowercased()), \(snapshot.activeThemes) themes emerged from \(snapshot.memoryNodes) memory nodes")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    // Placeholder for future evolution visualization
                    Text("Theme evolution visualization coming soon")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                        .italic()
                        .padding(.vertical, 8)
                }
                .padding(20)
            }
            
            // Long-term Memory Summary
            GlassPanel(tier: .contentCard, cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(KosmicPalette.violet)
                        Text("Long-term Memory")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                    }
                    
                    if let snapshot = currentSnapshot {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Memory Graph Density: \(String(format: "%.1f%%", snapshot.graphDensity * 100))")
                                .font(.system(size: 14))
                            Text("Total Concepts: \(snapshot.conceptCount)")
                                .font(.system(size: 14))
                            Text("Memory Nodes: \(snapshot.memoryNodes)")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            
            // Export Options
            HStack(spacing: 12) {
                Button {
                    exportWeeklyReflection()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Weekly Reflection")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(KosmicPalette.violet)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    // Future: Compare weeks feature
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Compare Weeks")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadAnalytics() async {
        isLoading = true
        let snapshot = await AnalyticsEngine.shared.generateSnapshot(
            for: selectedTimeRange,
            modelContext: modelContext
        )
        await MainActor.run {
            currentSnapshot = snapshot
            ritualTrend = AnalyticsEngine.shared.getRitualCompletionTrend(days: 14, modelContext: modelContext)
            topConcepts = fetchTopConcepts()
            isLoading = false
        }
    }
    
    private func getCurrentMode(from snapshot: AnalyticsSnapshot) -> String {
        // Determine mode based on recent activity
        let focusScore = snapshot.focusSessionsCount > 0 ? Double(snapshot.focusSessionsCount) : 0
        let taskScore = snapshot.completionRate
        let emotionalScore = abs(snapshot.emotionalSnapshot.valence)
        
        if focusScore > 3 && taskScore > 0.7 {
            return "Deep Work"
        } else if taskScore > 0.5 {
            return "Productive Flow"
        } else if emotionalScore > 0.6 {
            return "High Energy"
        } else if snapshot.feedbackEventsCount > 10 {
            return "Learning Mode"
        } else {
            return "Exploring"
        }
    }
    
    private func getModeDescription(from snapshot: AnalyticsSnapshot) -> String {
        let mode = getCurrentMode(from: snapshot)
        switch mode {
        case "Deep Work":
            return "You're in a highly focused state with multiple deep work sessions. Keep this momentum going."
        case "Productive Flow":
            return "You're completing tasks at a strong pace. Your productivity rhythm is healthy."
        case "High Energy":
            return "Your emotional state is vibrant. Channel this energy into creative work."
        case "Learning Mode":
            return "Aurora is learning rapidly from your patterns. Your feedback loop is strong."
        default:
            return "You're exploring and building habits. Your intelligence system is warming up."
        }
    }
    
    private func formatEmotionalPulse() -> String {
        guard let snapshot = currentSnapshot else { return "--" }
        let valence = snapshot.emotionalSnapshot.valence
        
        if valence > 0.5 {
            return "Positive"
        } else if valence > 0 {
            return "Stable"
        } else if valence > -0.5 {
            return "Reflective"
        } else {
            return "Challenging"
        }
    }
    
    private func getEmotionalColor() -> Color {
        guard let snapshot = currentSnapshot else { return .gray }
        let valence = snapshot.emotionalSnapshot.valence
        
        if valence > 0.5 {
            return .kosmicGreen
        } else if valence > 0 {
            return KosmicPalette.cyan
        } else if valence > -0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getAuroraExperiment(from snapshot: AnalyticsSnapshot) -> String {
        // Generate dynamic experiment message based on current data
        if snapshot.focusSessionsCount > 5 {
            return "Testing response tone adaptation based on your weekly focus ratio. Aurora is learning to match your energy levels."
        } else if snapshot.completionRate > 0.7 {
            return "Analyzing task completion patterns to predict optimal work times. You've been finishing tasks faster when you tag them by mood."
        } else if snapshot.emotionalTrend == .improving {
            return "Observing emotional continuity patterns. Your positive trend is being factored into recommendation algorithms."
        } else {
            return "Building your baseline cognitive profile. Aurora adapts more intelligently the more you interact."
        }
    }
    
    private func getTopConcepts() -> [(name: String, salience: Double, count: Int)]? {
        // Deprecated: use pre-fetched topConcepts state instead
        return topConcepts.isEmpty ? nil : topConcepts
    }
        
    private func fetchTopConcepts() -> [(name: String, salience: Double, count: Int)] {
        let conceptDescriptor = FetchDescriptor<ConceptNode>(
            sortBy: [SortDescriptor(\ConceptNode.relevanceWeight, order: .reverse)]
        )
        let concepts = (try? modelContext.fetch(conceptDescriptor)) ?? []
        return Array(concepts.prefix(5).map { concept in
            (
                name: concept.concept,
                salience: concept.relevanceWeight,
                count: concept.mentionCount
            )
        })
    }
    
    private func exportWeeklyReflection() {
        guard let snapshot = currentSnapshot else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf, .plainText]
        panel.nameFieldStringValue = "Weekly_Reflection_\(Date().ISO8601Format()).pdf"
        panel.message = "Export your weekly reflection"
        panel.allowsOtherFileTypes = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Generate summary content
                let summary = generateWeeklySummary(snapshot: snapshot)
                
                // Export as Markdown (simplified - full PDF generation would require PDFKit)
                if url.pathExtension == "txt" || url.pathExtension == "md" {
                    do {
                        try summary.write(to: url, atomically: true, encoding: .utf8)
                        Logger.insights.info("Exported weekly reflection to \(url.path)")
                    } catch {
                        Logger.insights.error("Failed to export reflection: \(error.localizedDescription)")
                    }
                } else {
                    // For PDF, we'd need to use PDFKit - for now, save as text
                    let textURL = url.deletingPathExtension().appendingPathExtension("txt")
                    do {
                        try summary.write(to: textURL, atomically: true, encoding: .utf8)
                        Logger.insights.info("Exported weekly reflection to \(textURL.path)")
                    } catch {
                        Logger.insights.error("Failed to export reflection: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func generateWeeklySummary(snapshot: AnalyticsSnapshot) -> String {
        var summary = "# Weekly Reflection\n\n"
        summary += "Generated: \(Date().formatted(date: .long, time: .shortened))\n\n"
        
        summary += "## Focus Metrics\n"
        summary += "- Sessions: \(snapshot.focusSessionsCount)\n"
        summary += "- Completion Rate: \(Int(snapshot.focusCompletionRate * 100))%\n"
        summary += "- Total Focus Time: \(snapshot.totalFocusMinutes) minutes\n\n"
        
        summary += "## Emotional Patterns\n"
        summary += "- Dominant Emotion: \(snapshot.dominantEmotion.rawValue)\n"
        summary += "- Trend: \(snapshot.emotionalTrend.rawValue)\n"
        summary += "- Valence: \(String(format: "%.2f", snapshot.emotionalSnapshot.valence))\n\n"
        
        summary += "## Habits & Rituals\n"
        summary += "- Ritual Completion: \(Int(snapshot.ritualCompletionRate * 100))%\n"
        summary += "- Morning Streak: \(snapshot.morningRitualStreak) days\n"
        summary += "- Evening Streak: \(snapshot.eveningRitualStreak) days\n\n"
        
        summary += "## Task Completion\n"
        summary += "- Tasks Completed: \(snapshot.tasksCompleted)\n"
        summary += "- Completion Rate: \(Int(snapshot.completionRate * 100))%\n\n"
        
        if let forecast = snapshot.latestForecast {
            summary += "## Cognitive Forecast\n"
            summary += "- Fatigue Risk: \(Int(forecast.fatigueRisk * 100))%\n"
            summary += "- Focus Stability: \(Int(forecast.focusStability * 100))%\n"
            if let nextWindow = forecast.nextFocusWindowStart {
                summary += "- Next Focus Peak: \(nextWindow.formatted(date: .abbreviated, time: .shortened))\n"
            }
            summary += "\n"
        }
        
        summary += "---\n"
        summary += "*Generated by Aurora's Intelligence Layer*\n"
        
        return summary
    }
    
    private func startAutoRefresh() {
        // Refresh every 5 minutes
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            _Concurrency.Task {
                await loadAnalytics()
            }
        }
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    // MARK: - Memory Graph Utilities

    @MainActor
    private func checkMemoryGraphData() {
        let nodeDescriptor = FetchDescriptor<MemoryNode>()
        let themeDescriptor = FetchDescriptor<ThemeNode>()
        let nodes = (try? modelContext.fetch(nodeDescriptor)) ?? []
        let themes = (try? modelContext.fetch(themeDescriptor)) ?? []
        memoryGraphNodeCount = nodes.count
        memoryGraphThemeCount = themes.count
        hasMemoryGraphData = !nodes.isEmpty
        Logger.insights.info("Memory graph data check: nodes=\(memoryGraphNodeCount), themes=\(memoryGraphThemeCount), hasData=\(hasMemoryGraphData)")
    }
    
    // MARK: - Memory Graph Builder
    private func buildMemoryGraph() async {
        guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
            await MainActor.run {
                memoryGraphError = "Memory Graph is disabled. Enable AIMemoryGraphEnabled in AIConfig.plist to use this feature."
                showingMemoryGraphInfo = true
            }
            return
        }
        if isBuildingGraph { return }
        await MainActor.run {
            graphActivityMessage = "Building memory graph…"
            isBuildingGraph = true
        }
        defer {
            _Concurrency.Task { @MainActor in
                isBuildingGraph = false
                graphActivityMessage = "Building memory graph…"
            }
        }
        
        let ctx = modelContext
        let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "Insights")
        logger.info("Building memory graph from existing data...")
        
        do {
            // Fetch a reasonable batch from each type
            var taskDescriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\Task.updatedAt, order: .reverse)])
            taskDescriptor.fetchLimit = 50
            let tasks = (try? ctx.fetch(taskDescriptor)) ?? []

            var noteDescriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\Note.updatedAt, order: .reverse)])
            noteDescriptor.fetchLimit = 50
            let notes = (try? ctx.fetch(noteDescriptor)) ?? []

            var draftDescriptor = FetchDescriptor<Draft>(sortBy: [SortDescriptor(\Draft.updatedAt, order: .reverse)])
            draftDescriptor.fetchLimit = 50
            let drafts = (try? ctx.fetch(draftDescriptor)) ?? []

            var postDescriptor = FetchDescriptor<Post>(sortBy: [SortDescriptor(\Post.updatedAt, order: .reverse)])
            postDescriptor.fetchLimit = 50
            let posts = (try? ctx.fetch(postDescriptor)) ?? []
            
            logger.info("Found \(tasks.count) tasks, \(notes.count) notes, \(drafts.count) drafts, \(posts.count) posts")
            
            let objects: [any RecallTrackable] = tasks + notes + drafts + posts
            if objects.isEmpty {
                logger.info("No objects found to create nodes from")
                await MainActor.run {
                    memoryGraphError = "No tasks, notes, drafts, or posts found. Create some content first."
                    showingMemoryGraphInfo = true
                }
                return
            }
            
            logger.info("Creating memory graph nodes for \(objects.count) objects...")
            
            // Create/find nodes
            var createdCount = 0
            var existingCount = 0
            
            // Fetch all existing nodes to check against
            let allNodesDescriptor = FetchDescriptor<MemoryNode>()
            let allNodes = (try? ctx.fetch(allNodesDescriptor)) ?? []
            let existingNodeIds = Set(allNodes.compactMap { $0.objectId })
            
            for (index, object) in objects.enumerated() {
                // Check if node already exists
                if existingNodeIds.contains(object.recallObjectId) {
                    existingCount += 1
                    continue
                }
                
                _ = try await MemoryGraphService.shared.findOrCreateNode(for: object, modelContext: ctx)
                createdCount += 1
                
                // Save periodically to avoid memory pressure
                if index % 10 == 0 {
                    try? ctx.save()
                }
            }
            
            logger.info("Created \(createdCount) new nodes, \(existingCount) already existed")
            
            // Optionally connect similar nodes (lightweight pass)
            var nodeDescriptor = FetchDescriptor<MemoryNode>()
            nodeDescriptor.fetchLimit = 25
            let seedNodes: [MemoryNode] = (try? ctx.fetch(nodeDescriptor)) ?? []
            
            logger.info("Linking \(seedNodes.count) seed nodes...")
            
            var edgeCount = 0
            for node in seedNodes {
                let similars = MemoryGraphService.shared.findSimilarNodes(to: node.id, threshold: 0.85, limit: 3, modelContext: ctx)
                for similar in similars {
                    _ = try? MemoryGraphService.shared.createEdge(from: node.id, to: similar.id, type: .similarTo, weight: 0.6, reason: "Auto-linked: embedding similarity", modelContext: ctx)
                    edgeCount += 1
                }
            }
            
            logger.info("Created \(edgeCount) edges between similar nodes")
            
            try? ctx.save()
            logger.info("Memory graph build complete!")
            
            // Run theme extraction so the graph has clusters to display
            await runThemeExtraction(afterBuild: true, context: ctx)
        } catch {
            logger.error("Memory graph build failed: \(error.localizedDescription)")
            await MainActor.run {
                memoryGraphError = "Failed to build memory graph: \(error.localizedDescription)"
                showingMemoryGraphInfo = true
            }
        }
    }

    private func runThemeExtraction(afterBuild: Bool = false, context: ModelContext? = nil) async {
        let ctx = context ?? modelContext
        if !afterBuild {
            guard AIConfigService.shared.config.featureFlags.memoryGraphEnabled else {
                await MainActor.run {
                    memoryGraphError = "Memory Graph is disabled. Enable AIMemoryGraphEnabled in AIConfig.plist to use this feature."
                    showingMemoryGraphInfo = true
                }
                return
            }
            if isBuildingGraph { return }
            await MainActor.run {
                graphActivityMessage = "Extracting themes…"
                isBuildingGraph = true
            }
        } else {
            await MainActor.run {
                graphActivityMessage = "Extracting themes…"
            }
        }
        defer {
            if !afterBuild {
                _Concurrency.Task { @MainActor in
                    isBuildingGraph = false
                    graphActivityMessage = "Building memory graph…"
                }
            }
        }
        Logger.insights.info("Running theme extraction pipeline")
        await ThemeExtractionPipeline.shared.extractThemesOnNarrative(modelContext: ctx)
        await MainActor.run {
            checkMemoryGraphData()
        }
        await loadAnalytics()
    }
}

// MARK: - Focus Ritual Metrics Card

extension InsightsView {
    private var focusRitualsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(KosmicPalette.violet)
                    Text("Focus Rituals")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    if let snapshot = currentSnapshot {
                        Text(String(format: "%.0f%%", snapshot.ritualCompletionRate * 100))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(KosmicPalette.violet)
                    }
                }

                if let snapshot = currentSnapshot {
                    HStack(spacing: 16) {
                        ritualMetric(title: "Morning Streak", value: "\(snapshot.morningRitualStreak) days")
                        ritualMetric(title: "Evening Streak", value: "\(snapshot.eveningRitualStreak) days")
                        ritualMetric(
                            title: "Nudge Response",
                            value: String(format: "%.0f%%", snapshot.nudgeResponseRate * 100)
                        )
                        if let lastReview = snapshot.lastWeeklyReview {
                            ritualMetric(title: "Last Review", value: lastReview.formatted(date: .abbreviated, time: .omitted))
                        } else {
                            ritualMetric(title: "Last Review", value: "Pending")
                        }
                    }
                }

                if !ritualTrend.isEmpty {
                    Chart {
                        ForEach(ritualTrend, id: \.0) { point in
                            LineMark(
                                x: .value("Date", point.0, unit: .day),
                                y: .value("Completion", point.1)
                            )
                            .foregroundStyle(KosmicPalette.violet)
                            AreaMark(
                                x: .value("Date", point.0, unit: .day),
                                y: .value("Completion", point.1)
                            )
                            .foregroundStyle(KosmicPalette.violet.opacity(0.2))
                        }
                    }
                    .transaction { $0.animation = nil }
                    .frame(height: 120)
                } else {
                    Text("Complete a few rituals to unlock consistency insights.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
        }
    }

    private func ritualMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Insight Tabs

enum InsightTab: String, CaseIterable {
    case overview = "Overview"
    case memoryGraph = "Memory Graph"
    case focus = "Focus Analytics"
    case emotional = "Emotional Heatmap"
    case learning = "Learning Loop"
    case connections = "Connections"
    
    var title: String { rawValue }
    
    var subtitle: String {
        switch self {
        case .overview:
            return "Your cognitive state at a glance"
        case .memoryGraph:
            return "Concepts and their relationships"
        case .focus:
            return "Productivity patterns and streaks"
        case .emotional:
            return "Your emotional journey"
        case .learning:
            return "What Aurora learns from you"
        case .connections:
            return "Recurring themes and evolution"
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "brain.head.profile"
        case .memoryGraph:
            return "network"
        case .focus:
            return "chart.bar.fill"
        case .emotional:
            return "heart.circle.fill"
        case .learning:
            return "sparkles"
        case .connections:
            return "link.circle.fill"
        }
    }
}

// MARK: - Intelligence Stat Card

struct IntelligenceStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(16)
            .frame(height: 140)
        }
    }
}

// MARK: - AnalyticsTimeRange Extension

extension AnalyticsTimeRange {
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "Week"
        case .thisMonth: return "Month"
        case .thisQuarter: return "Quarter"
        case .thisYear: return "Year"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Helper Structures (for backwards compatibility)

struct PageInsightsData {
    let pageViewsTotal: Int
    let pageFans: Int
    let pageReach: Int
    let pageImpressions: Int
    let pageEngagedUsers: Int
    let pagePostEngagements: Int
    let pageConsumptions: Int
    
    init(from response: PageInsightsResponse) {
        // Extract values from response data
        var views = 0, fans = 0, reach = 0, impressions = 0
        var engagedUsers = 0, postEngagements = 0, consumptions = 0
        
        for insight in response.data {
            var totalValue: Double = 0
            for rawValue in insight.values {
                if let numeric = rawValue.numericValue {
                    totalValue += numeric
                } else if let breakdown = rawValue.breakdown {
                    totalValue += breakdown.values.reduce(0, +)
                }
            }
            
            switch insight.name {
            case "page_views_total":
                views = Int(totalValue)
            case "page_fans":
                fans = Int(totalValue)
            case "page_reach":
                reach = Int(totalValue)
            case "page_impressions":
                impressions = Int(totalValue)
            case "page_engaged_users":
                engagedUsers = Int(totalValue)
            case "page_post_engagements":
                postEngagements = Int(totalValue)
            case "page_consumptions":
                consumptions = Int(totalValue)
            default:
                break
            }
        }
        
        self.pageViewsTotal = views
        self.pageFans = fans
        self.pageReach = reach
        self.pageImpressions = impressions
        self.pageEngagedUsers = engagedUsers
        self.pagePostEngagements = postEngagements
        self.pageConsumptions = consumptions
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [
            AIConversation.self,
            CloutmateShared.Task.self,
            FocusSession.self,
            ConceptNode.self,
            StoryToken.self
        ])
}
