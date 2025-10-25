//
//  MonthlyCalendarView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MonthlyCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    let posts: [Post]
    @Binding var selectedDate: Date
    
    @State private var displayedMonth = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            
            // Days of week
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        posts: postsForDate(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                    .onDrop(of: [.text], delegate: PostDropDelegate(
                        targetDate: date,
                        posts: posts,
                        modelContext: modelContext
                    ))
                }
            }
            .padding()
        }
    }
    
    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstDay = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start else {
            return []
        }
        
        return (0..<42).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: firstDay)
        }
    }
    
    private func postsForDate(_ date: Date) -> [Post] {
        posts.filter { post in
            guard let scheduledDate = post.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let posts: [Post]
    let isSelected: Bool
    let isCurrentMonth: Bool
    
    private let calendar = Calendar.current
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    private var isWeekend: Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayNumber)
                .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isCurrentMonth ? (isToday ? .white : .primary) : .secondary)
            
            if !posts.isEmpty {
                HStack(spacing: 3) {
                    ForEach(posts.prefix(2), id: \.id) { post in
                        Image(systemName: post.postPlatforms.contains(.threads) ? "t.square.fill" : "f.square.fill")
                            .font(.system(size: 10))
                            .foregroundColor(post.postPlatforms.contains(.threads) ? .purple : .blue)
                    }
                    if posts.count > 2 {
                        Text("+\(posts.count - 2)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            Group {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.2))
                } else if isWeekend {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.05))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected && !isToday ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func colorForPost(_ post: Post) -> Color {
        if post.postPlatforms.contains(.threads) {
            return .purple
        } else if post.postPlatforms.contains(.facebook) {
            return .blue
        }
        return .gray
    }
}

#Preview {
    MonthlyCalendarView(posts: [], selectedDate: .constant(Date()))
}

