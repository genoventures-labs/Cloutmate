//
//  WeeklyCalendarView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import CloutmateShared

struct WeeklyCalendarView: View {
    let posts: [CloutmateShared.Post]
    @Binding var selectedDate: Date
    @Binding var showingComposer: Bool
    @Binding var prefilledDate: Date?
    @Binding var showingPostPreview: Bool
    @Binding var selectedPost: CloutmateShared.Post?
    
    @State private var displayedWeek = Date()
    @State private var showPostListSheet = false
    @State private var postsForSelectedDate: [CloutmateShared.Post] = []
    @State private var selectedDateForList = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Week header with Glass Buttons
            HStack {
                GlassButton(icon: "chevron.left", style: .iconOnly, tintColor: .kosmicBlue, action: previousWeek)
                    .frame(width: 32, height: 32)
                
                Spacer()
                
                Text(weekRangeText)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.kosmicBlue, .kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                GlassButton(icon: "chevron.right", style: .iconOnly, tintColor: .kosmicBlue, action: nextWeek)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            
            // Days with posts
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(weekDays, id: \.self) { date in
                        DayColumn(
                            date: date,
                            posts: postsForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            onPostClick: { post in
                                selectedPost = post
                                showingPostPreview = true
                            }
                        )
                        .onTapGesture {
                            selectedDate = date
                            selectedDateForList = date
                            postsForSelectedDate = postsForDate(date)
                            showPostListSheet = true
                        }
                        .onTapGesture(count: 2) {
                            // Double-click to schedule post on future date or today
                            let calendar = Calendar.current
                            let today = Date()
                            if calendar.isDateInToday(date) || date > today {
                                prefilledDate = date
                                showingComposer = true
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.windowBackgroundColor))
        }
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
    
    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: displayedWeek) else {
            return []
        }
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start)
        }
    }
    
    private var weekRangeText: String {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: displayedWeek) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekInterval.start)
        formatter.dateFormat = "d, yyyy"
        let end = formatter.string(from: weekInterval.end)
        
        return "\(start) - \(end)"
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
    
    private func previousWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: displayedWeek) {
            displayedWeek = newDate
        }
    }
    
    private func nextWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: displayedWeek) {
            displayedWeek = newDate
        }
    }
}

struct DayColumn: View {
    let date: Date
    let posts: [CloutmateShared.Post]
    let isSelected: Bool
    var onPostClick: ((CloutmateShared.Post) -> Void)?
    
    @State private var isHovered = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header with Glass Panel
            GlassPanel(
                tier: isSelected ? .overlay : .contentCard,
                cornerRadius: 12,
                tintColor: isSelected ? Color.kosmicBlue.opacity(0.2) : nil
            ) {
                HStack {
                    Text(dayText)
                        .font(.system(.headline, design: .rounded))
                    Text(dateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(posts.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .shadow(
                color: isSelected ? Color.kosmicBlue.opacity(0.3) : .black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                y: isSelected ? 4 : 1
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(GlassMotion.Easing.spring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            
            // Posts
            ForEach(posts) { post in
                PostCard(post: post, onTap: {
                    onPostClick?(post)
                })
            }
        }
    }
    
    private var dayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct PostCard: View {
    let post: CloutmateShared.Post
    var onTap: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Platform badges
            ForEach(post.postPlatforms, id: \.self) { platform in
                Image(systemName: platform == .threads ? "t.square.fill" : "f.square.fill")
                    .font(.system(size: 15))
                    .foregroundColor(platform == .threads ? .kosmicPurple : .kosmicBlue)
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            }
            
            // Time
            if let scheduledDate = post.scheduledDate {
                Text(scheduledDate, style: .time)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
            }
            
            // Caption preview
            Text(post.caption)
                .lineLimit(1)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(12)
        .background(
            Group {
                if isHovering {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color.secondary.opacity(0.12), Color.secondary.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHovering ? Color.accentColor.opacity(0.4) : Color.accentColor.opacity(0.2),
                    lineWidth: isHovering ? 1.5 : 1
                )
        )
        .cornerRadius(12)
        .shadow(
            color: isHovering ? Color.accentColor.opacity(0.3) : .black.opacity(0.05),
            radius: isHovering ? 4 : 2,
            x: 0,
            y: isHovering ? 2 : 1
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap?()
        }
        .draggable(post.dragInfo)
    }
}

#Preview {
    @Previewable @State var showingComposer = false
    @Previewable @State var prefilledDate: Date? = nil
    @Previewable @State var showingPostPreview = false
    @Previewable @State var selectedPost: CloutmateShared.Post? = nil
    
    return WeeklyCalendarView(
        posts: [],
        selectedDate: .constant(Date()),
        showingComposer: $showingComposer,
        prefilledDate: $prefilledDate,
        showingPostPreview: $showingPostPreview,
        selectedPost: $selectedPost
    )
}
