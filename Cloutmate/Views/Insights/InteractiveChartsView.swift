//
//  InteractiveChartsView.swift
//  Cloutmate
//
//  Interactive Charts with Drill-down Capabilities
//

import SwiftUI
import Charts
import CloutmateShared

struct InteractiveChartsView: View {
    let posts: [CloutmateShared.Post]
    @State private var selectedChartType: ChartType = .engagement
    @State private var selectedPost: CloutmateShared.Post?
    
    enum ChartType: String, CaseIterable {
        case engagement = "Engagement Trends"
        case platforms = "Platform Compare"
        case content = "Content Type"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart type selector
            HStack(spacing: 8) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    GlassButton(
                        type.rawValue,
                        style: .pill,
                        tier: selectedChartType == type ? .overlay : .contentCard,
                        tintColor: .blue,
                        action: {
                            withAnimation(GlassMotion.Easing.spring) {
                                selectedChartType = type
                            }
                        }
                    )
                }
            }
            
            // Chart display
            GlassPanel(tier: .contentCard, cornerRadius: 16) {
                Group {
                    switch selectedChartType {
                    case .engagement:
                        EngagementTrendsChart(posts: posts, selectedPost: $selectedPost)
                            .frame(height: 320)
                            .padding()
                    case .platforms:
                        PlatformComparisonChart(posts: posts, selectedPost: $selectedPost)
                            .frame(height: 320)
                            .padding()
                    case .content:
                        ContentPerformanceChart(posts: posts, selectedPost: $selectedPost)
                            .frame(height: 320)
                            .padding()
                    }
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedPost },
            set: { selectedPost = $0 }
        )) { post in
            PostDetailPopup(post: post)
        }
    }
}

#Preview {
    InteractiveChartsView(posts: [])
        .padding()
}
