//
//  StoryTokenCard.swift
//  Cloutmate
//
//  Individual Story Token card component
//

import SwiftUI
import SwiftData

struct StoryTokenCard: View {
    let token: StoryToken
    let onTap: (() -> Void)?
    let onExport: (() -> Void)?
    
    @Environment(\.modelContext) private var modelContext
    
    init(
        token: StoryToken,
        onTap: (() -> Void)? = nil,
        onExport: (() -> Void)? = nil
    ) {
        self.token = token
        self.onTap = onTap
        self.onExport = onExport
    }
    
    var body: some View {
        GlassCard(showHeader: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(token.title)
                            .font(.system(size: 18, weight: .semibold))
                            .lineLimit(2)
                        
                        Text(dateRangeText)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Story type badge
                    Text(token.storyType.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(6)
                }
                
                // Summary
                Text(token.summary)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
                
                // Themes
                if !token.themes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(token.themes.prefix(5), id: \.self) { theme in
                                Text(theme)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                // Metrics row
                if !token.metrics.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(Array(token.metrics.keys).prefix(3), id: \.self) { key in
                            if let value = token.metrics[key] {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatMetricValue(value, key: key))
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: {
                        onTap?()
                    }) {
                        Label("View", systemImage: "eye")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    
                    if onExport != nil {
                        Button(action: {
                            onExport?()
                        }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .onTapGesture {
            onTap?()
        }
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: token.startDate)) - \(formatter.string(from: token.endDate))"
    }
    
    private func formatMetricValue(_ value: Double, key: String) -> String {
        switch key {
        case "focusHours":
            return String(format: "%.1f", value)
        case "focusCompletionRate":
            return String(format: "%.0f%%", value * 100)
        case "aliveConcepts":
            return String(format: "%.0f", value)
        default:
            return String(format: "%.1f", value)
        }
    }
}

