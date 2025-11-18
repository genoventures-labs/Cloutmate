//
//  TaskFocusMetrics.swift
//  FocusOS
//
//  Task Focus Metrics - Stub implementation for Focus Gravity integration
//

import SwiftUI
import FocusOSShared

struct TaskFocusMetrics {
    let cognitiveFocus: Double // 0.0 - 1.0
    let creativeFlow: Double
    let completionEnergy: Double
    
    static func defaultMetrics(for task: Task) -> TaskFocusMetrics {
        // Stub implementation - replace with real Focus Gravity data later
        // For now, generate placeholder metrics based on task duration and status
        let baseFocus: Double
        let baseFlow: Double
        let baseEnergy: Double
        
        switch task.status {
        case .done:
            baseFocus = 0.8
            baseFlow = 0.6
            baseEnergy = 0.9
        case .inProgress:
            baseFocus = 0.7
            baseFlow = 0.5
            baseEnergy = 0.6
        case .todo:
            baseFocus = 0.4
            baseFlow = 0.3
            baseEnergy = 0.5
        case .cancelled:
            baseFocus = 0.2
            baseFlow = 0.2
            baseEnergy = 0.2
        }
        
        // Add some variance based on task creation date
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        let variance = sin(Double(daysSinceCreation) * 0.1) * 0.1
        
        return TaskFocusMetrics(
            cognitiveFocus: min(1.0, max(0.0, baseFocus + variance)),
            creativeFlow: min(1.0, max(0.0, baseFlow + variance)),
            completionEnergy: min(1.0, max(0.0, baseEnergy + variance))
        )
    }
}

struct TaskFocusMetricsView: View {
    let metrics: TaskFocusMetrics
    let taskTitle: String
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Cognitive Focus (Blue)
            FocusIndicatorBar(
                value: metrics.cognitiveFocus,
                color: .kosmicBlue,
                label: "Cognitive Focus"
            )
            
            // Creative Flow (Purple)
            FocusIndicatorBar(
                value: metrics.creativeFlow,
                color: .kosmicPurple,
                label: "Creative Flow"
            )
            
            // Completion Energy (Green)
            FocusIndicatorBar(
                value: metrics.completionEnergy,
                color: .kosmicGreen,
                label: "Completion Energy"
            )
        }
        .frame(height: 4)
        .padding(.leading, 8)
        .help("You were in flow \(Int(metrics.completionEnergy * 100))% of this task's duration")
    }
}

struct FocusIndicatorBar: View {
    let value: Double
    let color: Color
    let label: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(0.6))
            .frame(width: max(4, CGFloat(value) * 20))
            .help("\(label): \(Int(value * 100))%")
    }
}

#Preview {
    TaskFocusMetricsView(
        metrics: TaskFocusMetrics(
            cognitiveFocus: 0.82,
            creativeFlow: 0.65,
            completionEnergy: 0.78
        ),
        taskTitle: "Sample Task"
    )
    .padding()
}

