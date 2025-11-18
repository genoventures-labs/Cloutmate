//
//  NotesHeaderView.swift
//  FocusOS
//
//  Unified header zone for Notes V2 redesign
//

import SwiftUI
import SwiftData
import AppKit
import FocusOSShared

enum NotesFilter: String, CaseIterable {
    case all = "All"
    case tagged = "Tagged"
    case recent = "Recent"
    case aiSummaries = "AI Summaries"
    case archived = "Archived"
}

struct NotesHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedFilter: NotesFilter
    @Binding var isSelectionMode: Bool
    @Binding var selectedViewMode: NotesViewMode
    
    let totalNotes: Int
    let taggedNotes: Int
    let selectionCount: Int
    let onCreate: () -> Void
    let onToggleSelection: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .overlay, cornerRadius: 12) {
            VStack(spacing: 16) {
                // Title and subline
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("\(totalNotes) notes • \(taggedNotes) tagged")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // View Mode Switcher
                        viewModeSwitcher
                        
                        GlassButton(
                            icon: isSelectionMode || selectionCount > 0 ? "checkmark.circle.fill" : "checkmark.circle",
                            style: .iconOnly,
                            role: .surface
                        ) {
                            onToggleSelection()
                        }
                        .accessibilityLabel(isSelectionMode ? "Exit selection mode" : "Enter selection mode")
                        .help(isSelectionMode ? "Done Selecting" : "Select Notes")
                        
                        // Quick Add button
                        GlassButton(
                            icon: "plus",
                            style: .iconOnly,
                            role: .primary
                        ) {
                            onCreate()
                        }
                        .accessibilityLabel("Create new note")
                    }
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    TextField("Search thoughts or tags", text: $searchText)
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
    
    private var viewModeSwitcher: some View {
        HStack(spacing: 4) {
            viewModeButton(.cards)
            viewModeButton(.list)
            viewModeButton(.grid)
            viewModeButton(.board)
            viewModeButton(.timeline)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func viewModeButton(_ mode: NotesViewMode) -> some View {
        Button(action: {
            selectedViewMode = mode
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }) {
            Image(systemName: mode.icon)
                .font(.caption)
                .foregroundColor(selectedViewMode == mode ? .kosmicBlue : glassColorSystem.textSecondary())
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedViewMode == mode ? Color.kosmicBlue.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(mode.displayName)
    }
    
    private var filterChips: [FilterChipGroup.FilterChipData] {
        NotesFilter.allCases.map { filter in
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
    NotesHeaderView(
        searchText: .constant(""),
        selectedFilter: .constant(.all),
        isSelectionMode: .constant(false),
        selectedViewMode: .constant(.cards),
        totalNotes: 128,
        taggedNotes: 14,
        selectionCount: 0,
        onCreate: {},
        onToggleSelection: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

