//
//  InsightsHeaderView.swift
//  FocusOS
//
//  Insights V2 - Unified Header Zone
//

import SwiftUI
import FocusOSShared

enum InsightsViewType: String, CaseIterable {
    case focus = "Focus"
    case emotion = "Emotion"
    case habits = "Habits"
    case cognition = "Cognition"
}

enum InsightsExportFormat: String {
    case pdf = "PDF"
    case markdown = "Markdown"
}

struct InsightsHeaderView: View {
    @Binding var selectedTimeRange: AnalyticsTimeRange
    @Binding var selectedViewType: InsightsViewType
    @Binding var searchText: String
    let onExport: (InsightsExportFormat) -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insights")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                        Text("Aurora's reflection of your patterns and focus")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 12)
                    
                    exportButton
                }
                
                GlassDivider()
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search focus trends, reflections…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                
                GlassDivider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeframe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([AnalyticsTimeRange.today, .thisWeek, .thisMonth, .thisYear], id: \.self) { range in
                                FilterPill(
                                    title: range.displayName,
                                    isSelected: selectedTimeRange == range,
                                    action: {
                                        updateTimeRange(to: range)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Perspective")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(InsightsViewType.allCases, id: \.self) { viewType in
                                FilterPill(
                                    title: viewType.rawValue,
                                    isSelected: selectedViewType == viewType,
                                    action: {
                                        updateViewType(to: viewType)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private var exportButton: some View {
        Menu {
            Button {
                onExport(.pdf)
            } label: {
                Label("Export as PDF", systemImage: "doc.richtext")
            }
            
            Button {
                onExport(.markdown)
            } label: {
                Label("Export as Markdown", systemImage: "doc.text")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Export")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.kosmicBlue, .kosmicPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(Capsule())
            )
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .menuStyle(.borderlessButton)
    }
    
    private func updateTimeRange(to range: AnalyticsTimeRange) {
        guard selectedTimeRange != range else { return }
        if reduceMotion {
            selectedTimeRange = range
        } else {
            withAnimation(GlassMotion.Easing.spring) {
                selectedTimeRange = range
            }
        }
    }
    
    private func updateViewType(to viewType: InsightsViewType) {
        guard selectedViewType != viewType else { return }
        if reduceMotion {
            selectedViewType = viewType
        } else {
            withAnimation(GlassMotion.Easing.spring) {
                selectedViewType = viewType
            }
        }
    }
}

#Preview {
    InsightsHeaderView(
        selectedTimeRange: .constant(.thisWeek),
        selectedViewType: .constant(.focus),
        searchText: .constant(""),
        onExport: { _ in }
    )
    .environmentObject(GlassColorSystem())
    .padding()
}

