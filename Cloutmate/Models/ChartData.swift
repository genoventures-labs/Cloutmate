//
//  ChartData.swift
//  Cloutmate
//
//  Structured data for rendering charts in AI reflection responses
//

import Foundation
import SwiftUI

/// Types of charts Aurora can render
enum ChartType: String, Codable {
    case line           // Time-series line chart
    case bar            // Bar chart for comparisons
    case area           // Area chart for cumulative metrics
    case point          // Scatter plot for correlations
    case heatmap        // Grid-based intensity visualization
    case multiLine      // Multiple line series on same chart
}

/// A single data point for chart rendering
struct ChartDataPoint: Codable, Identifiable {
    let id: UUID
    let x: Double          // X-axis value (often timestamp)
    let y: Double          // Y-axis value (metric)
    let label: String?     // Optional label for this point
    let category: String?  // For multi-series charts
    let metadata: [String: String]? // Additional context
    
    init(
        x: Double,
        y: Double,
        label: String? = nil,
        category: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = UUID()
        self.x = x
        self.y = y
        self.label = label
        self.category = category
        self.metadata = metadata
    }
}

/// Complete chart specification for rendering
struct ChartData: Codable {
    let id: UUID
    let type: ChartType
    let title: String
    let subtitle: String?
    let xAxisLabel: String
    let yAxisLabel: String
    let dataPoints: [ChartDataPoint]
    let milestones: [ChartMilestone]?   // Optional milestone markers
    let projectionStart: Int?            // Index where projection begins
    let colorScheme: String?             // "blue", "green", "purple", "gradient"
    
    init(
        type: ChartType,
        title: String,
        subtitle: String? = nil,
        xAxisLabel: String,
        yAxisLabel: String,
        dataPoints: [ChartDataPoint],
        milestones: [ChartMilestone]? = nil,
        projectionStart: Int? = nil,
        colorScheme: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
        self.dataPoints = dataPoints
        self.milestones = milestones
        self.projectionStart = projectionStart
        self.colorScheme = colorScheme
    }
}

/// Milestone marker for charts (e.g., "Breakthrough moment", "Focus session started")
struct ChartMilestone: Codable, Identifiable {
    let id: UUID
    let xValue: Double      // Where on X-axis to place marker
    let label: String       // Milestone description
    let icon: String?       // SF Symbol name
    let color: String?      // "red", "green", "blue", etc.
    
    init(
        xValue: Double,
        label: String,
        icon: String? = nil,
        color: String? = nil
    ) {
        self.id = UUID()
        self.xValue = xValue
        self.label = label
        self.icon = icon
        self.color = color
    }
}

/// Collection of charts for multi-dimensional visualizations
struct ChartCollection: Codable {
    let id: UUID
    let title: String
    let description: String?
    let charts: [ChartData]
    
    init(
        title: String,
        description: String? = nil,
        charts: [ChartData]
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.charts = charts
    }
}

