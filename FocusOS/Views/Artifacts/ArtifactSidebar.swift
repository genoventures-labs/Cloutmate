//
//  ArtifactSidebar.swift
//  FocusOS
//
//  Artifacts V2 - Sidebar with filters and suggestions
//

import SwiftUI
import SwiftData
import FocusOSShared

struct ArtifactSidebar: View {
    let artifacts: [Artifact]
    let filteredArtifacts: [Artifact]
    let onFilterChanged: (ArtifactFilter) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isTypeExpanded = true
    @State private var isToneExpanded = true
    @State private var isRecencyExpanded = true
    @State private var isSuggestionsExpanded = true
    @State private var auroraInsight: String = ""
    
    var artifactsNeedingReview: [Artifact] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return artifacts.filter { artifact in
            artifact.artifactState == .draft && artifact.updatedAt < sevenDaysAgo
        }
    }
    
    var unlinkedDrafts: [Artifact] {
        artifacts.filter { artifact in
            artifact.artifactState == .draft && artifact.linkedEntityIds.isEmpty
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Type Filter
                DashboardSectionPanel(
                    title: "Type",
                    icon: "doc.text",
                    accent: .kosmicBlue,
                    isCollapsed: Binding(
                        get: { !isTypeExpanded },
                        set: { isTypeExpanded = !$0 }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Button(action: {
                                // Filter by type
                            }) {
                                HStack {
                                    Text(format.displayName)
                                        .font(.caption)
                                        .foregroundColor(glassColorSystem.textPrimary())
                                    Spacer()
                                    Text("\(artifacts.filter { $0.format == format }.count)")
                                        .font(.caption2)
                                        .foregroundColor(glassColorSystem.textTertiary())
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // ARTE Tone Filter
                DashboardSectionPanel(
                    title: "ARTE Tone",
                    icon: "paintpalette",
                    accent: .kosmicPurple,
                    isCollapsed: Binding(
                        get: { !isToneExpanded },
                        set: { isToneExpanded = !$0 }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(EmotionalState.allCases, id: \.self) { tone in
                            Button(action: {
                                // Filter by tone
                            }) {
                                HStack {
                                    Image(systemName: tone.iconName)
                                        .foregroundColor(EmotionalPalette.palette(for: tone).backgroundTint)
                                        .font(.caption)
                                    Text(tone.displayName)
                                        .font(.caption)
                                        .foregroundColor(glassColorSystem.textPrimary())
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Recency Filter
                DashboardSectionPanel(
                    title: "Recency",
                    icon: "clock",
                    accent: .kosmicGreen,
                    isCollapsed: Binding(
                        get: { !isRecencyExpanded },
                        set: { isRecencyExpanded = !$0 }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {}) {
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Text("This Week")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Text("This Month")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Smart Suggestions
                DashboardSectionPanel(
                    title: "Suggestions",
                    icon: "lightbulb.fill",
                    accent: .orange,
                    isCollapsed: Binding(
                        get: { !isSuggestionsExpanded },
                        set: { isSuggestionsExpanded = !$0 }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !artifactsNeedingReview.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Artifacts needing review")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(glassColorSystem.textPrimary())
                                
                                Text("\(artifactsNeedingReview.count) draft\(artifactsNeedingReview.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(glassColorSystem.textTertiary())
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if !unlinkedDrafts.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unlinked drafts")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(glassColorSystem.textPrimary())
                                
                                Text("\(unlinkedDrafts.count) draft\(unlinkedDrafts.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(glassColorSystem.textTertiary())
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if artifactsNeedingReview.isEmpty && unlinkedDrafts.isEmpty {
                            Text("All artifacts are up to date")
                                .font(.caption)
                                .foregroundColor(glassColorSystem.textTertiary())
                                .padding(.vertical, 4)
                        }
                    }
                }
                
                // Aurora Echo Card
                if !auroraInsight.isEmpty {
                    GlassPanel(tier: .contentCard, cornerRadius: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.kosmicPurple)
                                Text("Aurora Insight")
                                    .font(.headline)
                                    .foregroundColor(glassColorSystem.textPrimary())
                            }
                            
                            Text(auroraInsight)
                                .font(.body)
                                .foregroundColor(glassColorSystem.textSecondary())
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(glassColorSystem.backgroundColor())
        .task {
            loadAuroraInsight()
        }
    }
    
    private func loadAuroraInsight() {
        // Placeholder - will be integrated with AuroraPredictiveService
        let stats = ArtifactAnalyticsService.shared.frequencyStats(modelContext: modelContext)
        if stats.artifactsPerWeek > 0 {
            auroraInsight = "You're creating \(String(format: "%.1f", stats.artifactsPerWeek)) artifacts per week. Keep up the momentum!"
        } else {
            auroraInsight = "Start creating artifacts to track your creative output."
        }
    }
}

#Preview {
    ArtifactSidebar(
        artifacts: [],
        filteredArtifacts: [],
        onFilterChanged: { _ in }
    )
    .environmentObject(GlassColorSystem())
}

