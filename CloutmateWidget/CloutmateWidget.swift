//
//  CloutmateWidget.swift
//  CloutmateWidget
//

import WidgetKit
import SwiftUI

struct CloutmateWidget: Widget {
    let kind: String = "CloutmateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CloutmateTimelineProvider()) { entry in
            CloutmateWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cloutmate Posts")
        .description("View your scheduled posts at a glance")
        .supportedFamilies([.systemSmall])
    }
}
