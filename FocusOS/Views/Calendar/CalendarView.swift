//
//  CalendarView.swift
//  FocusOS
//
//  Calendar view - now using UnifiedCalendarView
//

import SwiftUI
import SwiftData
import FocusOSShared

struct CalendarView: View {
    var body: some View {
        UnifiedCalendarView()
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [FocusOSShared.Post.self, FocusOSShared.Task.self])
}

