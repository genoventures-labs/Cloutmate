//
//  WeeklyCalendarView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI

struct WeeklyCalendarView: View {
    let posts: [Post]
    @Binding var selectedDate: Date
    
    @State private var displayedWeek = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Week header
            HStack {
                Button(action: previousWeek) {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(weekRangeText)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextWeek) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()
            
            // Days with posts
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(weekDays, id: \.self) { date in
                        DayColumn(
                            date: date,
                            posts: postsForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
                .padding()
            }
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
    
    private func postsForDate(_ date: Date) -> [Post] {
        posts.filter { post in
            guard let scheduledDate = post.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date)
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
    let posts: [Post]
    let isSelected: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day header
            HStack {
                Text(dayText)
                    .font(.headline)
                Text(dateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(posts.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            
            // Posts
            ForEach(posts) { post in
                PostCard(post: post)
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
    let post: Post
    
    var body: some View {
        HStack(spacing: 10) {
            // Platform badges
            ForEach(post.postPlatforms, id: \.self) { platform in
                Image(systemName: platform == .threads ? "t.square.fill" : "f.square.fill")
                    .font(.system(size: 14))
                    .foregroundColor(platform == .threads ? .purple : .blue)
            }
            
            // Time
            if let scheduledDate = post.scheduledDate {
                Text(scheduledDate, style: .time)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Caption preview
            Text(post.caption)
                .lineLimit(1)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .draggable(post.dragInfo)
    }
}

#Preview {
    WeeklyCalendarView(posts: [], selectedDate: .constant(Date()))
}

