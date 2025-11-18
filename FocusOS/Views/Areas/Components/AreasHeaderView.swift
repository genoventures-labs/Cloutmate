//
//  AreasHeaderView.swift
//  FocusOS
//
//  Areas V2 - Header component with filters, search, and quick add
//

import SwiftUI
import FocusOSShared

enum AreaFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case reviewNeeded = "Review Needed"
    case archived = "Archived"
}

struct AreasHeaderView: View {
    let selectedFilter: AreaFilter
    let searchText: Binding<String>
    let onFilterChange: (AreaFilter) -> Void
    let onQuickAdd: () -> Void
    let sidebarCollapsed: Bool
    let onToggleSidebar: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 12) {
            // Title and subline
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Areas")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    Text("Your ongoing domains of focus")
                        .font(.caption)
                        .foregroundColor(.kosmicPurple.opacity(0.7))
                }
                
                Spacer()
                
                // Sidebar toggle button
                Button(action: onToggleSidebar) {
                    Image(systemName: sidebarCollapsed ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(glassColorSystem.textSecondary())
                        .frame(width: 32, height: 32)
                        .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(sidebarCollapsed ? "Show Sidebar" : "Hide Sidebar")
                
                // Quick Add button
                GlassButton(
                    icon: "plus",
                    style: .iconOnly,
                    role: .primary,
                    tintColor: .kosmicBlue,
                    action: onQuickAdd
                )
                .frame(width: 32, height: 32)
            }
            
            // Filter chips and search
            HStack(spacing: 12) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AreaFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: { onFilterChange(filter) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer()
                
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(glassColorSystem.textSecondary())
                    
                    TextField("Search by name or tag…", text: searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                .foregroundColor(glassColorSystem.textPrimary())
                .cornerRadius(8)
                .frame(maxWidth: 300)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            GlassPanel(tier: .overlay, cornerRadius: 0) {
                EmptyView()
            }
            .ignoresSafeArea(edges: .top)
        )
    }
}

#Preview {
    AreasHeaderView(
        selectedFilter: .all,
        searchText: .constant(""),
        onFilterChange: { _ in },
        onQuickAdd: {},
        sidebarCollapsed: false,
        onToggleSidebar: {}
    )
    .padding()
    .background(Color(.windowBackgroundColor))
    .environmentObject(GlassColorSystem())
}

