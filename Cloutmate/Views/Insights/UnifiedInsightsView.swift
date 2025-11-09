//
//  UnifiedInsightsView.swift
//  Cloutmate
//
//  Insights V2 - Unified Dashboard Layout
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UnifiedInsightsView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    let searchText: String
    let selectedViewType: InsightsViewType
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Content based on selected view type
                    switch selectedViewType {
                    case .focus:
                        FocusAnalyticsView(snapshot: snapshot, timeRange: timeRange)
                            .frame(minHeight: geometry.size.height)
                        
                    case .emotion:
                        EmotionAnalyticsView(snapshot: snapshot, timeRange: timeRange)
                            .frame(minHeight: geometry.size.height)
                        
                    case .habits:
                        HabitMetricsView(snapshot: snapshot, timeRange: timeRange)
                            .frame(minHeight: geometry.size.height)
                        
                    case .cognition:
                        CognitiveForecastView(snapshot: snapshot, timeRange: timeRange)
                            .frame(minHeight: geometry.size.height)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
        .background(
            GlassPanel(tier: .background, cornerRadius: 0) {
                Color(.windowBackgroundColor)
            }
        )
    }
}

#Preview {
    UnifiedInsightsView(
        snapshot: nil,
        timeRange: .thisWeek,
        searchText: "",
        selectedViewType: .focus
    )
    .modelContainer(for: [
        FocusSession.self,
        StateTransitionHistory.self,
        RitualCompletion.self,
        FocusForecast.self,
        Project.self
    ])
    .environmentObject(GlassColorSystem())
    .environmentObject(ReactiveThemeManager.shared)
    .padding()
}

