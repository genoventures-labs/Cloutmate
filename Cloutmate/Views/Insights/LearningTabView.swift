//
//  LearningTabView.swift
//  Cloutmate
//

import SwiftUI
import SwiftData

struct LearningTabView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    var body: some View {
        LearningLoopView(snapshot: snapshot, timeRange: timeRange)
    }
}


