//
//  JournalHeaderView.swift
//  FocusOS
//
//  Unified header zone for Journal V2 redesign
//

import SwiftUI
import SwiftData
import FocusOSShared

enum JournalFilter: String, CaseIterable {
    case all = "All"
    case morning = "Morning"
    case evening = "Evening"
    case moodEntries = "Mood Entries"
    case aiReflections = "AI Reflections"
}

struct JournalHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedFilter: JournalFilter
    @Binding var isSelectionMode: Bool
    
    let selectionCount: Int
    let onCreate: () -> Void
    let onToggleSelection: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    // Check if predictive cognition is active (can be enhanced with actual feature flag)
    private var hasPredictiveCognition: Bool {
        // TODO: Check AIConfigService for predictive cognition feature flag
        false
    }
    
    private var sublineText: String {
        if hasPredictiveCognition {
            return "Reflections synced with Aurora • Predictive insights active"
        } else {
            return "Reflections synced with Aurora"
        }
    }
    
    var body: some View {
        GlassPanel(tier: .overlay, cornerRadius: 12) {
            VStack(spacing: 16) {
                // Title and subline
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Journal")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(sublineText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        GlassButton(
                            icon: isSelectionMode || selectionCount > 0 ? "checkmark.circle.fill" : "checkmark.circle",
                            style: .iconOnly,
                            role: .surface
                        ) {
                            onToggleSelection()
                        }
                        .accessibilityLabel(isSelectionMode ? "Exit selection mode" : "Enter selection mode")
                        .help(isSelectionMode ? "Done Selecting" : "Select Entries")
                    
                    // Quick Add button
                    GlassButton(
                        icon: "plus",
                        style: .iconOnly,
                        role: .primary
                    ) {
                        onCreate()
                        }
                        .accessibilityLabel("Create new journal entry")
                    }
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    TextField("Search reflections or emotions…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                
                // Filter chips
                FilterChipGroup(chips: filterChips)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var filterChips: [FilterChipGroup.FilterChipData] {
        JournalFilter.allCases.map { filter in
            FilterChipGroup.FilterChipData(
                id: filter.rawValue,
                title: filter.rawValue,
                isSelected: selectedFilter == filter,
                action: {
                    selectedFilter = filter
                }
            )
        }
    }
}

#Preview {
    JournalHeaderView(
        searchText: .constant(""),
        selectedFilter: .constant(.all),
        isSelectionMode: .constant(false),
        selectionCount: 0,
        onCreate: {},
        onToggleSelection: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

