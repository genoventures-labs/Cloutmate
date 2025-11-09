//
//  AuroraSelfReflectionView.swift
//  Cloutmate
//
//  Self-Reflection Diagnostic View for Aurora
//  Displays Aurora's introspection about her own cognitive state
//

import SwiftUI
import SwiftData

struct AuroraSelfReflectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AuroraSelfDiagnostic.generatedAt, order: .reverse) private var diagnostics: [AuroraSelfDiagnostic]
    
    @State private var selectedPeriod: String = "quarter"
    @State private var isGenerating: Bool = false
    @State private var showDebugMode: Bool = false
    @State private var currentDiagnostic: AuroraSelfDiagnostic?
    
    private let periods = ["week", "month", "quarter", "year"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Natural Language Summary
                if let diagnostic = currentDiagnostic ?? diagnostics.first {
                    naturalLanguageSection(diagnostic)
                    
                    // Expandable Sections
                    DisclosureGroup("Memory Management", isExpanded: .constant(true)) {
                        memoryManagementSection(diagnostic)
                    }
                    .padding(.vertical, 8)
                    
                    DisclosureGroup("Pattern Recognition") {
                        patternRecognitionSection(diagnostic)
                    }
                    .padding(.vertical, 8)
                    
                    DisclosureGroup("Graph Health") {
                        graphHealthSection(diagnostic)
                    }
                    .padding(.vertical, 8)
                    
                    if showDebugMode {
                        DisclosureGroup("Debug Metrics") {
                            debugMetricsSection(diagnostic)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Aurora's Self-Reflection")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await generateDiagnostic() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isGenerating)
            }
            
            ToolbarItem(placement: .automatic) {
                Toggle("Debug", isOn: $showDebugMode)
                    .toggleStyle(.switch)
            }
        }
        .task {
            if currentDiagnostic == nil {
                currentDiagnostic = diagnostics.first
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(.kosmicBlue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aurora's Self-Reflection")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("A system view of Aurora's cognitive state and memory management")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Picker("Period", selection: $selectedPeriod) {
                ForEach(periods, id: \.self) { period in
                    Text(period.capitalized).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) { _, _ in
                Task { await generateDiagnostic() }
            }
        }
    }
    
    // MARK: - Natural Language Section
    
    private func naturalLanguageSection(_ diagnostic: AuroraSelfDiagnostic) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundStyle(.kosmicBlue)
                    Text("Aurora's Reflection")
                        .font(.headline)
                }
                
                Text(diagnostic.naturalLanguageSummary)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
    }
    
    // MARK: - Memory Management Section
    
    private func memoryManagementSection(_ diagnostic: AuroraSelfDiagnostic) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                DiagnosticStatRow(
                    label: "Total Memories Summarized",
                    value: "\(diagnostic.totalMemoriesSummarized)",
                    icon: "doc.text.fill"
                )
                
                DiagnosticStatRow(
                    label: "Compressed Themes",
                    value: "\(diagnostic.compressedThemesCount)",
                    icon: "archivebox.fill"
                )
                
                DiagnosticStatRow(
                    label: "Active Themes",
                    value: "\(diagnostic.activeThemesCount)",
                    icon: "sparkles"
                )
                
                DiagnosticStatRow(
                    label: "Compression Ratio",
                    value: String(format: "%.1f%%", diagnostic.compressionRatio * 100),
                    icon: "arrow.down.circle.fill"
                )
                
                DiagnosticStatRow(
                    label: "Space Saved",
                    value: diagnostic.formattedSpaceSaved,
                    icon: "externaldrive.fill"
                )
                
                DiagnosticStatRow(
                    label: "Memory Revivals",
                    value: "\(diagnostic.revivalCount)",
                    icon: "arrow.clockwise.circle.fill"
                )
            }
        }
    }
    
    // MARK: - Pattern Recognition Section
    
    private func patternRecognitionSection(_ diagnostic: AuroraSelfDiagnostic) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                if !diagnostic.topRecurringMotifs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Recurring Motifs")
                            .font(.headline)
                        
                        ForEach(diagnostic.topRecurringMotifs.prefix(5), id: \.self) { motif in
                            HStack {
                                Text("•")
                                    .foregroundStyle(.kosmicBlue)
                                Text(motif)
                                Spacer()
                                if let frequency = diagnostic.motifFrequencies[motif] {
                                    Text("\(frequency)x")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                
                if !diagnostic.themeGrowth.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme Growth")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        ForEach(Array(diagnostic.themeGrowth.sorted { $0.value > $1.value }.prefix(3)), id: \.key) { theme, growth in
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(.green)
                                Text(theme)
                                Spacer()
                                Text("+\(Int(growth))%")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                if !diagnostic.themeDecline.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme Decline")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        ForEach(Array(diagnostic.themeDecline.sorted { $0.value > $1.value }.prefix(3)), id: \.key) { theme, decline in
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.orange)
                                Text(theme)
                                Spacer()
                                Text("-\(Int(decline))%")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Graph Health Section
    
    private func graphHealthSection(_ diagnostic: AuroraSelfDiagnostic) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                DiagnosticStatRow(
                    label: "Active Nodes",
                    value: "\(diagnostic.activeNodesCount)",
                    icon: "circle.fill"
                )
                
                DiagnosticStatRow(
                    label: "Total Edges",
                    value: "\(diagnostic.totalEdgesCount)",
                    icon: "line.3.horizontal"
                )
                
                DiagnosticStatRow(
                    label: "Clusters",
                    value: "\(diagnostic.clusterCount)",
                    icon: "square.stack.3d.up.fill"
                )
                
                DiagnosticStatRow(
                    label: "Avg Connection Strength",
                    value: String(format: "%.2f", diagnostic.averageConnectionStrength),
                    icon: "link.circle.fill"
                )
                
                DiagnosticStatRow(
                    label: "Node Density",
                    value: String(format: "%.2f", diagnostic.nodeDensity),
                    icon: "grid.circle.fill"
                )
            }
        }
    }
    
    // MARK: - Debug Metrics Section
    
    private func debugMetricsSection(_ diagnostic: AuroraSelfDiagnostic) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Raw Diagnostic Data")
                    .font(.headline)
                
                Text("""
                Period: \(diagnostic.period)
                Generated: \(diagnostic.generatedAt.formatted(date: .abbreviated, time: .shortened))
                
                Motif Frequencies: \(diagnostic.motifFrequencies.count) entries
                Theme Growth: \(diagnostic.themeGrowth.count) entries
                Theme Decline: \(diagnostic.themeDecline.count) entries
                """)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("No Diagnostic Available")
                    .font(.headline)
                
                Text("Generate Aurora's first self-reflection diagnostic to see her cognitive state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    Task { await generateDiagnostic() }
                } label: {
                    Label("Generate Diagnostic", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.kosmicBlue)
                .disabled(isGenerating)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Actions
    
    private func generateDiagnostic() async {
        isGenerating = true
        defer { isGenerating = false }
        
        let diagnostic = await AuroraSelfReflectionService.shared.generateDiagnostic(
            period: selectedPeriod,
            modelContext: modelContext
        )
        
        await MainActor.run {
            currentDiagnostic = diagnostic
        }
    }
}

// MARK: - Diagnostic Stat Row Component

private struct DiagnosticStatRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.kosmicBlue)
                .frame(width: 24)
            
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    NavigationStack {
        AuroraSelfReflectionView()
            .modelContainer(for: [AuroraSelfDiagnostic.self])
    }
}

