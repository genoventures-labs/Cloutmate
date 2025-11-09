//
//  ResourcesHeaderView.swift
//  Cloutmate
//
//  Resources V2 - Unified Header Zone
//

import SwiftUI
import AppKit
import CloutmateShared

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
}

#Preview {
    ResourcesHeaderView(
        searchText: .constant(""),
        selectedFilter: .constant(.all),
        onQuickAdd: {}
    )
    .environmentObject(GlassColorSystem())
    .padding()
}

