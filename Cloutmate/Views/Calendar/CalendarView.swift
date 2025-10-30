//
//  CalendarView.swift
//  Cloutmate
//
//  Calendar view - now using UnifiedCalendarView
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    var body: some View {
        UnifiedCalendarView()
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Post.self, Task.self])
}

