//
//  DashboardViewV2.swift
//  Cloutmate
//
//  Dashboard V2 - Main container view integrating all dashboard components
//

import SwiftUI
import SwiftData

struct DashboardViewV2: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var showAuroraInsights = false
    @State private var showDailySummary = false
    
    var body: some View {
        V2GlassContentScaffold(
            accentGradient: AuroraPalette.linearGradient(for: .dark),
            showsSidebar: false,
            header: { headerBar },
            content: { dashboardContent },
            sidebar: { EmptyView() }
                        )
        .overlay(alignment: .trailing) {
                if showAuroraInsights {
                    AuroraInsightsDrawer(isPresented: $showAuroraInsights)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(100)
                }
            }
        .sheet(isPresented: $showDailySummary) {
            DailySummaryView()
        }
    }
}

private extension DashboardViewV2 {
    var headerBar: some View {
        V2GlassHeaderBar(
            title: "Dashboard",
            subtitle: "Snapshot of the day across focus, rituals, and reflections."
        )
    }
    
    @ViewBuilder
    var dashboardContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                DailyOverviewPanel()
                    .padding(.horizontal, 4)
                
                ActiveWorkfeedView()
                    .padding(.horizontal, 4)
                
                RitualsSummaryView()
                    .padding(.horizontal, 4)
                
                ReflectionFeedView()
                    .padding(.horizontal, 4)
                
                DashboardFooterView(
                    onEndOfDaySummary: {
                        showDailySummary = true
                    }
                )
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardViewV2()
            .environmentObject(GlassColorSystem())
    }
}

