//
//  CustomizableDashboardView.swift
//  Cloutmate
//
//  Customizable Dashboard with Drag-and-Drop Layout
//

import SwiftUI
import SwiftData

struct CustomizableDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userCards: [DashboardCard]
    
    @State private var draggedCard: DashboardCard?
    @State private var editingCard: DashboardCard?
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            if sortedCards.isEmpty {
                ContentUnavailableView(
                    "No Dashboard Cards",
                    systemImage: "chart.bar",
                    description: Text("Click the settings button to add dashboard cards")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(sortedCards) { card in
                    DashboardCardView(card: card)
                        .onTapGesture {
                            moveCard(card, direction: .up)
                        }
                }
            }
            .padding()
            }
        }
        .background(Color.clear)
        .navigationTitle("Dashboard")
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
        userCards.filter { $0.isVisible }.sorted { $0.position < $1.position }
    }
    
    private func setupDefaultCardsIfNeeded() {
        // Check if this is the first time opening
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
        }
    }
    
    private func moveCard(_ card: DashboardCard, direction: MoveDirection) {
        // Simple reordering on tap (could be enhanced with gesture-based drag)
        let currentCards = sortedCards
        guard let currentIndex = currentCards.firstIndex(where: { $0.id == card.id }) else { return }
        
        var newIndex = currentIndex
        switch direction {
        case .up: newIndex = max(0, currentIndex - 1)
        case .down: newIndex = min(currentCards.count - 1, currentIndex + 1)
        }
        
        guard newIndex != currentIndex else { return }
        
        // Swap positions
        let otherCard = currentCards[newIndex]
        let temp = card.position
        card.position = otherCard.position
        otherCard.position = temp
        
        try? modelContext.save()
    }
}

enum MoveDirection {
    case up, down
}

struct DashboardCardView: View {
    let card: DashboardCard
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack {
                Image(systemName: card.type.icon)
                    .foregroundColor(.blue)
                
                Text(card.type.rawValue)
                    .font(.headline)
                
                Spacer()
                
                if card.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            // Card Content based on type
            Group {
                switch card.type {
                case .todayOverview:
                    TodayOverviewCard()
                case .inboxCount:
                    InboxCountCard()
                case .activeProjects:
                    ActiveProjectsCard()
                case .upcomingTasks:
                    UpcomingTasksCard()
                case .scheduledPosts:
                    ScheduledPostsCard()
                case .draftCount:
                    DraftCountCard()
                case .recentNotes:
                    RecentNotesCard()
                default:
                    Text("Card content")
                        .foregroundColor(.secondary)
                }
            }
            .frame(minHeight: 120)
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

// Placeholder Card Views
struct TodayOverviewCard: View {
    @Query private var tasks: [Task]
    @Query private var inbox: [InboxItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(inbox.filter { $0.convertedAt == nil }.count) inbox items")
                    .font(.body)
                Spacer()
                Text("\(tasks.filter { $0.status != .done }.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InboxCountCard: View {
    @Query private var inboxItems: [InboxItem]
    
    var unconvertedCount: Int {
        inboxItems.filter { $0.convertedAt == nil }.count
    }
    
    var body: some View {
        VStack {
            Text("\(unconvertedCount)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.orange)
            Text(unconvertedCount == 1 ? "item waiting" : "items waiting")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ActiveProjectsCard: View {
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var projects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(projects.prefix(3)) { project in
                HStack {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    Text(project.title)
                        .font(.body)
                    Spacer()
                }
            }
            if projects.isEmpty {
                Text("No active projects")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct UpcomingTasksCard: View {
    @Query private var tasks: [Task]
    
    var upcoming: [Task] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due <= tomorrow && task.status != .done
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(upcoming.prefix(3)) { task in
                HStack {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.status == .done ? .green : .secondary)
                    Text(task.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
            }
            if upcoming.isEmpty {
                Text("No tasks due")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ScheduledPostsCard: View {
    @Query private var posts: [Post]
    
    var scheduledToday: Int {
        posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }.count
    }
    
    var body: some View {
        VStack {
            Text("\(scheduledToday)")
                .font(.system(size: 36, weight: .bold))
            Text(scheduledToday == 1 ? "post today" : "posts today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DraftCountCard: View {
    @Query private var drafts: [Draft]
    
    var activeCount: Int {
        drafts.filter { !$0.isArchived }.count
    }
    
    var body: some View {
        VStack {
            Text("\(activeCount)")
                .font(.system(size: 36, weight: .bold))
            Text(activeCount == 1 ? "draft" : "drafts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct RecentNotesCard: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(notes.prefix(3)) { note in
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(note.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
            }
            if notes.isEmpty {
                Text("No notes yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    CustomizableDashboardView()
        .modelContainer(for: [DashboardCard.self, Task.self, InboxItem.self])
}

