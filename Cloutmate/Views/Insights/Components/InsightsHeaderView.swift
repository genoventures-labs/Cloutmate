//
//  InsightsHeaderView.swift
//  Cloutmate
//
//  Insights V2 - Unified Header Zone
//

import SwiftUI
import CloutmateShared

enum InsightsViewType: String, CaseIterable {
    case focus = "Focus"
    case emotion = "Emotion"
    case habits = "Habits"
    case cognition = "Cognition"
}

struct InsightsHeaderView: View {
    @Binding var selectedTimeRange: AnalyticsTimeRange
    @Binding var selectedViewType: InsightsViewType
    @Binding var searchText: String
    let onExport: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollOffset: CGFloat = 0
    @State private var showingExportMenu = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Title and Subline
                VStack(alignment: .leading, spacing: 4) {
                    Text("Insights")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Aurora's reflection of your patterns and focus")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    TextField("Search focus trends, reflections…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassPanel(tier: .contentCard, cornerRadius: 10)
                
                // Filter Controls
                VStack(spacing: 12) {
                    // Timeframe filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([AnalyticsTimeRange.today, .thisWeek, .thisMonth, .thisYear], id: \.self) { range in
                                FilterPill(
                                    title: range.displayName,
                                    isSelected: selectedTimeRange == range,
                                    action: {
                                        if reduceMotion {
                                            selectedTimeRange = range
                                        } else {
                                            withAnimation(GlassMotion.Easing.spring) {
                                                selectedTimeRange = range
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    
                    // View type filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(InsightsViewType.allCases, id: \.self) { viewType in
                                FilterPill(
                                    title: viewType.rawValue,
                                    isSelected: selectedViewType == viewType,
                                    action: {
                                        if reduceMotion {
                                            selectedViewType = viewType
                                        } else {
                                            withAnimation(GlassMotion.Easing.spring) {
                                                selectedViewType = viewType
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                
                // Quick Export Button
                HStack {
                    Spacer()
                    Menu {
                        Button(action: {
                            onExport()
                        }) {
                            Label("Export as PDF", systemImage: "doc.fill")
                        }
                        
                        Button(action: {
                            onExport()
                        }) {
                            Label("Export as Markdown", systemImage: "doc.text.fill")
                        }
                    } label: {
                        GlassButton(
                            nil,
                            icon: "square.and.arrow.up",
                            style: .iconOnly,
                            role: .surface,
                            action: {
                                showingExportMenu.toggle()
                            }
                        )
                        .frame(width: 40, height: 40)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                GlassPanel(tier: .overlay, cornerRadius: 0) {
                    LinearGradient(
                        colors: [Color.kosmicBlue.opacity(0.1), Color.kosmicPurple.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .background(
                GeometryReader { proxy in
                    SwiftUI.Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                }
            )
            .opacity(max(0.7, 1.0 - abs(scrollOffset) / 200.0))
        }
        .frame(height: 220)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
    }
}

#Preview {
    InsightsHeaderView(
        selectedTimeRange: .constant(.thisWeek),
        selectedViewType: .constant(.focus),
        searchText: .constant(""),
        onExport: {}
    )
    .environmentObject(GlassColorSystem())
    .padding()
}

