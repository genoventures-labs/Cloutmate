//
//  ArchiveReviewSheet.swift
//  Cloutmate
//
//  Archives V2 - Review Summary sheet
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ArchiveReviewSheet: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var dateRange: DateRange = .thisWeek
    @State private var auroraInsight: String?
    @State private var isLoading = false
    
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
                    } else {
                        chartsSection
                        archivedItemsSection
                        auroraInsightCard
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
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics")
                .font(.headline)
            
            // Weekly Completion Overview (placeholder)
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Completion Overview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Chart visualization coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // ARTE Emotional Distribution (placeholder)
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ARTE Emotional Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Chart visualization coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Top Learning Themes (placeholder)
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Learning Themes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Theme analysis coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
    
    private var archivedItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Archived")
                .font(.headline)
            
            // Placeholder for archived items list
            Text("Archived items list coming soon")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
                    Color.clear
                })
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
}

#Preview {
    @Previewable @State var isPresented = true
    
    ArchiveReviewSheet(isPresented: $isPresented)
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [ArchiveReflection.self])
}

