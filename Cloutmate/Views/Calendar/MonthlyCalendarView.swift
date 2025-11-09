//
//  MonthlyCalendarView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CloutmateShared

struct MonthlyCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    let posts: [CloutmateShared.Post]
    @Binding var selectedDate: Date
    @Binding var showingComposer: Bool
    @Binding var prefilledDate: Date?
    @Binding var showingPostPreview: Bool
    @Binding var selectedPost: CloutmateShared.Post?
    
    @State private var displayedMonth = Date()
    @State private var showPostListSheet = false
    @State private var postsForSelectedDate: [CloutmateShared.Post] = []
    @State private var selectedDateForList = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header with Glass Buttons
            HStack {
                GlassButton(icon: "chevron.left", style: .iconOnly, tintColor: .kosmicBlue, action: previousMonth)
                    .frame(width: 32, height: 32)
                
                Spacer()
                
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                GlassButton(icon: "chevron.right", style: .iconOnly, tintColor: .kosmicBlue, action: nextMonth)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            
            // Days of week
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            .background(
                LinearGradient(
                    colors: [Color.secondary.opacity(0.06), Color.secondary.opacity(0.02)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Calendar grid with Floating Glass Capsules
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                ForEach(calendarDays, id: \.self) { date in
                    GlassCalendarDayCell(
                        date: date,
                        posts: postsForDate(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                        onPostClick: { post in
                            selectedPost = post
                            showingPostPreview = true
                        },
                        onSelect: {
                            selectedDate = date
                            selectedDateForList = date
                            postsForSelectedDate = postsForDate(date)
                            showPostListSheet = true
                        },
                        onDoubleClick: {
                            // Double-click to schedule post on future date or today
                            let today = Date()
                            if calendar.isDateInToday(date) || date > today {
                                prefilledDate = date
                                showingComposer = true
                            }
                        }
                    )
                    .onDrop(of: [.text], delegate: PostDropDelegate(
                        targetDate: date,
                        posts: posts,
                        modelContext: modelContext
                    ))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial.opacity(0.3))
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showPostListSheet) {
            CalendarPostListSheet(
                date: selectedDateForList,
                posts: postsForSelectedDate,
                selectedPost: $selectedPost,
                isPresented: $showPostListSheet,
                onPostTap: { post in
                    showingPostPreview = true
                    showPostListSheet = false
                }
            )
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
    
    private func postsForDate(_ date: Date) -> [CloutmateShared.Post] {
        posts.filter { post in
            // Check both scheduledDate and publishedDate
            if let scheduledDate = post.scheduledDate, calendar.isDate(scheduledDate, inSameDayAs: date) {
                return true
            }
            if let publishedDate = post.publishedDate, calendar.isDate(publishedDate, inSameDayAs: date) {
                return true
            }
            return false
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
    let posts: [CloutmateShared.Post]
    let isSelected: Bool
    let isCurrentMonth: Bool
    var onPostClick: ((CloutmateShared.Post) -> Void)?
    
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
                        Image(systemName: "doc.text")
                            .font(.system(size: 11))
                            .foregroundColor(.kosmicBlue)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .onTapGesture {
                                onPostClick?(post)
                            }
                    }
                    if posts.count > 2 {
                        Text("+\(posts.count - 2)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            Group {
                if isToday {
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if isSelected {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if isWeekend {
                    LinearGradient(
                        colors: [Color.secondary.opacity(0.08), Color.secondary.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected && !isToday ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: posts.isEmpty ? .clear : (isSelected ? Color.accentColor.opacity(0.3) : .black.opacity(0.05)), radius: isSelected ? 4 : 2, x: 0, y: isSelected ? 2 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func colorForPost(_ post: CloutmateShared.Post) -> Color {
        return .kosmicBlue
    }
}

#Preview {
    @Previewable @State var showingComposer = false
    @Previewable @State var prefilledDate: Date? = nil
    @Previewable @State var showingPostPreview = false
    @Previewable @State var selectedPost: CloutmateShared.Post? = nil
    
    MonthlyCalendarView(
        posts: [],
        selectedDate: .constant(Date()),
        showingComposer: $showingComposer,
        prefilledDate: $prefilledDate,
        showingPostPreview: $showingPostPreview,
        selectedPost: $selectedPost
    )
}
