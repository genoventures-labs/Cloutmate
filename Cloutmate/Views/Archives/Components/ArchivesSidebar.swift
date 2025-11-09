//
//  ArchivesSidebar.swift
//  Cloutmate
//
//  Archives V2 - Sidebar with filters and insights
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ArchivesSidebar: View {
    @Binding var selectedTypeFilter: ArchiveFilter
    @Binding var selectedDateRange: DateRangeFilter
    @Binding var selectedToneFilter: EmotionalState?
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var mostCommonTone: EmotionalState?
    @State private var avgFocusSessionLength: TimeInterval?
    @State private var reflectionDensity: Double?
    @State private var auroraNotes: String?
    
    enum DateRangeFilter: String, CaseIterable, Identifiable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        case allTime = "All Time"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                filtersSection
                insightsSection
                auroraNotesSection
            }
            .padding()
        }
        .frame(width: 240)
        .background(glassColorSystem.backgroundElevated())
        .task {
            await loadInsights()
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
            
            // Type filter
            VStack(alignment: .leading, spacing: 8) {
                Text("By Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(ArchiveFilter.allCases) { filter in
                    Button(action: {
                        selectedTypeFilter = filter
                    }) {
                        HStack {
                            Text(filter.rawValue)
                                .font(.subheadline)
                            Spacer()
                            if selectedTypeFilter == filter {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                        .foregroundColor(selectedTypeFilter == filter ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // Date range filter
            VStack(alignment: .leading, spacing: 8) {
                Text("By Date Range")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(DateRangeFilter.allCases) { range in
                    Button(action: {
                        selectedDateRange = range
                    }) {
                        HStack {
                            Text(range.rawValue)
                                .font(.subheadline)
                            Spacer()
                            if selectedDateRange == range {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                        .foregroundColor(selectedDateRange == range ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // ARTE tone filter
            VStack(alignment: .leading, spacing: 8) {
                Text("By ARTE Tone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    selectedToneFilter = nil
                }) {
                    HStack {
                        Text("All Tones")
                            .font(.subheadline)
                        Spacer()
                        if selectedToneFilter == nil {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.kosmicBlue)
                        }
                    }
                    .foregroundColor(selectedToneFilter == nil ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                
                ForEach(EmotionalState.allCases, id: \.rawValue) { tone in
                    Button(action: {
                        selectedToneFilter = tone
                    }) {
                        HStack {
                            Text(tone.displayName)
                                .font(.subheadline)
                            Spacer()
                            if selectedToneFilter == tone {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                        .foregroundColor(selectedToneFilter == tone ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
            Color.clear
        })
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
            
            // Most Common Completion Tone
            if let tone = mostCommonTone {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most Common Completion Tone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tone.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Average Focus Session Length
            if let avgLength = avgFocusSessionLength {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Focus Session Length")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(avgLength))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Reflection Density
            if let density = reflectionDensity {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reflection Density")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", density * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
            Color.clear
        })
    }
    
    private var auroraNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.kosmicPurple)
                Text("Aurora Notes")
                    .font(.headline)
            }
            
            if let notes = auroraNotes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No notes available")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
        .padding()
        .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
            Color.clear
        })
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

