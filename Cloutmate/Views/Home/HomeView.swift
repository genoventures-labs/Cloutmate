//
//  HomeView.swift
//  Cloutmate
//
//  Merged Dashboard + Today with CODE workflow guidance
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query private var userCards: [DashboardCard]
    @Query private var tasks: [Task]
    @Query private var posts: [Post]
    @Query private var inboxItems: [InboxItem]
    @Query private var projects: [Project]
    
    @State private var showSettings = false
    
    var unconvertedInbox: Int {
        inboxItems.filter { $0.convertedAt == nil }.count
    }
    
    var todayTasks: [Task] {
        tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && task.status != .done
        }
    }
    
    var todayPosts: [Post] {
        posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
    }
    
    var activeProjects: [Project] {
        projects.filter { $0.status == .active }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome Back")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 8)
                
                // CODE Workflow Navigation
                CODEWorkflowGrid()
                
                // Daily Focus Area
                if !todayTasks.isEmpty || !todayPosts.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Focus")
                            .font(.system(size: 20, weight: .semibold))
                        
                        GlassCard(showHeader: false, headerContent: nil) {
                            DailyFocusContent(tasks: todayTasks, posts: todayPosts)
                        }
                    }
                }
                
                // Inbox Banner
                if unconvertedInbox > 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(unconvertedInbox) items in inbox waiting")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Convert them to organize your workflow.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Open Inbox") {
                            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.inbox)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Dashboard Cards
                if !sortedCards.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Dashboard")
                            .font(.system(size: 20, weight: .semibold))
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            ForEach(sortedCards) { card in
                                DashboardCardContent(card: card)
                                    .gridCellColumns(card.cardSize == .large ? 2 : 1)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            DashboardSettingsView()
        }
        .onAppear {
            setupDefaultCardsIfNeeded()
        }
    }
    
    private var sortedCards: [DashboardCard] {
        // Filter visible cards and remove duplicates by cardType
        let visibleCards = userCards.filter { $0.isVisible }
        var seenTypes: Set<DashboardCardType> = []
        var uniqueCards: [DashboardCard] = []
        
        for card in visibleCards.sorted(by: { $0.position < $1.position }) {
            if !seenTypes.contains(card.type) {
                seenTypes.insert(card.type)
                uniqueCards.append(card)
            }
        }
        
        return uniqueCards
    }
    
    private func setupDefaultCardsIfNeeded() {
        // Only create default cards if there are NO cards at all
        if userCards.isEmpty {
            let defaultCards = [
                DashboardCard(cardType: .todayOverview, position: 0, size: .large),
                DashboardCard(cardType: .inboxCount, position: 1, size: .small),
                DashboardCard(cardType: .activeProjects, position: 2, size: .small),
                DashboardCard(cardType: .upcomingTasks, position: 3, size: .small),
                DashboardCard(cardType: .scheduledPosts, position: 4, size: .small),
                DashboardCard(cardType: .recentNotes, position: 5, size: .small)
            ]
            
            for card in defaultCards {
                modelContext.insert(card)
            }
            
            try? modelContext.save()
        } else {
            // Remove any duplicate cards by type
            var seenTypes: Set<DashboardCardType> = []
            var positionsToKeep: [UUID] = []
            
            for card in userCards.sorted(by: { $0.createdAt < $1.createdAt }) {
                if !seenTypes.contains(card.type) {
                    seenTypes.insert(card.type)
                    positionsToKeep.append(card.id)
                }
            }
            
            // Delete duplicate cards
            for card in userCards {
                if !positionsToKeep.contains(card.id) {
                    modelContext.delete(card)
                }
            }
            
            try? modelContext.save()
        }
    }
}

struct CODEWorkflowGrid: View {
    @State private var hoveredStep: String?
    
    var body: some View {
        HStack(spacing: 12) {
            CODEButton(
                step: "Capture",
                icon: "plus.circle.fill",
                color: .blue,
                hoveredStep: $hoveredStep
            ) {
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.inbox)
            }
            CODEButton(
                step: "Organize",
                icon: "folder.fill",
                color: .green,
                hoveredStep: $hoveredStep
            ) {
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
            }
            CODEButton(
                step: "Distill",
                icon: "sparkles",
                color: .purple,
                hoveredStep: $hoveredStep
            ) {
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.resources)
            }
            CODEButton(
                step: "Express",
                icon: "square.and.pencil",
                color: .orange,
                hoveredStep: $hoveredStep
            ) {
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.drafts)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
    }
    
    struct CODEButton: View {
        let step: String
        let icon: String
        let color: Color
        @Binding var hoveredStep: String?
        let action: () -> Void
        
        @State private var isHovered = false
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isHovered ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color.primary))
                        .frame(width: 40, height: 40)
                    Text(step)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? color.opacity(0.08) : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                hoveredStep = hovering ? step : nil
            }
        }
    }
}

struct DailyFocusContent: View {
    let tasks: [Task]
    let posts: [Post]
    
    var body: some View {
        VStack(spacing: 16) {
            if !tasks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.blue)
                    Text("\(tasks.count) tasks due today")
                        .font(.body)
                    Spacer()
                }
            }
            
            if !posts.isEmpty {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.purple)
                    Text("\(posts.count) posts scheduled")
                        .font(.body)
                    Spacer()
                }
            }
        }
    }
}

