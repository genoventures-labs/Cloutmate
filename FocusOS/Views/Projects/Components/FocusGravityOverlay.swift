//
//  FocusGravityOverlay.swift
//  FocusOS
//
//  Visual components for Focus Gravity integration in Projects view
//

import SwiftUI

// MARK: - Focus Gravity Bar (Left Edge)

struct FocusGravityBar: View {
    let metrics: ProjectFocusMetrics
    let isActive: Bool
    
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        .kosmicBlue.opacity(metrics.cognitiveFocus),
                        .kosmicPurple.opacity(metrics.creativeFlow),
                        .kosmicGreen.opacity(metrics.completionEnergy)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
            .overlay(
                Group {
                    if isActive {
                        shimmerOverlay
                    }
                }
            )
    }
    
    private var shimmerOverlay: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: shimmerPhase)
            .blendMode(.overlay)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 4
                }
            }
    }
}

// MARK: - Focus Gravity Marker (Circular)

struct FocusGravityMarker: View {
    let metrics: ProjectFocusMetrics
    let size: CGFloat
    
    init(metrics: ProjectFocusMetrics, size: CGFloat = 8) {
        self.metrics = metrics
        self.size = size
    }
    
    private var dominantFocus: (color: Color, intensity: Double) {
        let maxValue = max(metrics.cognitiveFocus, metrics.creativeFlow, metrics.completionEnergy)
        if maxValue == metrics.cognitiveFocus {
            return (.kosmicBlue, metrics.cognitiveFocus)
        } else if maxValue == metrics.creativeFlow {
            return (.kosmicPurple, metrics.creativeFlow)
        } else {
            return (.kosmicGreen, metrics.completionEnergy)
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(dominantFocus.color.opacity(dominantFocus.intensity * 0.6))
                .frame(width: size, height: size)
            
            Circle()
                .stroke(dominantFocus.color.opacity(dominantFocus.intensity * 0.4), lineWidth: 1)
                .frame(width: size + 2, height: size + 2)
        }
    }
}

// MARK: - Focus Gravity Wave (Background)

struct FocusGravityWave: View {
    let metrics: ProjectFocusMetrics
    let width: CGFloat
    let height: CGFloat
    
    @State private var phase: CGFloat = 0
    
    private var waveFrequency: CGFloat {
        // Strong focus = tighter waveform (higher frequency)
        let avgFocus = (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
        return 0.02 + (avgFocus * 0.08) // Range: 0.02 to 0.1
    }
    
    private var waveAmplitude: CGFloat {
        let avgFocus = (metrics.cognitiveFocus + metrics.creativeFlow + metrics.completionEnergy) / 3.0
        return height * 0.3 * CGFloat(avgFocus) // Scale with focus strength
    }
    
    var body: some View {
        Path { path in
            let centerY = height / 2
            let step: CGFloat = 2
            
            path.move(to: CGPoint(x: 0, y: centerY))
            
            for x in stride(from: 0, through: width, by: step) {
                let y = centerY + sin((x * waveFrequency) + phase) * waveAmplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        .stroke(
            LinearGradient(
                colors: [
                    .kosmicBlue.opacity(0.4),
                    .kosmicPurple.opacity(0.4),
                    .kosmicGreen.opacity(0.4)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Focus Intensity Rings (Gallery Hover)

struct FocusIntensityRings: View {
    let metrics: ProjectFocusMetrics
    let isVisible: Bool
    
    private var dominantFocus: Color {
        let maxValue = max(metrics.cognitiveFocus, metrics.creativeFlow, metrics.completionEnergy)
        if maxValue == metrics.cognitiveFocus {
            return .kosmicBlue
        } else if maxValue == metrics.creativeFlow {
            return .kosmicPurple
        } else {
            return .kosmicGreen
        }
    }
    
    private var intensity: Double {
        max(metrics.cognitiveFocus, metrics.creativeFlow, metrics.completionEnergy)
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(
                        dominantFocus.opacity(intensity * (0.3 - Double(index) * 0.07)),
                        lineWidth: 2
                    )
                    .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
            }
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(duration: 0.3), value: isVisible)
    }
}

