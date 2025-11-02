//
//  CalendarView.swift
//  Cloutmate
//
//  Calendar view - now using UnifiedCalendarView
//

import SwiftUI
import SwiftData
import CloutmateShared

struct CalendarView: View {
    var body: some View {
        UnifiedCalendarView()
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Task.self])
}