struct DashboardCardContent: View {
    let card: DashboardCard
    @Query private var tasks: [Task]
    @Query private var inbox: [InboxItem]
    @Query private var allInboxItems: [InboxItem]
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var projects: [Project]
    @Query private var allTasks: [Task]
    @Query private var allPosts: [Post]
    @Query private var allDrafts: [Draft]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    
    private var headerView: some View {
        HStack {
            Image(systemName: card.type.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.blue.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.08))
                )
            
            Text(card.type.rawValue)
                .font(.system(size: 17, weight: .semibold))
            
            Spacer()
            
            if card.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Small builders to ease type-checker
    private func todayOverviewView(inboxPendingCount: Int, activeTasksCount: Int) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tray.fill").foregroundColor(.orange)
                Text("\(inboxPendingCount) inbox items").font(.body)
                Spacer()
            }
            HStack {
                Image(systemName: "checkmark.circle").foregroundColor(.blue)
                Text("\(activeTasksCount) active tasks").font(.body)
                Spacer()
            }
        })
    }
    
    private func inboxCountView(waitingInboxCount: Int) -> AnyView {
        AnyView(VStack(spacing: 4) {
            Text("\(waitingInboxCount)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.orange)
            Text(waitingInboxCount == 1 ? "item waiting" : "items waiting")
                .font(.caption)
                .foregroundColor(.secondary)
                .tracking(0.2)
        })
    }
    
    private func activeProjectsView() -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 8) {
            ForEach(projects.prefix(3)) { project in
                HStack {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text(project.title).font(.body)
                    Spacer()
                }
            }
            if projects.isEmpty {
                Text("No active projects").font(.caption).foregroundColor(.secondary)
            }
        })
    }
    
    private func upcomingTasksView() -> AnyView {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let upcoming = allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due <= tomorrow && task.status != .done
        }
        return AnyView(VStack(alignment: .leading, spacing: 6) {
            ForEach(upcoming.prefix(3)) { task in
                HStack {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.status == .done ? .green : .secondary)
                    Text(task.title).font(.caption).lineLimit(1)
                    Spacer()
                }
            }
            if upcoming.isEmpty {
                Text("No tasks due").font(.caption).foregroundColor(.secondary)
            }
        })
    }
    
    private func scheduledPostsView() -> AnyView {
        let scheduledToday = allPosts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }.count
        return AnyView(VStack(spacing: 4) {
            Text("\(scheduledToday)").font(.system(size: 48, weight: .bold))
            Text(scheduledToday == 1 ? "post today" : "posts today")
                .font(.caption).foregroundColor(.secondary).tracking(0.2)
        })
    }
    
    private func draftCountView() -> AnyView {
        let activeCount = allDrafts.filter { !$0.isArchived }.count
        return AnyView(VStack(spacing: 4) {
            Text("\(activeCount)").font(.system(size: 48, weight: .bold))
            Text(activeCount == 1 ? "draft" : "drafts")
                .font(.caption).foregroundColor(.secondary).tracking(0.2)
        })
    }
    
    private func recentNotesView() -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 6) {
            ForEach(notes.prefix(3)) { note in
                HStack {
                    Image(systemName: "doc.text").foregroundColor(.secondary).font(.caption)
                    Text(note.title).font(.caption).lineLimit(1)
                    Spacer()
                }
            }
            if notes.isEmpty {
                Text("No notes yet").font(.caption).foregroundColor(.secondary)
            }
        })
    }
    
    private func textOnlyView(_ text: String) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.caption).foregroundColor(.secondary)
        })
    }
    
    private func postingStreakView() -> AnyView {
        AnyView(VStack(spacing: 4) {
            Text("0").font(.system(size: 48, weight: .bold)).foregroundColor(.orange)
            Text("day streak").font(.caption).foregroundColor(.secondary).tracking(0.2)
        })
    }
    
    private func defaultView() -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 8) {
            Text(card.type.rawValue).font(.caption).foregroundColor(.secondary)
            Text("Not implemented yet").font(.caption2).foregroundColor(.secondary)
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            Spacer()
            
            // Precompute simple counts to aid type-checker
            let inboxPendingCount = inbox.filter { $0.convertedAt == nil }.count
            let activeTasksCount = tasks.filter { $0.status != .done }.count
            let waitingInboxCount = allInboxItems.filter { $0.convertedAt == nil }.count
            
            // Build content in a local variable to simplify the ViewBuilder
            let content: AnyView = {
                switch card.type {
                case .todayOverview: return todayOverviewView(inboxPendingCount: inboxPendingCount, activeTasksCount: activeTasksCount)
                case .inboxCount: return inboxCountView(waitingInboxCount: waitingInboxCount)
                case .activeProjects: return activeProjectsView()
                case .upcomingTasks: return upcomingTasksView()
                case .scheduledPosts: return scheduledPostsView()
                case .draftCount: return draftCountView()
                case .recentNotes: return recentNotesView()
                case .areasOverview: return textOnlyView("Areas Overview")
                case .recentInsights: return textOnlyView("Recent Insights")
                case .postingStreak: return postingStreakView()
                case .topPerformingPost: return textOnlyView("Top Performing Post")
                case .quickCapture: return textOnlyView("Quick Capture")
                case .aiSuggestions: return textOnlyView("AI Suggestions")
                default: return defaultView()
                }
            }()

            Group { content }
            .frame(minHeight: 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
    }
}

// Note: Dashboard card views are defined in CustomizableDashboardView.swift to avoid duplication

#Preview {
    HomeView()
        .modelContainer(for: [DashboardCard.self, Task.self, InboxItem.self, Post.self, Project.self])
        .environmentObject(GlassColorSystem())
}

