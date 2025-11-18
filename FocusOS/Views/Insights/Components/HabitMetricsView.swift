//
//  HabitMetricsView.swift
//  FocusOS
//
//  Insights V2 - Habit & Completion Panel
//

import SwiftUI
import SwiftData
import Charts
import FocusOSShared

struct HabitMetricsView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var ritualBreakdown: [(type: String, count: Int)] = []
    @State private var activeProjects: [Project] = []
    @State private var showGoodDayBanner = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Habits & Completion")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.kosmicGreen, Color.kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Routine consistency and project momentum")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Behavior Shifts Section
                BehaviorShiftsView(timeRange: timeRange)
                    .padding(.top, 8)
                
                // Task Completion Rate Ring
                if let snapshot = snapshot {
                    let clampedCompletionRate = min(max(snapshot.completionRate, 0), 1)
                    DashboardTile(accent: .kosmicGreen.opacity(0.85), padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Task Completion Rate")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                                
                                Circle()
                                    .trim(from: 0, to: clampedCompletionRate)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.kosmicGreen, Color.kosmicGreen.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: clampedCompletionRate)
                                
                                VStack(spacing: 4) {
                                    Text("\(Int(clampedCompletionRate * 100))%")
                                        .font(.system(.title, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("completed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(height: 150)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Ritual Consistency Bars
                if !ritualBreakdown.isEmpty {
                    DashboardTile(accent: .kosmicGreen.opacity(0.8), padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ritual Consistency")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                ForEach(ritualBreakdown, id: \.type) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(item.type)
                                                .font(.system(.body, design: .rounded))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Text("\(item.count)")
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundColor(.kosmicGreen)
                                        }
                                        
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.secondary.opacity(0.1))
                                                
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color.kosmicGreen, Color.kosmicGreen.opacity(0.7)],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .frame(width: geometry.size.width * min(1.0, Double(item.count) / 14.0))
                                                    .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: item.count)
                                            }
                                        }
                                        .frame(height: 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Project Momentum Dots
                if !activeProjects.isEmpty {
                    DashboardTile(accent: .kosmicBlue.opacity(0.8), padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Project Momentum")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(activeProjects.prefix(5)) { project in
                                        ProjectMomentumDot(project: project)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Streak Tracker
                if let snapshot = snapshot {
                    DashboardTile(accent: .kosmicGreen.opacity(0.8), padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Streak Tracker")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                StreakMeter(
                                    title: "Morning",
                                    streak: snapshot.morningRitualStreak,
                                    color: .kosmicGreen
                                )
                                
                                StreakMeter(
                                    title: "Evening",
                                    streak: snapshot.eveningRitualStreak,
                                    color: .kosmicGreen
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // "Good Day" Summary Banner
                if showGoodDayBanner {
                    DashboardTile(accent: .kosmicGreen.opacity(0.75), padding: 20) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.kosmicGreen)
                                .font(.system(size: 24))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Routine balanced, focus grounded.")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("Both rituals and tasks completed today")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .task {
            await loadHabitData()
        }
        .onChange(of: timeRange) { _, _ in
            _Concurrency.Task {
                await loadHabitData()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadHabitData() async {
        guard let snapshot = snapshot else { return }
        
        let (startDate, endDate) = timeRange.dateRange
        
        // Load ritual completions
        let ritualDescriptor = FetchDescriptor<RitualCompletion>(
            predicate: #Predicate { completion in
                completion.completedAt >= startDate && completion.completedAt <= endDate
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        
        let completions = (try? modelContext.fetch(ritualDescriptor)) ?? []
        
        // Calculate ritual breakdown
        var morningCount = 0
        var eveningCount = 0
        
        for completion in completions {
            if completion.ritualType == .morning {
                morningCount += 1
            } else if completion.ritualType == .evening {
                eveningCount += 1
            }
        }
        
        ritualBreakdown = [
            (type: "Morning Ritual", count: morningCount),
            (type: "Evening Ritual", count: eveningCount)
        ]
        
        // Load active projects with recent task completions
        var projectDescriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        projectDescriptor.fetchLimit = 10
        
        let allProjects = (try? modelContext.fetch(projectDescriptor)) ?? []
        
        // Filter projects with recent activity
        activeProjects = allProjects.filter { project in
            project.updatedAt >= startDate
        }
        
        // Check for "Good Day" banner
        let today = Calendar.current.startOfDay(for: Date())
        let todayCompletions = completions.filter { Calendar.current.isDate($0.completedAt, inSameDayAs: today) }
        let todayTasks = snapshot.tasksCompleted > 0
        
        showGoodDayBanner = todayCompletions.count >= 2 && todayTasks && snapshot.completionRate > 0.7
    }
}

// MARK: - Streak Meter

struct StreakMeter: View {
    let title: String
    let streak: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text("\(streak)")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text("days")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Visual streak indicator
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: streak > 0 ? [color, color.opacity(0.6)] : [Color.secondary.opacity(0.3), Color.secondary.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(1.0, Double(streak) / 30.0))
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Project Momentum Dot

struct ProjectMomentumDot: View {
    let project: Project
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.kosmicGreen.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Circle()
                    .fill(Color.kosmicGreen)
                    .frame(width: 20, height: 20)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.6 : 1.0)
            }
            
            Text(project.title)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 60)
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    HabitMetricsView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [RitualCompletion.self, Project.self])
    .environmentObject(GlassColorSystem())
    .padding()
}

