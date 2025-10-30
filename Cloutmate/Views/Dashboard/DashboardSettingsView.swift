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
    
    @State private var availableCards: [DashboardCardType] = DashboardCardType.allCases
    
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Available Cards Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Cards")
                            .font(.system(size: 17, weight: .semibold))
                        
                        ForEach(availableCards, id: \.self) { cardType in
                            Toggle(
                                cardType.rawValue,
                                isOn: Binding(
                                    get: { isCardVisible(cardType) },
                                    set: { enabled in
                                        toggleCard(cardType, enabled: enabled)
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Card Sizes Section
                    if !visibleCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Card Sizes")
                                .font(.system(size: 17, weight: .semibold))
                            
                            ForEach(visibleCards, id: \.id) { card in
                                HStack {
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
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(20)
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
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func toggleCard(_ cardType: DashboardCardType, enabled: Bool) {
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

#Preview {
    DashboardSettingsView()
        .modelContainer(for: [DashboardCard.self])
}

