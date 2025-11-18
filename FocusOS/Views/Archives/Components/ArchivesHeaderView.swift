//
//  ArchivesHeaderView.swift
//  FocusOS
//
//  Archives V2 - Unified header zone
//

import SwiftUI

enum ArchiveFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case projects = "Projects"
    case areas = "Areas"
    case notes = "Notes"
    case artifacts = "Artifacts"
    case drafts = "Drafts"
    
    var id: String { rawValue }
}

struct ArchivesHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedFilter: ArchiveFilter
    @Binding var showReviewSummary: Bool
    @Binding var showRestoreMenu: Bool
    
    @State private var hasAppeared = false
    @FocusState private var isSearchFocused: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var sublineText: String {
        "Everything you've completed, remembered, and learned."
    }
    
    private var titleGradient: LinearGradient {
        if accessibilityManager.performanceMode == .balanced {
            return LinearGradient(colors: [.primary.opacity(0.85), .primary.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing)
    }
    
    var body: some View {
        GlassPanel(tier: .overlay, cornerRadius: 12) {
            VStack(spacing: 16) {
                headerRow
                searchBar
                filterChipsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .overlay(accentBorder)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -18)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82, blendDuration: 0.2)) {
                hasAppeared = true
            }
        }
        .animation(GlassMotion.Easing.spring, value: selectedFilter)
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
    
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Archives")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(titleGradient)
                
                Text(sublineText)
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            // Quick Actions
            HStack(spacing: 8) {
                GlassButton(
                    icon: "location.north",
                    style: .iconOnly,
                    tintColor: .kosmicBlue
                ) {
                    showReviewSummary = true
                }
                .accessibilityLabel("Review Summary")
                .applyIf(!reduceMotion) { view in
                    view.glassHoverEffect()
                }
                
                GlassButton(
                    icon: "arrow.counterclockwise",
                    style: .iconOnly,
                    tintColor: .kosmicPurple
                ) {
                    showRestoreMenu = true
                }
                .accessibilityLabel("Restore")
                .applyIf(!reduceMotion) { view in
                    view.glassHoverEffect()
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)
            
            TextField("Search memories or milestones…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.7))
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GlassPanel(tier: .contentCard, cornerRadius: 10) {
            Color.clear
        })
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var filterChipsSection: some View {
        FilterChipGroup(chips: ArchiveFilter.allCases.map { filter in
            FilterChipGroup.FilterChipData(
                id: filter.rawValue,
                title: filter.rawValue,
                isSelected: selectedFilter == filter,
                action: {
                    guard selectedFilter != filter else { return }
                    withAnimation(GlassMotion.Easing.spring) {
                        selectedFilter = filter
                    }
                }
            )
        })
    }
    
    private var accentBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .kosmicBlue.opacity(0.35),
                        .kosmicPurple.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

#Preview {
    ArchivesHeaderView(
        searchText: .constant(""),
        selectedFilter: .constant(.all),
        showReviewSummary: .constant(false),
        showRestoreMenu: .constant(false)
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

