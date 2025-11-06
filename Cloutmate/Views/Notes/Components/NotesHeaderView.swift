//
//  NotesHeaderView.swift
//  Cloutmate
//
//  Unified header zone for Notes V2 redesign
//

import SwiftUI
import SwiftData
import CloutmateShared

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
    @Binding var showCreateSheet: Bool
    
    let totalNotes: Int
    let taggedNotes: Int
    
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
                    
                    // Quick Add button
                    GlassButton(
                        icon: "plus",
                        style: .iconOnly,
                        role: .primary
                    ) {
                        showCreateSheet = true
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
        showCreateSheet: .constant(false),
        totalNotes: 128,
        taggedNotes: 14
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

