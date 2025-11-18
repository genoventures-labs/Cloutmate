//
//  FocusGravityOrbit.swift
//  FocusOS
//
//  Focus Gravity V2 - Orbit visualization with spring physics and ARTE integration
//

import SwiftUI
import Combine

struct FocusGravityOrbit: View {
    let entities: [FocusEntity]
    @Binding var selectedEntityId: UUID?
    let forecast: FocusForecast?
    let reduceMotion: Bool
    
    @State private var orbitRotation: Double = 0
    @State private var gravityWellPulse: Double = 1.0
    @State private var hoveredEntityId: UUID?
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var reactiveTheme = ReactiveThemeManager.shared
    
    private let orbitRadius: CGFloat = 150
    private let centerX: CGFloat = 200
    private let centerY: CGFloat = 200
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
            
            ZStack {
                // ARTE gradient overlay
                if glassColorSystem.isARTEEnabled {
                    glassColorSystem.emotionalBackgroundShift()
                        .opacity(0.15)
                        .blur(radius: 40)
                }
                
                // Predictive wave distortion (if forecast available)
                if let forecast = forecast, forecast.fatigueRisk > 0.5 {
                    ForecastWaveOverlay(
                        fatigueRisk: forecast.fatigueRisk,
                        focusStability: forecast.focusStability
                    )
                    .opacity(0.3)
                }
                
                // Central gravity well
                GravityWell(
                    pulseScale: gravityWellPulse,
                    color: stateColor,
                    reduceMotion: reduceMotion
                )
                .position(center)
                
                // Orbiting nodes
                ForEach(Array(entities.prefix(12).enumerated()), id: \.element.id) { index, entity in
                    OrbitNode(
                        entity: entity,
                        index: index,
                        total: min(12, entities.count),
                        center: center,
                        radius: orbitRadius,
                        rotation: orbitRotation,
                        isSelected: selectedEntityId == entity.id,
                        isHovered: hoveredEntityId == entity.id,
                        reduceMotion: reduceMotion,
                        forecast: forecast
                    )
                    .onTapGesture {
                        selectedEntityId = entity.id
                    }
                    .onHover { hovering in
                        hoveredEntityId = hovering ? entity.id : nil
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(entity.name), position \(index + 1) of \(min(12, entities.count))")
                    .accessibilityValue("\(Int(entity.focusAllocation))% focus allocation, \(entity.energy.dominantType) energy")
                    .accessibilityHint("Double tap to select")
                    .accessibilityAddTraits(selectedEntityId == entity.id ? .isSelected : [])
                }
            }
        }
        .onAppear {
            if !reduceMotion {
                startAnimations()
            }
        }
        .onDisappear {
            stopAnimations()
        }
    }
    
    private var stateColor: Color {
        switch reactiveTheme.currentState {
        case .calm: return .kosmicBlue
        case .focused: return .kosmicPurple
        case .fatigued: return .orange
        case .energized: return .kosmicGreen
        case .reflective: return .cyan
        }
    }
    
    private func startAnimations() {
        // Orbit rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            orbitRotation = 360
        }
        
        // Gravity well pulse
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            gravityWellPulse = 1.15
        }
    }
    
    private func stopAnimations() {
        orbitRotation = 0
        gravityWellPulse = 1.0
    }
}

// MARK: - Gravity Well

private struct GravityWell: View {
    let pulseScale: Double
    let color: Color
    let reduceMotion: Bool
    
    var body: some View {
        ZStack {
            // Outer rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.2 - Double(index) * 0.05), lineWidth: 2)
                    .frame(width: 40 + CGFloat(index * 15), height: 40 + CGFloat(index * 15))
                    .scaleEffect(reduceMotion ? 1.0 : pulseScale + Double(index) * 0.1)
            }
            
            // Core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.8), color.opacity(0.4)],
                        center: .center,
                        startRadius: 5,
                        endRadius: 20
                    )
                )
                .frame(width: 40, height: 40)
                .scaleEffect(reduceMotion ? 1.0 : pulseScale)
        }
    }
}

// MARK: - Orbit Node

private struct OrbitNode: View {
    let entity: FocusEntity
    let index: Int
    let total: Int
    let center: CGPoint
    let radius: CGFloat
    let rotation: Double
    let isSelected: Bool
    let isHovered: Bool
    let reduceMotion: Bool
    let forecast: FocusForecast?
    
    @State private var nodeRotation: Double = 0
    
    private var nodeColor: Color {
        switch entity.energy.dominantType {
        case .cognitive: return .kosmicBlue
        case .creative: return .kosmicPurple
        case .completion: return .kosmicGreen
        }
    }
    
    private var nodeSize: CGFloat {
        let baseSize: CGFloat = 20
        let scaledSize = baseSize + (CGFloat(entity.gravityWeight) * 40)
        return min(60, max(20, scaledSize))
    }
    
    private var angle: Double {
        guard total > 0 else { return 0 }
        let baseAngle = (2.0 * .pi * Double(index) / Double(total))
        return baseAngle + (reduceMotion ? 0 : rotation * .pi / 180)
    }
    
    private var position: CGPoint {
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        ZStack {
            // Node
            Circle()
                .fill(nodeColor.opacity(0.7))
                .frame(width: nodeSize, height: nodeSize)
                .overlay(
                    Circle()
                        .stroke(nodeColor, lineWidth: isSelected ? 3 : 2)
                )
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .shadow(color: nodeColor.opacity(0.5), radius: isHovered ? 8 : 4)
            
            // Pulse animation (if forecast approaching focus peak)
            if let forecast = forecast,
               let windowStart = forecast.nextFocusWindowStart,
               windowStart.timeIntervalSinceNow < 3600 { // Within 1 hour
                Circle()
                    .stroke(nodeColor.opacity(0.4), lineWidth: 2)
                    .frame(width: nodeSize + 10, height: nodeSize + 10)
                    .scaleEffect(reduceMotion ? 1.0 : 1.0 + sin(nodeRotation) * 0.2)
            }
        }
        .position(position)
        .animation(
            reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8),
            value: position
        )
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    nodeRotation = 360
                }
            }
        }
        .overlay(
            // Tooltip on hover
            Group {
                if isHovered {
                    NodeTooltip(entity: entity)
                        .offset(x: 0, y: -nodeSize - 30)
                }
            }
        )
    }
}

// MARK: - Node Tooltip

private struct NodeTooltip: View {
    let entity: FocusEntity
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entity.name)
                .font(.caption.weight(.semibold))
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text("\(Int(entity.focusAllocation))% focus")
                .font(.caption2)
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(glassColorSystem.cardColor())
                .shadow(radius: 4)
        )
    }
}

// MARK: - Forecast Wave Overlay

private struct ForecastWaveOverlay: View {
    let fatigueRisk: Double
    let focusStability: Double
    
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2
                let amplitude = height * 0.1 * CGFloat(fatigueRisk)
                let frequency = 0.02 + (0.08 * CGFloat(focusStability))
                
                path.move(to: CGPoint(x: 0, y: centerY))
                
                for x in stride(from: 0, through: width, by: 2) {
                    let y = centerY + sin((x * frequency) + phase) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [
                        .red.opacity(0.4),
                        .orange.opacity(0.3),
                        .yellow.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

