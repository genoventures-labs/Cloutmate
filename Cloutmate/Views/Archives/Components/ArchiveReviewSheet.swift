//
//  ArchiveReviewSheet.swift
//  Cloutmate
//
//  Archives V2 - Review Summary sheet
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct ArchiveReviewSheet: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var dateRange: DateRange = .thisWeek
    @State private var auroraInsight: String?
    @State private var isLoading = false
    @State private var snapshot: ArchiveAnalyticsSnapshot?
    
    enum DateRange: String, CaseIterable, Identifiable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dateRangeSelector
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let snapshot {
                        statsGrid(for: snapshot)
                        chartsSection(snapshot: snapshot)
                        archivedItemsSection(snapshot: snapshot)
                        auroraInsightCard
                    } else {
                        ContentUnavailableView(
                            "No archived items",
                            systemImage: "archivebox",
                            description: Text("Archive items to generate a review summary.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("Review Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
        .task {
            await loadData()
        }
    }
    
    private var dateRangeSelector: some View {
        Picker("Date Range", selection: $dateRange) {
            ForEach(DateRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: dateRange) { oldValue, newValue in
            _Concurrency.Task {
                await loadData()
            }
        }
    }
    
    private func statsGrid(for snapshot: ArchiveAnalyticsSnapshot) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
        return LazyVGrid(columns: columns, spacing: 16) {
            statCard(
                title: "Archived Items",
                value: "\(snapshot.totalArchived)",
                footer: dateRange.rawValue,
                icon: "archivebox.fill",
                tint: .kosmicBlue
            )
            
            statCard(
                title: "Projects Archived",
                value: "\(snapshot.countsByType[.projects] ?? 0)",
                footer: "Projects in this range",
                icon: "folder.fill",
                tint: .kosmicBlue
            )
            
            statCard(
                title: "Notes Archived",
                value: "\(snapshot.countsByType[.notes] ?? 0)",
                footer: "Notes captured",
                icon: "doc.text.fill",
                tint: .kosmicPurple
            )
            
            statCard(
                title: "Top Tone",
                value: snapshot.mostCommonTone?.displayName ?? "No data",
                footer: "Dominant ARTE tone",
                icon: snapshot.mostCommonTone?.iconName ?? "sparkles",
                tint: .kosmicGreen
            )
            
            statCard(
                title: "Reflections",
                value: "\(snapshot.reflectionsCount)",
                footer: "AI reflections generated",
                icon: "bubble.left.and.bubble.right.fill",
                tint: .kosmicPurple
            )
            
            let themeCount = snapshot.learningThemes.keys.count
            statCard(
                title: "Learning Themes",
                value: themeCount > 0 ? "\(themeCount)" : "0",
                footer: "Patterns surfaced",
                icon: "sparkles",
                tint: .orange
            )
        }
    }
    
    private func statCard(title: String, value: String, footer: String, icon: String, tint: Color) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(tint)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(value)
                    .font(.title2.weight(.semibold))
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
    }
    
    private func chartsSection(snapshot: ArchiveAnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics")
                .font(.headline)
            
            itemsByTypeChart(snapshot: snapshot)
            arteToneChart(snapshot: snapshot)
            learningThemesCard(snapshot: snapshot)
        }
    }
    
    @ViewBuilder
    private func itemsByTypeChart(snapshot: ArchiveAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Archived by Type")
                    .font(.subheadline.weight(.medium))
                if snapshot.countsByType.isEmpty {
                    Text("No archived items in this range.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Chart {
                        ForEach(ArchiveFilter.allCases.filter { $0 != .all }, id: \.self) { filter in
                            if let count = snapshot.countsByType[filter], count > 0 {
                                BarMark(
                                    x: .value("Count", count),
                                    y: .value("Type", filter.rawValue)
                                )
                                .foregroundStyle(.linearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing))
                            }
                        }
                    }
                    .frame(height: 160)
                    .transaction { $0.animation = nil }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func arteToneChart(snapshot: ArchiveAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ARTE Tone Distribution")
                    .font(.subheadline.weight(.medium))
                
                if snapshot.toneCounts.isEmpty {
                    Text("No ARTE tone data for this range.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Chart {
                        ForEach(EmotionalState.allCases, id: \.self) { tone in
                            if let count = snapshot.toneCounts[tone], count > 0 {
                                BarMark(
                                    x: .value("Tone", tone.displayName),
                                    y: .value("Count", count)
                                )
                                .foregroundStyle(kosmicColor(for: tone))
                            }
                        }
                    }
                    .frame(height: 180)
                    .transaction { $0.animation = nil }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func learningThemesCard(snapshot: ArchiveAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Learning Themes")
                    .font(.subheadline.weight(.medium))
                if snapshot.learningThemes.isEmpty {
                    Text("No learning themes detected for this range.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(snapshot.learningThemes.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { theme, count in
                        HStack {
                            Text(theme)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func kosmicColor(for tone: EmotionalState) -> Color {
        switch tone {
        case .focused: return .kosmicBlue
        case .reflective: return .kosmicPurple
        case .calm: return .gray
        case .energized: return .orange
        case .fatigued: return .red.opacity(0.8)
        }
    }
    
    private func archivedItemsSection(snapshot: ArchiveAnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Archived")
                .font(.headline)
            
            if snapshot.recentItems.isEmpty {
                GlassPanel(tier: .contentCard, cornerRadius: 12) {
                    Text("No archived items available in this date range.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(snapshot.recentItems.prefix(6)) { entry in
                        GlassPanel(tier: .contentCard, cornerRadius: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: icon(for: entry.item))
                                    .foregroundColor(color(for: entry.item))
                                    .font(.headline)
                                    .frame(width: 28, height: 28)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.subheadline.weight(.semibold))
                                    if let summary = entry.summary, !summary.isEmpty {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        if let date = entry.archivedAt {
                                            Text(date, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(entry.entityType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if let tone = entry.tone {
                                            Label(tone.displayName, systemImage: tone.iconName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                        }
                    }
                }
            }
        }
    }
    
    private var auroraInsightCard: some View {
        GlassPanel(tier: .overlay, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("Aurora Insight")
                        .font(.headline)
                }
                
                if let insight = auroraInsight {
                    Text(insight)
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("Generating insights...")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .italic()
                }
            }
            .padding()
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        snapshot = ArchiveAnalyticsService.shared.snapshot(for: analyticsRange(for: dateRange), modelContext: modelContext)
        
        // Generate Aurora insight
        let prompt = "Generate a brief insight summary about archived items for \(dateRange.rawValue). Focus on patterns, emotional continuity, and learning outcomes."
        
        do {
            let insight = try await CoreResponseService.shared.generateResponse(
                for: prompt,
                context: "",
                modelContext: modelContext
            )
            await MainActor.run {
                auroraInsight = insight
            }
        } catch {
            await MainActor.run {
                auroraInsight = "Unable to generate insights at this time."
            }
        }
        
        isLoading = false
    }
    
    private func icon(for item: ArchiveItem) -> String {
        switch item {
        case .project: return "folder.fill"
        case .area: return "rectangle.stack.fill"
        case .note: return "doc.text.fill"
        case .artifact: return "brain.head.profile"
        case .draft: return "doc.text"
        }
    }
    
    private func color(for item: ArchiveItem) -> Color {
        switch item {
        case .project: return .kosmicBlue
        case .area: return .gray
        case .note: return .kosmicPurple
        case .artifact: return .kosmicGreen
        case .draft: return .kosmicBlue
        }
    }
    
    private func analyticsRange(for range: DateRange) -> ArchiveReviewRange {
        switch range {
        case .thisWeek: return .thisWeek
        case .thisMonth: return .thisMonth
        case .allTime: return .allTime
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    ArchiveReviewSheet(isPresented: $isPresented)
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [ArchiveReflection.self])
}

