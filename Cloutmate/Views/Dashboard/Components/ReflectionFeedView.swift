//
//  ReflectionFeedView.swift
//  Cloutmate
//
//  Dashboard V2 - Journal & Reflection Feed
//

import SwiftUI
import SwiftData

struct ReflectionFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(sort: \Journal.createdAt, order: .reverse)
    private var allJournals: [Journal]
    
    @State private var dailyReflection: String = ""
    
    private var recentJournals: [Journal] {
        Array(allJournals.prefix(7))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Aurora's Reflection of the Day
            if !dailyReflection.isEmpty {
                GlassPanel(tier: .contentCard, cornerRadius: 12, tintColor: .kosmicPurple.opacity(0.1)) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundColor(.kosmicPurple)
                        Text(dailyReflection)
                            .font(.subheadline)
                            .foregroundColor(glassColorSystem.textPrimary())
                            .italic()
                    }
                    .padding(16)
                }
            }
            
            // Recent Journal entries
            if !recentJournals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Reflections")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    LazyVStack(spacing: 12) {
                        ForEach(recentJournals) { journal in
                            JournalEntryCard(journal: journal)
                        }
                    }
                }
            }
        }
        .task {
            await generateDailyReflection()
        }
    }
    
    @MainActor
    private func generateDailyReflection() async {
        // Simplified reflection generation
        if recentJournals.count >= 3 {
            dailyReflection = "You've been most consistent when your sessions begin before noon."
        } else if recentJournals.count > 0 {
            dailyReflection = "Your reflections show a pattern of thoughtful consideration."
        } else {
            dailyReflection = "Start your reflection journey with a journal entry."
        }
    }
}

struct JournalEntryCard: View {
    let journal: Journal
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var toneColor: Color {
        // Map journal mood to ARTE tone colors
        switch journal.journalMood {
        case .calm: return .kosmicBlue
        case .reflective: return .kosmicPurple
        case .creative: return .kosmicGreen
        case .excited, .motivated: return .orange
        default: return .gray
        }
    }
    
    private var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: journal.createdAt, relativeTo: Date())
    }
    
    private var contentPreview: String {
        let lines = journal.content.components(separatedBy: .newlines)
        return lines.prefix(2).joined(separator: " ")
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Tone color dot
                Circle()
                    .fill(toneColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dateString)
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                        Spacer()
                    }
                    
                    if !contentPreview.isEmpty {
                        Text(contentPreview)
                            .font(.subheadline)
                            .foregroundColor(glassColorSystem.textPrimary())
                            .lineLimit(2)
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [toneColor.opacity(0.05), toneColor.opacity(0.02)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
}

#Preview {
    ReflectionFeedView()
        .padding()
        .environmentObject(GlassColorSystem())
}

