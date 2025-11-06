//
//  TasksHeaderView.swift
//  Cloutmate
//
//  Tasks V2 - Header component with focus summary and filters
//

import SwiftUI
import CloutmateShared

struct TasksHeaderView: View {
    let todayCompletionRate: String
    let currentStreak: Int
    let selectedFilter: TaskFilter
    let onFilterChange: (TaskFilter) -> Void
    let onQuickAdd: () -> Void
    
    @State private var showFilterDropdown = false
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case upcoming = "Upcoming"
        case completed = "Completed"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left-aligned title and summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Tasks")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Focus Summary: \(todayCompletionRate) • \(currentStreak)-day streak")
                    .font(.caption)
                    .foregroundColor(.kosmicPurple.opacity(0.7))
            }
            
            Spacer()
            
            // Right-side actions
            HStack(spacing: 12) {
                // Filter button with dropdown
                Menu {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            onFilterChange(filter)
                        }) {
                            HStack {
                                Text(filter.rawValue)
                                if selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 14, weight: .medium))
                        Text(selectedFilter.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Quick Add button
                GlassButton(
                    icon: "plus",
                    style: .iconOnly,
                    tintColor: .kosmicPurple,
                    action: onQuickAdd
                )
                .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    TasksHeaderView(
        todayCompletionRate: "3/5 complete",
        currentStreak: 3,
        selectedFilter: .all,
        onFilterChange: { _ in },
        onQuickAdd: {}
    )
    .padding()
    .background(Color(.windowBackgroundColor))
    .environmentObject(GlassColorSystem())
}

