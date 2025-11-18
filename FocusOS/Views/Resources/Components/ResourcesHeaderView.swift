//
//  ResourcesHeaderView.swift
//  FocusOS
//
//  Resources V2 - Unified Header Zone
//

import SwiftUI
import AppKit
import FocusOSShared

enum ResourceFilter: String, CaseIterable {
    case all = "All"
    case documents = "Documents"
    case media = "Media"
    case templates = "Templates"
    case articles = "Articles"
    case archived = "Archived"
}

struct ResourcesHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedFilter: ResourceFilter
    let currentSortOption: ResourceSortOption
    @Binding var isFilterSortDrawerVisible: Bool
    let onSortChange: (ResourceSortOption) -> Void
    let onQuickAdd: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 16) {
            // Title and Subline
            VStack(alignment: .leading, spacing: 4) {
                Text("Resources")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Your library of saved knowledge and media")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search by title, type, or tag…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(glassColorSystem.cardColor())
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                    )
            )
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ResourceFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            action: {
                                if reduceMotion {
                                    selectedFilter = filter
                                } else {
                                    withAnimation(GlassMotion.Easing.spring) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
            
            HStack {
                // Most common sorts (3 max)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Sort")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 10) {
                        quickSortButton(.updatedAtDesc)
                        quickSortButton(.titleAsc)
                        quickSortButton(.typeNote)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                        isFilterSortDrawerVisible = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                        Text("All Options")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                    }
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(glassColorSystem.cardColor().opacity(0.4))
                            .overlay(
                                Capsule()
                                    .stroke(glassColorSystem.borderColor().opacity(0.5), lineWidth: 0.8)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Quick Add Button
            HStack {
                Spacer()
                GlassButton(
                    nil,
                    icon: "plus",
                    style: .iconOnly,
                    role: .primary,
                    action: onQuickAdd
                )
                .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            GlassPanel(tier: .overlay, cornerRadius: 0) {
                LinearGradient(
                    colors: [Color.kosmicBlue.opacity(0.1), Color.kosmicPurple.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
    }
    
    @ViewBuilder
    private func quickSortButton(_ sort: ResourceSortOption) -> some View {
        Button {
            onSortChange(sort)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sort.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(sort.displayName)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(currentSortOption == sort ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(currentSortOption == sort ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(currentSortOption == sort ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.3), lineWidth: currentSortOption == sort ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func sortCategoryMenu(for category: ResourceSortCategory) -> some View {
        let options = ResourceSortOption.options(for: category)
        let currentOptionInCategory = options.first { $0 == currentSortOption }
        let isActive = currentOptionInCategory != nil
        
        Menu {
            ForEach(options) { option in
                Button {
                    onSortChange(option)
                } label: {
                    HStack {
                        Text(option.displayName)
                        Spacer()
                        if currentSortOption == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                
                if let current = currentOptionInCategory {
                    Text(current.displayName)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(1)
                } else {
                    Text(category.rawValue)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? glassColorSystem.cardColor().opacity(0.5) : glassColorSystem.backgroundSecondary().opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isActive ? glassColorSystem.emotionalAccent().opacity(0.4) : glassColorSystem.borderColor().opacity(0.55), lineWidth: isActive ? 1.0 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ResourcesHeaderView(
        searchText: .constant(""),
        selectedFilter: .constant(.all),
        currentSortOption: .updatedAtDesc,
        isFilterSortDrawerVisible: .constant(false),
        onSortChange: { _ in },
        onQuickAdd: {}
    )
    .environmentObject(GlassColorSystem())
    .padding()
}

