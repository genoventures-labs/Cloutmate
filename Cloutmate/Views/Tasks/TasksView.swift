//
//  TasksView.swift
//  Cloutmate
//
//  Legacy tasks table replaced by the unified experience.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct TasksView: View {
    var body: some View {
        UnifiedTasksView()
    }
}

#Preview {
    TasksView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [CloutmateShared.Task.self, CloutmateShared.Project.self, Area.self])
}

