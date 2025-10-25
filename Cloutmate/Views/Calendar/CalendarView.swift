//
//  CalendarView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.scheduledDate) private var posts: [Post]
    
    @State private var selectedDate = Date()
    @State private var isWeeklyView = false
    @State private var draggedPost: Post?
    
    var body: some View {
        VStack {
            // View toggle
            Picker("View", selection: $isWeeklyView) {
                Text("Monthly").tag(false)
                Text("Weekly").tag(true)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if isWeeklyView {
                WeeklyCalendarView(posts: posts, selectedDate: $selectedDate)
            } else {
                MonthlyCalendarView(posts: posts, selectedDate: $selectedDate)
            }
        }
        .navigationTitle("Calendar")
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Post.self])
}

