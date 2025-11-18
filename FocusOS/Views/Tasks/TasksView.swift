//
//  TasksView.swift
//  FocusOS
//
//  Legacy tasks table replaced by the unified experience.
//

import SwiftUI
import SwiftData
import FocusOSShared

struct TasksView: View {
    var body: some View {
        UnifiedTasksView()
    }
}

#Preview {
    TasksView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [FocusOSShared.Task.self, FocusOSShared.Project.self, Area.self])
}

