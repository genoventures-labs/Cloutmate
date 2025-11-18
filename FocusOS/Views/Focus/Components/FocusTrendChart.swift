//
//  FocusTrendChart.swift
//  FocusOS
//
//  Focus Gravity V2 - Weekly focus distribution bar chart
//

import SwiftUI
import SwiftData
import Charts

struct FocusTrendChart: View {
    @Environment(\.modelContext) private var modelContext
    let reduceMotion: Bool
    
    @State private var trendData: [(date: Date, cognitive: Double, creative: Double, completion: Double)] = []
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weekly Focus Distribution")
                    .font(.headline)
                    .foregroundColor(glassColorSystem.textPrimary())
                
                if trendData.isEmpty {
                    Text("No trend data available")
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textSecondary())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    Chart {
                        ForEach(Array(trendData.enumerated()), id: \.offset) { index, data in
                            BarMark(
                                x: .value("Day", dayLabel(for: data.date)),
                                y: .value("Cognitive", data.cognitive * 100)
                            )
                            .foregroundStyle(Color.kosmicBlue)
                            .cornerRadius(4)
                            
                            BarMark(
                                x: .value("Day", dayLabel(for: data.date)),
                                y: .value("Creative", data.creative * 100)
                            )
                            .foregroundStyle(Color.kosmicPurple)
                            .cornerRadius(4)
                            
                            BarMark(
                                x: .value("Day", dayLabel(for: data.date)),
                                y: .value("Completion", data.completion * 100)
                            )
                            .foregroundStyle(Color.kosmicGreen)
                            .cornerRadius(4)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Double.self) {
                                    Text("\(Int(intValue))%")
                                        .font(.caption2)
                                        .foregroundColor(glassColorSystem.textSecondary())
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let stringValue = value.as(String.self) {
                                    Text(stringValue)
                                        .font(.caption2)
                                        .foregroundColor(glassColorSystem.textSecondary())
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
                
                // Legend
                HStack(spacing: 20) {
                    legendItem(color: .kosmicBlue, label: "Cognitive")
                    legendItem(color: .kosmicPurple, label: "Creative")
                    legendItem(color: .kosmicGreen, label: "Completion")
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .task {
            loadTrendData()
        }
    }
    
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(glassColorSystem.textSecondary())
        }
    }
    
    @MainActor
    private func loadTrendData() {
        trendData = FocusGravityService.shared.getWeeklyTrend(modelContext: modelContext)
    }
}

