//
//  TasksView.swift
//  FocusOSMenuBar
//
//  Menu Bar Tasks View - Quick Task Management
//

import SwiftUI
import SwiftData
import FocusOSShared

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @FocusState private var isFocused: Bool
    
    @Query(sort: \Task.updatedAt, order: .reverse) private var tasks: [Task]
    
    @State private var newTitle = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Quick Add Task
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add Task")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(glassColorSystem.cardColor())
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                            .overlay(
                                TextField("Add task...", text: $newTitle)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .focused($isFocused)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        isFocused ? glassColorSystem.buttonColor(for: .primary) : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .frame(height: 44)
                            .animation(Animation.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
                        
                        GlassButton(
                            nil,
                            icon: "plus.circle.fill",
                            style: .iconOnly,
                            role: .primary
                        ) {
                            addTask()
                        }
                        .disabled(newTitle.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                if !tasks.isEmpty {
                    Text("Recent Tasks")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(glassColorSystem.textPrimary())
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    ForEach(tasks.prefix(10)) { task in
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(glassColorSystem.cardColor())
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                            .overlay(
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(glassColorSystem.buttonColor(for: .primary))
                                        .font(.system(size: 14))
                                    Text(task.title.isEmpty ? "(No title)" : task.title)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                        .foregroundColor(glassColorSystem.textPrimary())
                                    Spacer()
                                    Text(task.updatedAt, style: .relative)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(glassColorSystem.textSecondary())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            )
                            .frame(height: 44)
                            .padding(.horizontal, 16)
                            .floatLift()
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("✨")
                            .font(.system(size: 40))
                        Text("No tasks yet")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 72/255, green: 131/255, blue: 255/255), // kosmicBlue
                                        Color(red: 124/255, green: 77/255, blue: 255/255)  // kosmicPurple
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Add a task to get started")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 16)
        }
    }
    
    private func addTask() {
        guard !newTitle.isEmpty else { return }
        let task = Task(title: newTitle)
        modelContext.insert(task)
        do {
            try modelContext.save()
            withAnimation(Animation.spring(response: 0.3, dampingFraction: 0.7)) {
                newTitle = ""
            }
        } catch {
            print("Failed to save task: \(error)")
        }
    }
}

#Preview {
    TasksView()
        .modelContainer(for: [Task.self])
}
