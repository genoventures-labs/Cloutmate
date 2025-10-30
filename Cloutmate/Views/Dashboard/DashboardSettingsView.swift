//
//  DashboardSettingsView.swift
//  Cloutmate
//
//  Dashboard Customization Settings
//

import SwiftUI
import SwiftData

struct DashboardSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allCards: [DashboardCard]
    
    // Computed properties to reflect actual state
    private var visibleCards: [DashboardCard] {
        allCards.filter { $0.isVisible }
    }
    
    private var isCardVisible: (DashboardCardType) -> Bool {
        { cardType in
            allCards.contains { $0.type == cardType && $0.isVisible }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Main Workflow
                Section("Main Workflow") {
                    ForEach(categorizedCards.workflow, id: \.self) { cardType in
                        Toggle(isOn: bindingFor(cardType)) {
                            HStack {
                                Image(systemName: cardType.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(cardType.rawValue)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                
                // Projects
                Section("Projects") {
                    ForEach(categorizedCards.projects, id: \.self) { cardType in
                        Toggle(isOn: bindingFor(cardType)) {
                            HStack {
                                Image(systemName: cardType.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(cardType.rawValue)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                
                // Areas & Resources
                Section("Areas & Resources") {
                    ForEach(categorizedCards.resources, id: \.self) { cardType in
                        Toggle(isOn: bindingFor(cardType)) {
                            HStack {
                                Image(systemName: cardType.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(cardType.rawValue)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                
                Section("Social Media") {
                    ForEach(categorizedCards.social, id: \.self) { cardType in
                        if cardType == .socialOverview {
                            HStack {
                                Image(systemName: cardType.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("Social Overview (Always On)")
                                Spacer()
                                Image(systemName: "lock.fill").foregroundColor(.secondary)
                            }
                        } else {
                            Toggle(isOn: bindingFor(cardType)) {
                                HStack {
                                    Image(systemName: cardType.icon)
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    Text(cardType.rawValue)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }
                }
                
                Section {
                    ForEach(categorizedCards.facebook, id: \.self) { cardType in
                        Toggle(isOn: bindingFor(cardType)) {
                            HStack {
                                Image(systemName: cardType.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(cardType.rawValue)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                } header: {
                    Text("Facebook Page Insights")
                }
                
                // Visible Cards with Size Settings
                if !visibleCards.isEmpty {
                    Section {
                        ForEach(visibleCards, id: \.id) { card in
                            HStack {
                                Image(systemName: card.type.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(card.type.rawValue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                Picker("Size", selection: Binding(
                                    get: { card.cardSize },
                                    set: { newSize in
                                        updateCardSize(card, size: newSize)
                                    }
                                )) {
                                    ForEach([DashboardCardSize.small, .medium, .large], id: \.self) { size in
                                        Text(size.rawValue.capitalized).tag(size)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }
                        }
                    } header: {
                        Text("Card Sizes")
                    } footer: {
                        Text("Adjust the size of cards that are currently visible on your dashboard")
                    }
                }
            }
            .navigationTitle("Dashboard Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 600)
    }
    
    private func bindingFor(_ cardType: DashboardCardType) -> Binding<Bool> {
        Binding<Bool>(
            get: { isCardVisible(cardType) },
            set: { newValue in
                toggleCard(cardType, enabled: newValue)
            }
        )
    }

    private var categorizedCards: (workflow: [DashboardCardType], projects: [DashboardCardType], resources: [DashboardCardType], social: [DashboardCardType], facebook: [DashboardCardType]) {
        let workflow: [DashboardCardType] = [.todayOverview, .inboxCount, .upcomingTasks, .upcomingDeadlines]
        let projects: [DashboardCardType] = [.activeProjects, .projectsOverview, .tasksOverview, .completionRate]
        let resources: [DashboardCardType] = [.areasHealth, .notesActivity, .recentNotes]
        let social: [DashboardCardType] = [.scheduledPosts, .draftCount, .recentInsights, .postingStreak, .topPerformingPost, .socialOverview, .contentPerformance, .platformComparison]
        let facebook: [DashboardCardType] = [.facebookPageInsightsOverview, .facebookPageViews, .facebookPageFans, .facebookPageReach, .facebookPageImpressions, .facebookEngagedUsers, .facebookPostEngagements]
        return (workflow, projects, resources, social, facebook)
    }
    
    private func toggleCard(_ cardType: DashboardCardType, enabled: Bool) {
        // Lock Social Overview as mandatory hero card
        if cardType == .socialOverview { return }
        if enabled {
            // Add card if it doesn't exist
            if !allCards.contains(where: { $0.type == cardType }) {
                let position = allCards.count
                let card = DashboardCard(
                    cardType: cardType,
                    position: position,
                    size: cardType.defaultSize
                )
                modelContext.insert(card)
            } else {
                // Re-enable existing card
                if let card = allCards.first(where: { $0.type == cardType }) {
                    card.isVisible = true
                }
            }
        } else {
            // Hide card
            if let card = allCards.first(where: { $0.type == cardType }) {
                card.isVisible = false
            }
        }
        
        try? modelContext.save()
    }
    
    private func updateCardSize(_ card: DashboardCard, size: DashboardCardSize) {
        card.cardSize = size
        try? modelContext.save()
    }
}

struct CardToggleRow: View {
    let cardType: DashboardCardType
    let isVisible: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: cardType.icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(cardType.rawValue)
                    .foregroundColor(.primary)
                Spacer()
                if isVisible {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardSettingsView()
        .modelContainer(for: [DashboardCard.self])
}
