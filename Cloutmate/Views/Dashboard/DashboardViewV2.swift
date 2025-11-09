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
    @State private var headerOpacity: Double = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var showDailySummary = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(spacing: 24) {
                            // Header (semi-persistent)
                            DashboardHeaderView(
                                onRefresh: {
                                    // Trigger refresh
                                },
                                onSearch: {
                                    // Open command palette (global search)
                                    NotificationCenter.default.post(name: NSNotification.Name("OpenCommandPalette"), object: nil)
                                },
                                onToggleInsights: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showAuroraInsights.toggle()
                                    }
                                }
                            )
                            .padding(.horizontal, 28)
                            .padding(.top, 20)
                            .opacity(headerOpacity)
                            .id("header")
                            
                            // Daily Overview Panel
                            DailyOverviewPanel()
                                .padding(.horizontal, 28)
                            
                            // Active Workfeed
                            ActiveWorkfeedView()
                                .padding(.horizontal, 28)
                            
                            // Rituals & Streaks
                            RitualsSummaryView()
                                .padding(.horizontal, 28)
                            
                            // Reflection Feed
                            ReflectionFeedView()
                                .padding(.horizontal, 28)
                            
                            // Footer
                            DashboardFooterView(
                                onEndOfDaySummary: {
                                    showDailySummary = true
                                }
                            )
                                .padding(.horizontal, 28)
                                .padding(.bottom, 40)
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: scrollGeometry.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            let offset = -value
                            scrollOffset = offset
                            
                            // Fade header as user scrolls
                            withAnimation(.easeOut(duration: 0.2)) {
                                if offset > 50 {
                                    headerOpacity = max(0.3, 1.0 - (offset - 50.0) / 200.0)
                                } else {
                                    headerOpacity = 1.0
                                }
                            }
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .background(Color(.windowBackgroundColor))
                
                // Aurora Insights Drawer Overlay
                if showAuroraInsights {
                    AuroraInsightsDrawer(isPresented: $showAuroraInsights)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(100)
                }
            }
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showDailySummary) {
            DailySummaryView()
        }
    }
}

#Preview {
    NavigationStack {
        DashboardViewV2()
            .environmentObject(GlassColorSystem())
    }
}

