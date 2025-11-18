//
//  TimelineVisuals.swift
//  FocusOS
//
//  Shared timeline decor for V2 glassmorphic tracks.
//

import SwiftUI

struct TimelineTrackBackground: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    let width: CGFloat
    let height: CGFloat
    var accentGradient: LinearGradient?
    
    var body: some View {
        RoundedRectangle(cornerRadius: TimelineLayout.trackCornerRadius, style: .continuous)
            .fill(glassColorSystem.cardColor().opacity(0.82))
            .overlay(accentOverlay)
            .overlay(
                RoundedRectangle(cornerRadius: TimelineLayout.trackCornerRadius, style: .continuous)
                    .stroke(glassColorSystem.borderColor().opacity(0.85), lineWidth: 0.9)
            )
            .background(
                RoundedRectangle(cornerRadius: TimelineLayout.trackCornerRadius + 6, style: .continuous)
                    .stroke(glassColorSystem.borderColor().opacity(0.25), lineWidth: 0.6)
                    .blur(radius: 12)
            )
            .overlay(gridOverlay)
            .shadow(color: glassColorSystem.backgroundSecondary().opacity(0.22), radius: 24, y: 18)
            .frame(width: backgroundWidth, height: backgroundHeight)
            .offset(
                x: TimelineLayout.horizontalPadding * 0.6,
                y: TimelineLayout.baselineY - (TimelineLayout.connectionHeight / 2) - TimelineLayout.backgroundYOffset
            )
            .allowsHitTesting(false)
    }
    
    private var backgroundWidth: CGFloat {
        width - (TimelineLayout.horizontalPadding * TimelineLayout.backgroundWidthInsetFactor)
    }
    
    private var backgroundHeight: CGFloat {
        height - 52
    }
    
    private var accentOverlay: some View {
        (accentGradient ?? AuroraPalette.linearGradient(for: colorScheme))
            .opacity(0.18)
            .blendMode(.plusLighter)
    }
    
    private var gridOverlay: some View {
        Canvas { context, size in
            let stripeSpacing = TimelineLayout.gridStripeSpacing
            let verticalCount = Int(size.width / stripeSpacing)
            for index in 0...verticalCount {
                let x = CGFloat(index) * stripeSpacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(
                    path,
                    with: .color(glassColorSystem.borderColor().opacity(0.25)),
                    style: StrokeStyle(lineWidth: 0.6)
                )
            }
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: 0, y: size.height * 0.35))
            horizontal.addLine(to: CGPoint(x: size.width, y: size.height * 0.35))
            context.stroke(
                horizontal,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.45),
                        Color.white.opacity(0.12)
                    ]),
                    startPoint: CGPoint(x: 0, y: size.height * 0.35),
                    endPoint: CGPoint(x: size.width, y: size.height * 0.35)
                ),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
            )
            if !reduceMotion {
                let glowRect = CGRect(origin: .zero, size: size)
                context.fill(
                    Path(roundedRect: glowRect, cornerRadius: TimelineLayout.trackCornerRadius),
                    with: .radialGradient(
                        Gradient(colors: [
                            glassColorSystem.emotionalAccent().opacity(0.16),
                            .clear
                        ]),
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.3),
                        startRadius: 20,
                        endRadius: size.width * 0.65
                    )
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TimelineLayout.trackCornerRadius, style: .continuous))
    }
}

struct TimelineAxis: View {
    let width: CGFloat
    let tickCount: Int
    let tickHeight: CGFloat
    var gradient: LinearGradient = LinearGradient(
        colors: [.kosmicBlue.opacity(0.9), .kosmicPurple.opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: TimelineLayout.horizontalPadding, y: TimelineLayout.baselineY))
                path.addLine(to: CGPoint(x: width - TimelineLayout.horizontalPadding, y: TimelineLayout.baselineY))
            }
            .stroke(
                gradient,
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            
            let usableWidth = width - (TimelineLayout.horizontalPadding * 2)
            ForEach(0...tickCount, id: \.self) { index in
                let ratio = CGFloat(index) / CGFloat(max(tickCount, 1))
                Path { path in
                    let x = TimelineLayout.horizontalPadding + ratio * usableWidth
                    path.move(to: CGPoint(x: x, y: TimelineLayout.baselineY - tickHeight / 2))
                    path.addLine(to: CGPoint(x: x, y: TimelineLayout.baselineY + tickHeight / 2))
                }
                .stroke(Color.white.opacity(0.24), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
    }
}

struct TimelineDateRangeLabel: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let startDate: Date
    let endDate: Date
    let alignment: Alignment
    var icon: String = "calendar"
    
    private var formatter: DateIntervalFormatter {
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = "MMM d"
        return formatter
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(glassColorSystem.emotionalAccent())
            VStack(alignment: .leading, spacing: 2) {
                Text("Timeline Range")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatter.string(from: startDate, to: endDate))
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.semibold)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(glassColorSystem.cardElevated().opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(glassColorSystem.borderColor().opacity(0.75), lineWidth: 0.8)
                )
        )
        .shadow(color: glassColorSystem.backgroundSecondary().opacity(0.18), radius: 18, y: 10)
        .frame(maxWidth: .infinity, alignment: alignment)
    }
}

struct TimelineDensityRibbon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    struct Point: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
    }
    
    let points: [Point]
    let baselineY: CGFloat
    let fillGradient: Gradient
    let strokeGradient: Gradient
    
    var body: some View {
        Canvas { context, _ in
            guard points.count >= 2 else { return }
            
            var fill = Path()
            fill.move(to: CGPoint(x: points.first!.x, y: baselineY))
            points.forEach { fill.addLine(to: CGPoint(x: $0.x, y: $0.y)) }
            fill.addLine(to: CGPoint(x: points.last!.x, y: baselineY))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(fillGradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: baselineY)))
            
            var line = Path()
            line.move(to: CGPoint(x: points.first!.x, y: points.first!.y))
            points.dropFirst().forEach { line.addLine(to: CGPoint(x: $0.x, y: $0.y)) }
            context.stroke(
                line,
                with: .linearGradient(strokeGradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: baselineY)),
                style: StrokeStyle(lineWidth: reduceMotion ? 1.5 : 2.4, lineCap: .round, lineJoin: .round)
            )
        }
        .opacity(0.92)
    }
}


