//
//  DraftsHeaderView.swift
//  Cloutmate
//
//  Unified header zone for Drafts V2 redesign
//

import SwiftUI

enum DraftsFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unfinished = "Unfinished"
    case aiGenerated = "AI-Generated"
    case userCreated = "User-Created"
    case archived = "Archived"
    
    var id: String { rawValue }
}

struct DraftsHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedFilter: DraftsFilter
    @Binding var isShowingQuickCreate: Bool
    
    var activeDraftCount: Int
    var aiDraftCount: Int
    var archivedCount: Int
    var onFilterChanged: ((DraftsFilter) -> Void)?
    var onSearchSubmitted: (() -> Void)?
    
    @State private var hasAppeared = false
    @FocusState private var isSearchFocused: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var sublineText: String {
        "Ideas in progress • Synced with AI Assistant"
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
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedFilter)
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
    
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drafts")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(titleGradient)
                
                HStack(spacing: 8) {
                    Text(sublineText)
                        .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    Spacer(minLength: 0)
                    
                    tagPill(
                        title: "\(activeDraftCount) active",
                        icon: "sparkles",
                        color: .kosmicBlue.opacity(0.15),
                        textColor: .kosmicBlue
                    )
                    
                    tagPill(
                        title: "\(aiDraftCount) AI",
                        icon: "wand.and.stars",
                        color: .kosmicPurple.opacity(0.12),
                        textColor: .kosmicPurple
                    )
                    
                    if archivedCount > 0 {
                        tagPill(
                            title: "\(archivedCount) archived",
                            icon: "archivebox",
                            color: Color.secondary.opacity(0.1),
                            textColor: .secondary
                        )
                    }
                }
            }
            
            Spacer()
            
            GlassButton(
                icon: "plus",
                style: .iconOnly,
                role: .primary
            ) {
                isShowingQuickCreate = true
            }
            .accessibilityLabel("Create new draft")
            .applyIf(!reduceMotion) { view in
                view.glassHoverEffect()
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)
            
            TextField("Search drafts by title or tags…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .focused($isSearchFocused)
                .onSubmit {
                    onSearchSubmitted?()
                }
            
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
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var filterChipsSection: some View {
        FilterChipGroup(chips: DraftsFilter.allCases.map { filter in
            FilterChipGroup.FilterChipData(
                id: filter.rawValue,
                title: filter.rawValue,
                isSelected: selectedFilter == filter,
                action: {
                    guard selectedFilter != filter else { return }
                    selectedFilter = filter
                    onFilterChanged?(filter)
                }
            )
        })
    }
    
    private func tagPill(
        title: String,
        icon: String,
        color: Color,
        textColor: Color
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color)
        .foregroundColor(textColor)
        .cornerRadius(8)
        .transition(.opacity)
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
    DraftsHeaderView(
        searchText: .constant(""),
        selectedFilter: .constant(.all),
        isShowingQuickCreate: .constant(false),
        activeDraftCount: 8,
        aiDraftCount: 3,
        archivedCount: 5
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

