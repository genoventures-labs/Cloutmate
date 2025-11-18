//
//  FocusOSWidget.swift
//  FocusOSWidget
//

import WidgetKit
import SwiftUI

struct FocusOSWidget: Widget {
    let kind: String = "FocusOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusOSTimelineProvider()) { entry in
            FocusOSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FocusOS Posts")
        .description("View your scheduled posts at a glance")
        .supportedFamilies([.systemSmall])
    }
}
