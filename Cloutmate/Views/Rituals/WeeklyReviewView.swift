//
//  WeeklyReviewView.swift
//  Cloutmate
//
//  Weekly review ritual workflow
//

import SwiftUI
import SwiftData
import CloutmateShared

struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var inboxItems: [CloutmateShared.InboxItem]
    @Query private var tasks: [CloutmateShared.Task]
    @Query private var projects: [CloutmateShared.Project]
    @Query private var posts: [CloutmateShared.Post]
    
    @State private var currentStep = ReviewStep.clearInbox
    @State private var completedSteps: Set<ReviewStep> = []
    @State private var weekLearnings = ""
    @State private var nextWeekPriorities = ""
    
    enum ReviewStep: String, CaseIterable {
        case clearInbox = "Clear Inbox"
        case reviewProjects = "Review Projects"
        case checkTasks = "Check Tasks"
        case schedulePosts = "Schedule Posts"
        case captureLearnings = "Capture Learnings"
        
        var icon: String {
            switch self {
            case .clearInbox: return "tray.fill"
            case .reviewProjects: return "folder.fill"
            case .checkTasks: return "checkmark.circle"
            case .schedulePosts: return "calendar"
            case .captureLearnings: return "brain.head.profile"
            }
        }
        
        var description: String {
            switch self {
            case .clearInbox: return "Process all items in your inbox"
            case .reviewProjects: return "Update project status and plan ahead"
            case .checkTasks: return "Review and organize upcoming tasks"
            case .schedulePosts: return "Schedule content for the next week"
            case .captureLearnings: return "Capture insights and plan next week"
            }
        }
    }
    
    var unconvertedInbox: [InboxItem] {
        inboxItems.filter { $0.convertedAt == nil }
    }
    
    var upcomingTasks: [Task] {
        let today = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? Date()
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due <= nextWeek && task.status != .done
        }
    }
    
    var activeProjects: [Project] {
        projects.filter { $0.status == .active }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color.kosmicBlue)
                            .font(.largeTitle)
                        Text("Weekly Review")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    
                    Text("Let's get your week organized")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(ReviewStep.allCases, id: \.self) { step in
                            Circle()
                                .fill(completedSteps.contains(step) ? Color.kosmicGreen : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .glassPanel(tier: .overlay, cornerRadius: 12)
                .padding()
                
                // Current step content
                switch currentStep {
                case .clearInbox:
                    ClearInboxStep(items: unconvertedInbox, onComplete: { markComplete(.clearInbox) })
                case .reviewProjects:
                    ReviewProjectsStep(projects: activeProjects, onComplete: { markComplete(.reviewProjects) })
                case .checkTasks:
                    CheckTasksStep(tasks: upcomingTasks, onComplete: { markComplete(.checkTasks) })
                case .schedulePosts:
                    SchedulePostsStep(posts: posts, onComplete: { markComplete(.schedulePosts) })
                case .captureLearnings:
                    CaptureLearningsStep(
                        learnings: $weekLearnings,
                        priorities: $nextWeekPriorities,
                        onComplete: { saveReview() }
                    )
                }
                
                // Navigation
                HStack {
                    if currentStep != ReviewStep.allCases.first {
                        Button("Previous") {
                            previousStep()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep != ReviewStep.allCases.last {
                        Button("Next") {
                            nextStep()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Complete Review") {
                            saveReview()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(weekLearnings.isEmpty && nextWeekPriorities.isEmpty)
                    }
                }
                .padding()
            }
        }
        .background(Color.clear)
        .navigationTitle("Weekly Review")
    }
    
    private func nextStep() {
        markComplete(currentStep)
        if let currentIndex = ReviewStep.allCases.firstIndex(of: currentStep),
           currentIndex < ReviewStep.allCases.count - 1 {
            currentStep = ReviewStep.allCases[currentIndex + 1]
        }
    }
    
    private func previousStep() {
        if let currentIndex = ReviewStep.allCases.firstIndex(of: currentStep),
           currentIndex > 0 {
            currentStep = ReviewStep.allCases[currentIndex - 1]
        }
    }
    
    private func markComplete(_ step: ReviewStep) {
        completedSteps.insert(step)
    }
    
    private func saveReview() {
        // Create summary note
        let noteTitle = "Weekly Review - \(Date().formatted(date: .complete, time: .omitted))"
        let noteContent = """
        # Weekly Review
        
        ## Key Learnings
        \(weekLearnings)
        
        ## Next Week Priorities
        \(nextWeekPriorities)
        
        ## Completed Steps
        \(completedSteps.map { "- \($0.rawValue)" }.joined(separator: "\n"))
        """
        
        let reviewNote = Note(title: noteTitle, markdown: noteContent, tags: ["review", "weekly"])
        modelContext.insert(reviewNote)
        
        try? modelContext.save()
    }
}

struct ClearInboxStep: View {
    let items: [InboxItem]
    let onComplete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 1: Clear Your Inbox")
                .font(.headline)
                .padding(.horizontal)
            
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.kosmicGreen)
                    
                    Text("Inbox is empty!")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Great work keeping your inbox clean.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassPanel(tier: .contentCard, cornerRadius: 12)
                .padding(.horizontal)
                
                Button("Mark Complete") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                Text("You have \(items.count) unconverted items in your inbox")
                    .font(.body)
                    .padding(.horizontal)
                
                ForEach(items.prefix(5)) { item in
                    HStack {
                        Text(item.content)
                            .lineLimit(2)
                            .font(.body)
                        Spacer()
                        Button("Convert") {
                            // Quick convert to note
                            let note = Note(title: item.content.prefix(50).description, markdown: item.content)
                            modelContext.insert(note)
                            item.convertedAt = Date()
                            item.convertedToType = "note"
                            try? modelContext.save()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 8)
                    .padding(.horizontal)
                }
                
                if items.count > 5 {
                    Text("+ \(items.count - 5) more items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct ReviewProjectsStep: View {
    let projects: [Project]
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 2: Review Projects")
                .font(.headline)
                .padding(.horizontal)
            
            if projects.isEmpty {
                Text("No active projects to review")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 12)
                    .padding(.horizontal)
                
                Button("Mark Complete") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                ForEach(projects.prefix(5)) { project in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.kosmicBlue)
                        Text(project.title)
                            .font(.body)
                        Spacer()
                        ProjectStatusBadge(status: project.status)
                    }
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 8)
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct CheckTasksStep: View {
    let tasks: [Task]
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 3: Check Tasks")
                .font(.headline)
                .padding(.horizontal)
            
            if tasks.isEmpty {
                Text("No tasks due this week")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 12)
                    .padding(.horizontal)
                
                Button("Mark Complete") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                ForEach(tasks.prefix(5)) { task in
                    TaskRow(task: task)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct SchedulePostsStep: View {
    let posts: [CloutmateShared.Post]
    let onComplete: () -> Void
    
    var upcomingPosts: [CloutmateShared.Post] {
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return scheduled <= nextWeek && post.postStatus != .published
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 4: Schedule Posts")
                .font(.headline)
                .padding(.horizontal)
            
            if upcomingPosts.isEmpty {
                Text("No posts to schedule this week")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 12)
                    .padding(.horizontal)
                
                Button("Mark Complete") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                ForEach(upcomingPosts.prefix(5)) { post in
                    PostPreviewRow(post: post)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct CaptureLearningsStep: View {
    @Binding var learnings: String
    @Binding var priorities: String
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 5: Capture Learnings")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("What went well this week?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                TextEditor(text: $learnings)
                    .frame(height: 100)
                    .padding(8)
                    .glassPanel(tier: .contentCard, cornerRadius: 8)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Top 3 priorities for next week:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                TextEditor(text: $priorities)
                    .frame(height: 100)
                    .padding(8)
                    .glassPanel(tier: .contentCard, cornerRadius: 8)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views
private struct ProjectStatusBadge: View {
    let status: ProjectStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(6)
    }
}

#Preview {
    WeeklyReviewView()
        .modelContainer(for: [CloutmateShared.InboxItem.self, CloutmateShared.Task.self, CloutmateShared.Project.self, CloutmateShared.Post.self, CloutmateShared.Note.self])
}

