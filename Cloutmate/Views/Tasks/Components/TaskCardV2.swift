//
//  TaskCardV2.swift
//  Cloutmate
//
//  Tasks V2 - Modern card component with expansion and hover actions
//

import SwiftUI
import SwiftData
import CloutmateShared

struct TaskCardV2: View {
    @Bindable var task: Task
    let project: Project?
    let area: Area?
    let metrics: TaskFocusMetrics
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onRequestFocus: (Task) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var showCompletionAnimation = false
    @State private var previousStatus: TaskStatus?
    
    private var isDueToday: Bool {
        guard let dueDate = task.dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < Date() && task.status != .done
    }
    
    private var dueDateColor: Color {
        if task.status == .done {
            return .gray
        } else if isOverdue {
            return .red
        } else if isDueToday {
            return .kosmicBlue
        } else if let due = task.dueDate,
                  Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0 <= 3 {
            return .kosmicPurple
        }
        return .gray
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 12) {
                // Quick completion checkbox
                Button(action: {
                    completeTask()
                }) {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(task.status == .done ? .kosmicGreen : .secondary.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help(task.status == .done ? "Mark as incomplete" : "Mark as complete")
                .allowsHitTesting(true)
                
                // Progress pill indicator (interactive)
                InteractiveProgressPill(task: task)
                
                // Task content
                VStack(alignment: .leading, spacing: 6) {
                    // Title and due date
                    HStack(alignment: .top) {
                        Text(task.title)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(task.status == .done ? .secondary : .primary)
                            .strikethrough(task.status == .done)
                            .lineLimit(isExpanded ? nil : 2)
                        
                        Spacer()
                        
                        // Due date badge (interactive)
                        InteractiveDueDateBadge(task: task, color: dueDateColor)
                    }
                    
                    // Expanded content
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            // Notes with mention rendering
                            if let notes = task.notes, !notes.isEmpty {
                                MentionRenderedTextView(
                                    text: notes,
                                    textFont: .caption,
                                    mentionFont: .caption
                                )
                                    .foregroundColor(.secondary)
                                    .lineLimit(nil)
                            }
                            
                            // Interactive fields row
                            HStack(spacing: 12) {
                                // Status picker
                                InteractiveStatusPicker(task: task)
                                
                                // Priority picker
                                InteractivePriorityPicker(task: task)
                                
                                Spacer()
                            }
                            
                            // Project/Area
                            if let project = project {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.fill")
                                        .font(.caption2)
                                        .foregroundColor(.kosmicBlue)
                                    Text(project.title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let area = area {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.caption2)
                                        .foregroundColor(.kosmicPurple)
                                    Text(area.title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Focus metrics
                            TaskFocusMetricsView(metrics: metrics, taskTitle: task.title)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // Priority indicator (interactive)
                InteractivePriorityIndicator(task: task)
            }
            .padding(16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(GlassMotion.Easing.spring) {
                    isExpanded.toggle()
                }
            }
            .onTapGesture(count: 2) {
                onEdit()
            }
            .onHover { hovering in
                withAnimation(GlassMotion.Easing.spring) {
                    isHovered = hovering
                }
            }
            
            // Hover actions row
            if isHovered && !isExpanded {
                HStack(spacing: 8) {
                    Spacer()
                    
                    QuickActionButton(icon: "checkmark.circle.fill", color: .kosmicGreen) {
                        completeTask()
                    }
                    
                    QuickActionButton(icon: "pencil", color: .kosmicBlue) {
                        onEdit()
                    }
                    
                    QuickActionButton(icon: "timer", color: .kosmicPurple) {
                        onRequestFocus(task)
                    }
                    
                    QuickActionButton(icon: "archivebox.fill", color: .gray) {
                        onArchive()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .overlay(
            // Animated border for due/overdue tasks
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    borderGradient,
                    lineWidth: isDueToday || isOverdue ? 2 : 0
                )
                .animation(GlassMotion.Easing.spring, value: isDueToday)
        )
        .shadow(
            color: Color.kosmicPurple.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 6 : 4,
            x: 0,
            y: isHovered ? 3 : 2
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .contextMenu {
            Button("Start Focus Session") {
                onRequestFocus(task)
            }
            Divider()
            Button("Edit") {
                onEdit()
            }
            Button("Duplicate") {
                onDuplicate()
            }
            Divider()
            Button("Archive") {
                onArchive()
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .onChange(of: task.status) { oldValue, newValue in
            if newValue == .done && oldValue != .done {
                triggerCompletionAnimation()
            }
            previousStatus = oldValue
        }
        .overlay(
            // Completion animation overlay
            Group {
                if showCompletionAnimation {
                    CompletionAnimationOverlay()
                        .allowsHitTesting(false)
                }
            }
        )
    }
    
    private var borderGradient: LinearGradient {
        if isOverdue {
            return LinearGradient(
                colors: [Color.red.opacity(0.6), Color.red.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if isDueToday {
            return LinearGradient(
                colors: [Color.kosmicBlue.opacity(0.6), Color.kosmicBlue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
    }
    
    private func completeTask() {
        withAnimation(GlassMotion.Easing.spring) {
            if task.status == .done {
                task.status = .todo
            } else {
                task.status = .done
            }
        }
        try? modelContext.save()
    }
    
    private func triggerCompletionAnimation() {
        showCompletionAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                showCompletionAnimation = false
            }
        }
    }
}

// MARK: - Interactive Progress Pill

struct InteractiveProgressPill: View {
    @Bindable var task: Task
    @Environment(\.modelContext) private var modelContext
    
    @State private var pulsePhase: CGFloat = 0
    
    var body: some View {
        Menu {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        task.status = status
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Text(status.displayName)
                        if task.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(pillColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(pillColor)
                
                if task.status == .inProgress {
                    Circle()
                        .stroke(pillColor.opacity(0.4), lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .scaleEffect(1.0 + pulsePhase * 0.3)
                        .opacity(1.0 - pulsePhase)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if task.status == .inProgress {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    pulsePhase = 1.0
                }
            }
        }
    }
    
    private var pillColor: Color {
        switch task.status {
        case .done:
            return .kosmicGreen
        case .inProgress:
            return .orange
        case .cancelled:
            return .gray
        case .todo:
            return .kosmicBlue
        }
    }
    
    private var iconName: String {
        switch task.status {
        case .done:
            return "checkmark"
        case .inProgress:
            return "arrow.clockwise"
        case .cancelled:
            return "xmark"
        case .todo:
            return "circle"
        }
    }
}

// MARK: - Interactive Due Date Badge

struct InteractiveDueDateBadge: View {
    @Bindable var task: Task
    let color: Color
    @Environment(\.modelContext) private var modelContext
    @State private var showDatePicker = false
    
    var body: some View {
        Menu {
            Button("Set Due Date") {
                if task.dueDate == nil {
                    task.dueDate = Date()
                    try? modelContext.save()
                }
                showDatePicker = true
            }
            
            if task.dueDate != nil {
                Button("Remove Due Date", role: .destructive) {
                    task.dueDate = nil
                    try? modelContext.save()
                }
            }
            
            Divider()
            
            Button("Today") {
                task.dueDate = Calendar.current.startOfDay(for: Date())
                try? modelContext.save()
            }
            
            Button("Tomorrow") {
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    task.dueDate = Calendar.current.startOfDay(for: tomorrow)
                    try? modelContext.save()
                }
            }
            
            Button("Next Week") {
                if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) {
                    task.dueDate = Calendar.current.startOfDay(for: nextWeek)
                    try? modelContext.save()
                }
            }
        } label: {
            if let dueDate = task.dueDate {
                Text(dueDate, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15))
                    .foregroundColor(color)
                    .cornerRadius(6)
            } else {
                Image(systemName: "calendar.badge.plus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker) {
            DatePicker(
                "Due Date",
                selection: Binding(
                    get: { task.dueDate ?? Date() },
                    set: {
                        task.dueDate = $0
                        try? modelContext.save()
                        showDatePicker = false
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
        }
    }
}

// MARK: - Interactive Priority Indicator

struct InteractivePriorityIndicator: View {
    @Bindable var task: Task
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(TaskPriority.allCases, id: \.self) { priority in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        task.priority = priority
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Circle()
                            .fill(priority.color)
                            .frame(width: 8, height: 8)
                        Text(priority.displayName)
                        if task.priority == priority {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Circle()
                .fill(task.priority.color.opacity(0.2))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(task.priority.color)
                        .frame(width: 4, height: 4)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interactive Status Picker (for expanded view)

struct InteractiveStatusPicker: View {
    @Bindable var task: Task
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        task.status = status
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Text(status.displayName)
                        if task.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                    )
                Text(task.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch task.status {
        case .done:
            return .kosmicGreen
        case .inProgress:
            return .orange
        case .cancelled:
            return .gray
        case .todo:
            return .kosmicBlue
        }
    }
}

// MARK: - Interactive Priority Picker (for expanded view)

struct InteractivePriorityPicker: View {
    @Bindable var task: Task
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(TaskPriority.allCases, id: \.self) { priority in
                Button(action: {
                    withAnimation(GlassMotion.Easing.spring) {
                        task.priority = priority
                    }
                    try? modelContext.save()
                }) {
                    HStack {
                        Circle()
                            .fill(priority.color)
                            .frame(width: 8, height: 8)
                        Text(priority.displayName)
                        if task.priority == priority {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(task.priority.color.opacity(0.2))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 6, height: 6)
                    )
                Text(task.priority.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .onHover { hovering in
            withAnimation(GlassMotion.Easing.spring) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Completion Animation Overlay

struct CompletionAnimationOverlay: View {
    @State private var gradientPhase: CGFloat = -1
    @State private var opacity: Double = 0.8
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        Color.kosmicBlue.opacity(0.3),
                        Color.kosmicPurple.opacity(0.3),
                        Color.kosmicGreen.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: UnitPoint(x: gradientPhase - 0.3, y: 0.5),
                            endPoint: UnitPoint(x: gradientPhase + 0.3, y: 0.5)
                        )
                    )
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.linear(duration: 0.6)) {
                    gradientPhase = 2
                }
                // Fade out after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        opacity = 0
                    }
                }
            }
    }
}

#Preview {
    let task = Task(
        title: "Sample Task",
        notes: "This is a sample task with some notes",
        status: .inProgress,
        priority: .high,
        dueDate: Date()
    )
    
    return TaskCardV2(
        task: task,
        project: nil,
        area: nil,
        metrics: TaskFocusMetrics.defaultMetrics(for: task),
        onEdit: {},
        onDuplicate: {},
        onArchive: {},
        onDelete: {},
        onRequestFocus: { _ in }
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

