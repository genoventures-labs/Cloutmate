//
//  DailyOutcomesDrawer.swift
//  Cloutmate
//
//  Evening ritual drawer showing task completion stats, project progress, and daily highlights
//

import SwiftUI
import SwiftData
import CloutmateShared

struct DailyOutcomesDrawer: View {
    @Binding var isPresented: Bool
    let ritualType: FocusRitualType
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Query(sort: \CloutmateShared.Task.dueDate) private var allTasks: [CloutmateShared.Task]
    @Query(sort: \CloutmateShared.Project.dueDate) private var allProjects: [CloutmateShared.Project]
    
    private let calendar = Calendar.current
    private let today = Date()
    
    private var tone: AuroraTone {
        AuroraToneKit.tone(for: ritualType)
    }
    
    init(isPresented: Binding<Bool>, ritualType: FocusRitualType) {
        self._isPresented = isPresented
        self.ritualType = ritualType
    }
    
    private var todayTasks: [Task] {
        allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: today)
        }
    }
    
    private var completedTasks: [Task] {
        todayTasks.filter { task in
            guard let completedAt = task.completedAt else { return task.status == .done }
            return calendar.isDate(completedAt, inSameDayAs: today) && task.status == .done
        }
    }
    
    private var deferredTasks: [Task] {
        // TaskStatus doesn't have .deferred - return empty array or filter by cancelled if needed
        []
    }
    
    private var droppedTasks: [Task] {
        // TaskStatus doesn't have .dropped - filter by cancelled instead
        todayTasks.filter { task in
            task.status == .cancelled
        }
    }
    
    private var completionRate: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(todayTasks.count)
    }
    
    private var activeProjects: [Project] {
        allProjects.filter { $0.status == .active }
    }
    
    private var projectsCompletedToday: [Project] {
        allProjects.filter { project in
            // Project doesn't have completedAt - check if status is completed and updatedAt is today
            project.status == .completed && calendar.isDate(project.updatedAt, inSameDayAs: today)
        }
    }
    
    private var topCompletedTasks: [Task] {
        Array(completedTasks.prefix(5))
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // Backdrop
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer
                        VStack(spacing: 0) {
                            // Header
                            V2DrawerScaffold(
                                accentGradient: AuroraToneKit.accentGradient(for: tone),
                                showsSidebar: false,
                                header: { headerContent },
                                content: { drawerContent },
                                sidebar: { EmptyView() }
                            )
                        }
                        .frame(width: 600)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .trailing))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Outcomes")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text(today.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface,
                tintColor: glassColorSystem.backgroundElevated()
            ) {
                closeDrawer()
            }
            .accessibilityLabel("Close")
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Task Completion Stats
                taskStatsSection
                
                // Project Progress
                projectProgressSection
                
                // Daily Highlights
                dailyHighlightsSection
                
                // View Details buttons
                viewDetailsSection
            }
            .padding(.vertical, 8)
        }
    }
    
    private var taskStatsSection: some View {
        DashboardTile(accent: AuroraToneKit.accentColor(for: tone), padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuroraToneKit.accentColor(for: tone))
                    
                    Text("Task Completion")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                HStack(spacing: 24) {
                    statCard(
                        label: "Done",
                        value: "\(completedTasks.count)",
                        color: .kosmicGreen
                    )
                    
                    statCard(
                        label: "Deferred",
                        value: "\(deferredTasks.count)",
                        color: .orange
                    )
                    
                    statCard(
                        label: "Dropped",
                        value: "\(droppedTasks.count)",
                        color: .red
                    )
                }
                
                // Completion rate
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Completion Rate")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                        
                        Spacer()
                        
                        Text("\(Int(completionRate * 100))%")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AuroraToneKit.accentColor(for: tone))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(glassColorSystem.borderColor().opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AuroraToneKit.accentColor(for: tone), AuroraToneKit.accentColor(for: tone).opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * completionRate, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
    
    private var projectProgressSection: some View {
        DashboardTile(accent: AuroraToneKit.accentColor(for: tone), padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuroraToneKit.accentColor(for: tone))
                    
                    Text("Project Progress")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                HStack(spacing: 24) {
                    statCard(
                        label: "Active",
                        value: "\(activeProjects.count)",
                        color: .kosmicBlue
                    )
                    
                    statCard(
                        label: "Completed Today",
                        value: "\(projectsCompletedToday.count)",
                        color: .kosmicGreen
                    )
                }
            }
        }
    }
    
    private var dailyHighlightsSection: some View {
        DashboardTile(accent: AuroraToneKit.accentColor(for: tone), padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuroraToneKit.accentColor(for: tone))
                    
                    Text("Daily Highlights")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                if !topCompletedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Top Completed Tasks")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                        
                        ForEach(topCompletedTasks) { task in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.kosmicGreen)
                                
                                Text(task.title)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if !projectsCompletedToday.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Projects Completed")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                        
                        ForEach(projectsCompletedToday) { project in
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.kosmicGreen)
                                
                                Text(project.title)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
    
    private var viewDetailsSection: some View {
        HStack(spacing: 12) {
            GlassButton(
                "View Tasks",
                icon: "checkmark.circle.fill",
                style: .pill,
                role: .accent
            ) {
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.tasks)
                closeDrawer()
            }
            
            GlassButton(
                "View Projects",
                icon: "folder.fill",
                style: .pill,
                role: .accent
            ) {
                NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
                closeDrawer()
            }
        }
    }
    
    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(glassColorSystem.textSecondary())
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    DailyOutcomesDrawer(
        isPresented: $isPresented,
        ritualType: .evening
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Task.self, Project.self])
}

