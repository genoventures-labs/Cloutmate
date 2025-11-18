//
//  ConnectionsTabView.swift
//  FocusOS
//

import SwiftUI
import SwiftData

struct ConnectionsTabView: View {
    let snapshot: AnalyticsSnapshot?
    let topConcepts: [(name: String, salience: Double, count: Int)]
    let timeRange: AnalyticsTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            recurringMotifs
            themeEvolution
            longTermSummary
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connections").font(.system(size: 24, weight: .bold))
                Text("Recurring themes and concept evolution").font(.system(size: 14)).foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var recurringMotifs: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles").foregroundColor(KosmicPalette.violet)
                    Text("Recurring Motifs").font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                if !topConcepts.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(topConcepts, id: \.name) { concept in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(concept.name).font(.system(size: 16, weight: .semibold))
                                    Text("Mentioned \(concept.count) times").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f", concept.salience)).font(.system(size: 20, weight: .bold)).foregroundColor(KosmicPalette.cyan)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
                        }
                    }
                } else {
                    Text("No themes detected yet. Continue working and reflecting.")
                        .font(.system(size: 14)).foregroundColor(.secondary).padding(.vertical, 8)
                }
            }
            .padding(20)
        }
    }

    private var themeEvolution: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "arrow.triangle.branch").foregroundColor(KosmicPalette.cyan)
                    Text("Theme Evolution").font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                if let snapshot {
                    Text("In the last \(timeRange.displayName.lowercased()), \(snapshot.activeThemes) themes emerged from \(snapshot.memoryNodes) memory nodes")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                }
                Text("Theme evolution visualization coming soon").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.7)).italic().padding(.vertical, 8)
            }
            .padding(20)
        }
    }

    private var longTermSummary: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath").foregroundColor(KosmicPalette.violet)
                    Text("Long-term Memory").font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                if let snapshot {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Graph Density: \(String(format: "%.1f%%", snapshot.graphDensity * 100))")
                        Text("Total Concepts: \(snapshot.conceptCount)")
                        Text("Memory Nodes: \(snapshot.memoryNodes)")
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
}


