//
//  EmotionalTabView.swift
//  Cloutmate
//

import SwiftUI
import SwiftData

struct EmotionalTabView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    var body: some View {
        EmotionalHeatmapView(snapshot: snapshot, timeRange: timeRange)
    }
}


