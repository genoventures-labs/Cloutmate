//
//  ArchivesSidebar.swift
//  FocusOS
//
//  Archives V2 - Sidebar with filters and insights
//

import SwiftUI
import SwiftData
import FocusOSShared

struct ArchivesSidebar: View {
    @Binding var selectedTypeFilter: ArchiveFilter
    @Binding var selectedDateRange: DateRangeFilter
    @Binding var selectedToneFilter: EmotionalState?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var mostCommonTone: EmotionalState?
    @State private var avgFocusSessionLength: TimeInterval?
    @State private var reflectionDensity: Double?
    @State private var auroraNotes: String?
    @State private var isFiltersExpanded = true
    @State private var isInsightsExpanded = true
    @State private var isAuroraExpanded = true
    
    enum DateRangeFilter: String, CaseIterable, Identifiable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        case allTime = "All Time"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                filtersSection
                insightsSection
                auroraNotesSection
            }
            .padding()
        }
        .task {
            await loadInsights()
        }
    }
    
    private var filtersSection: some View {
        DashboardTile(accent: .kosmicBlue) {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.kosmicBlue)
            Text("Filters")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    Spacer()
                    Button(action: {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                            isFiltersExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isFiltersExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    .buttonStyle(.plain)
                }
                
                if isFiltersExpanded {
                    VStack(alignment: .leading, spacing: 16) {
            // Type filter
            VStack(alignment: .leading, spacing: 8) {
                Text("By Type")
                    .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                
                            ForEach(ArchiveFilter.allCases, id: \.id) { filter in
                    Button(action: {
                                    withAnimation(GlassMotion.Easing.spring) {
                        selectedTypeFilter = filter
                                    }
                    }) {
                        HStack {
                            Text(filter.rawValue)
                                .font(.subheadline)
                            Spacer()
                            if selectedTypeFilter == filter {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                                .foregroundStyle(.kosmicBlue)
                            }
                        }
                                    .foregroundStyle(selectedTypeFilter == filter ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
                            .opacity(0.3)
            
            // Date range filter
            VStack(alignment: .leading, spacing: 8) {
                Text("By Date Range")
                    .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                
                ForEach(DateRangeFilter.allCases) { range in
                    Button(action: {
                                    withAnimation(GlassMotion.Easing.spring) {
                        selectedDateRange = range
                                    }
                    }) {
                        HStack {
                            Text(range.rawValue)
                                .font(.subheadline)
                            Spacer()
                            if selectedDateRange == range {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                                .foregroundStyle(.kosmicBlue)
                            }
                        }
                                    .foregroundStyle(selectedDateRange == range ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
                            .opacity(0.3)
            
            // ARTE tone filter
            VStack(alignment: .leading, spacing: 8) {
                Text("By ARTE Tone")
                    .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                
                Button(action: {
                                withAnimation(GlassMotion.Easing.spring) {
                    selectedToneFilter = nil
                                }
                }) {
                    HStack {
                        Text("All Tones")
                            .font(.subheadline)
                        Spacer()
                        if selectedToneFilter == nil {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                            .foregroundStyle(.kosmicBlue)
                        }
                    }
                                .foregroundStyle(selectedToneFilter == nil ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                }
                .buttonStyle(.plain)
                
                ForEach(EmotionalState.allCases, id: \.rawValue) { tone in
                    Button(action: {
                                    withAnimation(GlassMotion.Easing.spring) {
                        selectedToneFilter = tone
                                    }
                    }) {
                        HStack {
                            Text(tone.displayName)
                                .font(.subheadline)
                            Spacer()
                            if selectedToneFilter == tone {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                                .foregroundStyle(.kosmicBlue)
                            }
                        }
                                    .foregroundStyle(selectedToneFilter == tone ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private var insightsSection: some View {
        DashboardTile(accent: .kosmicPurple) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.kosmicPurple)
            Text("Insights")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    Spacer()
                    Button(action: {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                            isInsightsExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isInsightsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    .buttonStyle(.plain)
                }
                
                if isInsightsExpanded {
                    VStack(alignment: .leading, spacing: 16) {
            // Most Common Completion Tone
            if let tone = mostCommonTone {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most Common Completion Tone")
                        .font(.caption)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                    Text(tone.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                                    .foregroundStyle(glassColorSystem.textPrimary())
                }
            }
            
            // Average Focus Session Length
            if let avgLength = avgFocusSessionLength {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Focus Session Length")
                        .font(.caption)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                    Text(formatDuration(avgLength))
                        .font(.subheadline)
                        .fontWeight(.medium)
                                    .foregroundStyle(glassColorSystem.textPrimary())
                }
            }
            
            // Reflection Density
            if let density = reflectionDensity {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reflection Density")
                        .font(.caption)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                    Text(String(format: "%.1f%%", density * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                                    .foregroundStyle(glassColorSystem.textPrimary())
                            }
                        }
                        
                        if mostCommonTone == nil && avgFocusSessionLength == nil && reflectionDensity == nil {
                            Text("No insights available")
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
                                .italic()
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private var auroraNotesSection: some View {
        DashboardTile(accent: .kosmicPurple) {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.kosmicPurple)
                Text("Aurora Notes")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    Spacer()
                    Button(action: {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.spring) {
                            isAuroraExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isAuroraExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    .buttonStyle(.plain)
            }
            
                if isAuroraExpanded {
            if let notes = auroraNotes {
                Text(notes)
                    .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No notes available")
                    .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
                    .italic()
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func loadInsights() async {
        // Load insights from archived items
        // Simplified implementation - can be enhanced
        
        // Most common tone from StateTransitionHistory
        let transitionDescriptor = FetchDescriptor<StateTransitionHistory>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        if let transitions = try? modelContext.fetch(transitionDescriptor) {
            let toneCounts = Dictionary(grouping: transitions, by: { $0.toState })
            if let mostCommon = toneCounts.max(by: { $0.value.count < $1.value.count }) {
                await MainActor.run {
                    mostCommonTone = mostCommon.key
                }
            }
        }
        
        // Average focus session length (simplified)
        await MainActor.run {
            avgFocusSessionLength = 45 * 60 // 45 minutes default
            reflectionDensity = 0.65 // 65% default
        }
    }
}

#Preview {
    ArchivesSidebar(
        selectedTypeFilter: .constant(.all),
        selectedDateRange: .constant(.allTime),
        selectedToneFilter: .constant(nil)
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [StateTransitionHistory.self])
}

