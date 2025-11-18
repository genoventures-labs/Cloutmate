//
//  DailySummaryView.swift
//  FocusOS
//
//  Dashboard V2 - End of Day Summary View
//

import SwiftUI
import SwiftData
import FocusOSShared

struct DailySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(sort: \Task.completedAt, order: .reverse) private var allTasks: [Task]
    @Query(sort: \FocusSession.startTime, order: .reverse) private var allSessions: [FocusSession]
    @Query(sort: \Artifact.publishedAt, order: .reverse) private var allArtifacts: [Artifact]
    @Query(sort: \Journal.entryDate, order: .reverse) private var allJournals: [Journal]
    
    @State private var completedTasks: [Task] = []
    @State private var focusSessions: [FocusSession] = []
    @State private var publishedArtifacts: [Artifact] = []
    @State private var journalEntries: [Journal] = []
    @State private var totalFocusTime: TimeInterval = 0
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End of Day Summary")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(glassColorSystem.textPrimary())
                        
                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    
                    // Stats Overview
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Tasks Completed",
                            value: "\(completedTasks.count)",
                            icon: "checkmark.circle.fill",
                            color: .kosmicGreen
                        )
                        
                        StatCard(
                            title: "Focus Sessions",
                            value: "\(focusSessions.count)",
                            icon: "timer",
                            color: .kosmicBlue
                        )
                        
                        StatCard(
                            title: "Focus Time",
                            value: formatFocusTime(totalFocusTime),
                            icon: "clock.fill",
                            color: .kosmicPurple
                        )
                        
                        StatCard(
                            title: "Artifacts Published",
                            value: "\(publishedArtifacts.count)",
                            icon: "sparkles",
                            color: .kosmicGreen
                        )
                    }
                    .padding(.horizontal, 28)
                    
                    // Completed Tasks
                    if !completedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Completed Tasks")
                                .font(.headline)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .padding(.horizontal, 28)
                            
                            VStack(spacing: 8) {
                                ForEach(completedTasks.prefix(10)) { task in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.kosmicGreen)
                                        Text(task.title)
                                            .font(.subheadline)
                                        Spacer()
                                        if let completedAt = task.completedAt {
                                            Text(completedAt, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(glassColorSystem.cardColor().opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                    
                    // Focus Sessions
                    if !focusSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Focus Sessions")
                                .font(.headline)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .padding(.horizontal, 28)
                            
                            VStack(spacing: 8) {
                                ForEach(focusSessions.prefix(10)) { session in
                                    HStack {
                                        Image(systemName: "timer")
                                            .foregroundColor(.kosmicBlue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formatFocusTime(session.actualDuration))
                                                .font(.subheadline)
                                            Text(session.startTime, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(glassColorSystem.cardColor().opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                    
                    // Published Artifacts
                    if !publishedArtifacts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Published Artifacts")
                                .font(.headline)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .padding(.horizontal, 28)
                            
                            VStack(spacing: 8) {
                                ForEach(publishedArtifacts.prefix(10)) { artifact in
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.kosmicGreen)
                                        Text(artifact.title)
                                            .font(.subheadline)
                                        Spacer()
                                        if let publishedAt = artifact.publishedAt {
                                            Text(publishedAt, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(glassColorSystem.cardColor().opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                    
                    // Journal Entries
                    if !journalEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Journal Entries")
                                .font(.headline)
                                .foregroundColor(glassColorSystem.textPrimary())
                                .padding(.horizontal, 28)
                            
                            VStack(spacing: 8) {
                                ForEach(journalEntries.prefix(5)) { journal in
                                    HStack {
                                        Image(systemName: "book.fill")
                                            .foregroundColor(.kosmicPurple)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(journal.title)
                                                .font(.subheadline)
                                            if !journal.content.isEmpty {
                                                Text(journal.content.prefix(60))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(glassColorSystem.cardColor().opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                    
                    // Empty State
                    if completedTasks.isEmpty && focusSessions.isEmpty && publishedArtifacts.isEmpty && journalEntries.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.kosmicPurple.opacity(0.5))
                            Text("A quiet day")
                                .font(.headline)
                                .foregroundColor(glassColorSystem.textSecondary())
                            Text("Take a moment to reflect on what moved today.")
                                .font(.subheadline)
                                .foregroundColor(glassColorSystem.textSecondary())
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(.windowBackgroundColor))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadDailyData()
        }
    }
    
    @MainActor
    private func loadDailyData() async {
        let today = calendar.startOfDay(for: Date())
        
        // Completed tasks today
        completedTasks = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: Date())
        }
        
        // Focus sessions today
        focusSessions = allSessions.filter { calendar.isDate($0.startTime, inSameDayAs: Date()) }
        totalFocusTime = focusSessions.reduce(0) { $0 + $1.actualDuration }
        
        // Published artifacts today
        publishedArtifacts = allArtifacts.filter { artifact in
            if let publishedAt = artifact.publishedAt {
                return calendar.isDate(publishedAt, inSameDayAs: Date())
            }
            return false
        }
        
        // Journal entries today
        journalEntries = allJournals.filter { calendar.isDate($0.entryDate, inSameDayAs: Date()) }
    }
    
    private func formatFocusTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    DailySummaryView()
        .environmentObject(GlassColorSystem())
}

