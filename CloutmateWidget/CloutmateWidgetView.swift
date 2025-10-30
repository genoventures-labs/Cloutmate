//
//  CloutmateWidgetView.swift
//  CloutmateWidget
//

import SwiftUI
import WidgetKit
import CloutmateShared

struct CloutmateWidgetEntryView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("Cloutmate")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Scheduled count
                HStack(spacing: 6) {
                    Text("\(entry.scheduledCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text(entry.scheduledCount == 1 ? "post" : "posts")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Next post
                if let nextDate = entry.nextPostDate {
                    VStack(spacing: 4) {
                        Text("Next:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(nextDate, style: .time)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        if let caption = entry.nextPostCaption {
                            Text(caption)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No posts scheduled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
    }
}

