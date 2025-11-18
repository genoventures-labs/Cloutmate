//
//  CalendarEventCard.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Enhanced event card with dynamic colors
//

import SwiftUI
import SwiftData
import FocusOSShared

struct CalendarEventCard: View {
    let occurrence: CalendarEventOccurrence
    var onTap: (() -> Void)?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var isHovering = false
    @State private var colorReason: EventColorReason?
    @State private var showTooltip = false
    
    private var event: CalendarEvent {
        occurrence.event
    }
    
    private var eventColor: EventColor {
        if let colorHex = event.colorHex,
           let color = EventColor.from(hex: colorHex) {
            return color
        }
        return .blue // Default fallback
    }
    
    private var timeRangeText: String {
        if event.allDay {
            return "All-day"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: occurrence.startDate)) – \(formatter.string(from: occurrence.endDate))"
    }
    
    private var shouldGlow: Bool {
        guard !reduceMotion else { return false }
        
        let hoursUntil = occurrence.startDate.timeIntervalSince(Date()) / 3600
        
        switch eventColor {
        case .red:
            return hoursUntil < 1 && hoursUntil >= 0
        case .orange:
            return hoursUntil < 3 && hoursUntil >= 0
        case .blue:
            return true // Always glow for deep work
        default:
            return false
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(eventColor.color)
                .frame(width: 4)
                .overlay(
                    Group {
                        if shouldGlow {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(eventColor.color)
                                .opacity(0.6)
                                .blur(radius: 4)
                                .scaleEffect(glowScale)
                                .animation(glowAnimation, value: glowScale)
                        }
                    }
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title.isEmpty ? "Untitled Event" : event.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Label(timeRangeText, systemImage: "clock")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .lineLimit(1)
                    }
                }
                
                if event.recurrence != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 11, weight: .medium))
                        Text("Repeating")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(eventColor.color)
                }
            }
            
            Spacer()
            
            // Color explanation button
            if colorReason != nil {
                Button {
                    showTooltip.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(eventColor.color.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Why this color?")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            eventColor.color.opacity(isHovering ? 0.18 : 0.12),
                            eventColor.color.opacity(isHovering ? 0.1 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(eventColor.color.opacity(isHovering ? 0.35 : 0.2), lineWidth: isHovering ? 1.5 : 1)
        )
        .shadow(
            color: eventColor.color.opacity(shouldGlow ? 0.25 : (isHovering ? 0.15 : 0.08)),
            radius: shouldGlow ? 8 : (isHovering ? 6 : 3),
            y: shouldGlow ? 4 : (isHovering ? 3 : 1)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap?()
        }
        .popover(isPresented: $showTooltip, arrowEdge: .top) {
            if let reason = colorReason {
                EventColorTooltip(reason: reason, eventColor: eventColor)
            }
        }
        .task {
            loadColorReason()
            if shouldGlow {
                startGlowAnimation()
            }
        }
        .onChange(of: shouldGlow) { newValue in
            if newValue {
                startGlowAnimation()
            } else {
                glowScale = 1.0
            }
        }
    }
    
    @State private var glowScale: CGFloat = 1.0
    
    private var glowAnimation: Animation {
        Animation.easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
    }
    
    private func startGlowAnimation() {
        guard shouldGlow else { return }
        withAnimation(glowAnimation) {
            glowScale = 1.2
        }
    }
    
    private func loadColorReason() {
        let eventId = event.id
        let descriptor = FetchDescriptor<EventColorReason>(
            predicate: #Predicate<EventColorReason> { reason in
                reason.eventId == eventId
            }
        )
        colorReason = try? modelContext.fetch(descriptor).first
    }
}

