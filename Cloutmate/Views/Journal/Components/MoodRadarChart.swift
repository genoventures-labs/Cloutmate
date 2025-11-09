//
//  MoodRadarChart.swift
//  Cloutmate
//
//  Mini radar chart for mood analysis in Journal Detail Drawer
//

import SwiftUI
import SwiftData
import CloutmateShared

struct MoodRadarChart: View {
    let calm: Double      // 0.0 - 1.0
    let creative: Double
    let chaotic: Double
    let restless: Double
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let chartSize: CGFloat = 120
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ZStack {
                    // Background grid
                    RadarGrid()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    
                    // Data shape
                    RadarShape(
                        calm: calm,
                        creative: creative,
                        chaotic: chaotic,
                        restless: restless
                    )
                    .fill(
                        LinearGradient(
                            colors: [.kosmicBlue.opacity(0.4), .kosmicPurple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .stroke(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    
                    // Data points
                    ForEach(radarPoints, id: \.label) { point in
                        Circle()
                            .fill(point.color)
                            .frame(width: 6, height: 6)
                            .position(point.position)
                    }
                }
                .frame(width: chartSize, height: chartSize)
                
                // Legend
                VStack(alignment: .leading, spacing: 4) {
                    LegendRow(label: "Calm", value: calm, color: .kosmicBlue)
                    LegendRow(label: "Creative", value: creative, color: .kosmicPurple)
                    LegendRow(label: "Chaotic", value: chaotic, color: .orange)
                    LegendRow(label: "Restless", value: restless, color: .red)
                }
            }
            .padding(16)
        }
    }
    
    private var radarPoints: [RadarPoint] {
        let center = CGPoint(x: chartSize / 2, y: chartSize / 2)
        let radius = chartSize / 2 - 10
        
        return [
            RadarPoint(
                label: "Calm",
                position: CGPoint(
                    x: center.x,
                    y: center.y - radius * CGFloat(calm)
                ),
                color: .kosmicBlue
            ),
            RadarPoint(
                label: "Creative",
                position: CGPoint(
                    x: center.x + radius * CGFloat(creative) * cos(CGFloat.pi / 4),
                    y: center.y - radius * CGFloat(creative) * sin(CGFloat.pi / 4)
                ),
                color: .kosmicPurple
            ),
            RadarPoint(
                label: "Chaotic",
                position: CGPoint(
                    x: center.x + radius * CGFloat(chaotic),
                    y: center.y
                ),
                color: .orange
            ),
            RadarPoint(
                label: "Restless",
                position: CGPoint(
                    x: center.x - radius * CGFloat(restless) * cos(CGFloat.pi / 4),
                    y: center.y - radius * CGFloat(restless) * sin(CGFloat.pi / 4)
                ),
                color: .red
            )
        ]
    }
}

struct RadarGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 10
        
        // Draw concentric circles
        for i in 1...3 {
            let r = radius * CGFloat(i) / 3
            path.addEllipse(in: CGRect(
                x: center.x - r,
                y: center.y - r,
                width: r * 2,
                height: r * 2
            ))
        }
        
        // Draw axes
        for angle in stride(from: 0, to: 2 * CGFloat.pi, by: CGFloat.pi / 4) {
            let x = center.x + radius * cos(angle)
            let y = center.y - radius * sin(angle)
            path.move(to: center)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

struct RadarShape: Shape {
    let calm: Double
    let creative: Double
    let chaotic: Double
    let restless: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 10
        
        // Top (Calm)
        let top = CGPoint(
            x: center.x,
            y: center.y - radius * CGFloat(calm)
        )
        path.move(to: top)
        
        // Top-right (Creative)
        let topRight = CGPoint(
            x: center.x + radius * CGFloat(creative) * cos(CGFloat.pi / 4),
            y: center.y - radius * CGFloat(creative) * sin(CGFloat.pi / 4)
        )
        path.addLine(to: topRight)
        
        // Right (Chaotic)
        let right = CGPoint(
            x: center.x + radius * CGFloat(chaotic),
            y: center.y
        )
        path.addLine(to: right)
        
        // Bottom-left (Restless)
        let bottomLeft = CGPoint(
            x: center.x - radius * CGFloat(restless) * cos(CGFloat.pi / 4),
            y: center.y - radius * CGFloat(restless) * sin(CGFloat.pi / 4)
        )
        path.addLine(to: bottomLeft)
        
        path.closeSubpath()
        return path
    }
}

struct RadarPoint {
    let label: String
    let position: CGPoint
    let color: Color
}

struct LegendRow: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(Int(value * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    MoodRadarChart(
        calm: 0.8,
        creative: 0.6,
        chaotic: 0.2,
        restless: 0.3
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

