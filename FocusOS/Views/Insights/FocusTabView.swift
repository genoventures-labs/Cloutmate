//
//  FocusTabView.swift
//  FocusOS
//

import SwiftUI
import SwiftData

struct FocusTabView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    var body: some View {
        ProductivityMetricsView(snapshot: snapshot, timeRange: timeRange)
    }
}


