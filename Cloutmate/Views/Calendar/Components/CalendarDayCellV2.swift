//
//  CalendarDayCellV2.swift
//  Cloutmate
//
//  Calendar V2 - Enhanced day cell with minimalist design
//

import SwiftUI
import CloutmateShared

struct CalendarDayCellV2: View {
    let date: Date
    let items: [CalendarItem]
    let isSelected: Bool
    let isCurrentMonth: Bool
    var onTap: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
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
    
    private var hasItems: Bool {
        !items.isEmpty
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
                
                // Active indicators
                if hasItems {
                    HStack(spacing: 3) {
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
            onTap: {}
        )
        
        CalendarDayCellV2(
            date: calendar.date(byAdding: .day, value: 1, to: today)!,
            items: [CalendarItem.task(Task(title: "Test"))],
            isSelected: false,
            isCurrentMonth: true,
            onTap: {}
        )
        
        CalendarDayCellV2(
            date: calendar.date(byAdding: .day, value: 2, to: today)!,
            items: [],
            isSelected: false,
            isCurrentMonth: false,
            onTap: {}
        )
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

