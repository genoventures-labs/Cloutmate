//
//  CalendarDayCellV2.swift
//  FocusOS
//
//  Calendar V2 - Enhanced day cell with minimalist design
//

import SwiftUI
import SwiftData
import FocusOSShared

struct CalendarDayCellV2: View {
    let date: Date
    let items: [CalendarItem]
    let isSelected: Bool
    let isCurrentMonth: Bool
    var onTap: () -> Void = {}
    var onPostTap: ((FocusOSShared.Post) -> Void)? = nil
    var onArtifactTap: ((FocusOSShared.Artifact) -> Void)? = nil
    var onTaskTap: ((FocusOSShared.Task) -> Void)? = nil
    var onEventTap: ((CalendarEventOccurrence) -> Void)? = nil
    var onCompose: (() -> Void)? = nil
    
    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private let calendar = Calendar.current
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }
    
    private var artifactCount: Int {
        items.filter { if case .artifact = $0 { return true }; return false }.count
    }
    
    private var taskCount: Int {
        items.filter { if case .task = $0 { return true }; return false }.count
    }
    
    private var postCount: Int {
        items.filter { if case .post = $0 { return true }; return false }.count
    }
    
    private var eventCount: Int {
        items.filter { if case .event = $0 { return true }; return false }.count
    }
    
    private var hasItems: Bool {
        !items.isEmpty
    }
    
    private var dominantColor: EventColor? {
        let eventItems = items.compactMap { item -> CalendarEventOccurrence? in
            if case .event(let occurrence) = item { return occurrence }
            return nil
        }
        
        // Find most urgent event color
        var maxUrgency: Double = -1
        var dominant: EventColor?
        
        for occurrence in eventItems {
            if let colorHex = occurrence.event.colorHex,
               let color = EventColor.from(hex: colorHex) {
                // Get urgency score from reason
                let eventId = occurrence.event.id
                let descriptor = FetchDescriptor<EventColorReason>(
                    predicate: #Predicate<EventColorReason> { reason in
                        reason.eventId == eventId
                    }
                )
                if let reason = try? modelContext.fetch(descriptor).first,
                   reason.urgencyScore > maxUrgency {
                    maxUrgency = reason.urgencyScore
                    dominant = color
                } else if dominant == nil {
                    // Fallback: use color priority
                    dominant = color
                }
            }
        }
        
        return dominant
    }
    
    private var urgencyCount: Int {
        let eventItems = items.compactMap { item -> CalendarEventOccurrence? in
            if case .event(let occurrence) = item { return occurrence }
            return nil
        }
        
        return eventItems.filter { occurrence in
            if let colorHex = occurrence.event.colorHex,
               let color = EventColor.from(hex: colorHex) {
                return color == .red || color == .orange
            }
            return false
        }.count
    }
    
    var body: some View {
        Button(action: {
            withAnimation(GlassMotion.Easing.spring) {
                onTap()
            }
        }) {
            VStack(spacing: 6) {
                Text("\(dayNumber)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(
                        isToday ? .kosmicBlue : (isCurrentMonth ? .primary : .secondary.opacity(0.4))
                    )
                
                if hasItems {
                    HStack(spacing: 3) {
                        // Show dominant color indicator if available
                        if let dominant = dominantColor {
                            Circle()
                                .fill(dominant.color)
                                .frame(width: 5, height: 5)
                                .shadow(color: dominant.color.opacity(0.6), radius: 2)
                        } else {
                            // Fallback to type indicators
                            if artifactCount > 0 {
                                Circle()
                                    .fill(Color.kosmicPurple)
                                    .frame(width: 4, height: 4)
                            }
                            if taskCount > 0 {
                                Circle()
                                    .fill(Color.kosmicGreen)
                                    .frame(width: 4, height: 4)
                            }
                            if postCount > 0 {
                                Circle()
                                    .fill(Color.kosmicBlue)
                                    .frame(width: 4, height: 4)
                            }
                            if eventCount > 0 {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        
                        // Urgency count badge
                        if urgencyCount > 0 {
                            Text("\(urgencyCount)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(Color.red)
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                Group {
                    if isHovered && !isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(glassColorSystem.cardColor())
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.kosmicBlue.opacity(0.15))
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                Group {
                    if isToday {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.kosmicBlue.opacity(0.8), Color.kosmicPurple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.kosmicBlue.opacity(0.4), lineWidth: 1.5)
                    }
                }
            )
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
            .shadow(
                color: isHovered ? Color.black.opacity(0.1) : .clear,
                radius: isHovered ? 4 : 0,
                y: isHovered ? 2 : 0
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onCompose?()
            }
        )
        .onHover { hovering in
            withAnimation(GlassMotion.Easing.spring) {
                isHovered = hovering
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.linear(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityLabel("\(dayNumber), \(isToday ? "today" : "")")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
        .contextMenu {
            if let firstPost = items.compactMap({ item -> FocusOSShared.Post? in
                if case .post(let post) = item { return post }
                return nil
            }).first {
                Button("Open Post") {
                    onPostTap?(firstPost)
                }
            }
            if let firstTask = items.compactMap({ item -> FocusOSShared.Task? in
                if case .task(let task) = item { return task }
                return nil
            }).first {
                Button("Open Task") {
                    onTaskTap?(firstTask)
                }
            }
            if let firstArtifact = items.compactMap({ item -> FocusOSShared.Artifact? in
                if case .artifact(let artifact) = item { return artifact }
                return nil
            }).first {
                Button("Open Artifact") {
                    onArtifactTap?(firstArtifact)
                }
            }
            if let firstEvent = items.compactMap({ item -> CalendarEventOccurrence? in
                if case .event(let occurrence) = item { return occurrence }
                return nil
            }).first {
                Button("Open Event") {
                    onEventTap?(firstEvent)
                }
            }
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
        CalendarDayCellV2(
            date: today,
            items: [],
            isSelected: true,
            isCurrentMonth: true,
            onTap: {},
            onCompose: {}
        )
        
        CalendarDayCellV2(
            date: calendar.date(byAdding: .day, value: 1, to: today)!,
            items: [CalendarItem.task(FocusOSShared.Task(title: "Test"))],
            isSelected: false,
            isCurrentMonth: true,
            onTap: {},
            onCompose: {}
        )
        
        CalendarDayCellV2(
            date: calendar.date(byAdding: .day, value: 2, to: today)!,
            items: [],
            isSelected: false,
            isCurrentMonth: false,
            onTap: {},
            onCompose: {}
        )
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

