//
//  CollapsibleSidebarSection.swift
//  Cloutmate
//
//  Reusable collapsible sidebar section with state persistence
//

import SwiftUI

struct CollapsibleSidebarSection: View {
    let title: String
    let icon: String
    let tabs: [TabIdentifier]
    @Binding var selectedTab: TabIdentifier
    @State private var isExpanded: Bool
    
    init(title: String, icon: String, tabs: [TabIdentifier], selectedTab: Binding<TabIdentifier>, isExpanded: Bool = true) {
        self.title = title
        self.icon = icon
        self.tabs = tabs
        self._selectedTab = selectedTab
        self._isExpanded = State(initialValue: isExpanded)
    }
    
    private var badgeCount: Int? {
        // Could show counts for active items, inbox, etc.
        nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.blue.gradient)
                        .font(.system(size: 16))
                        .frame(width: 20)
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let count = badgeCount {
                        Text("\(count)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Section content
            if isExpanded {
                ForEach(tabs, id: \.self) { tab in
                    GlassSidebarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isHovered: false,
                        onSelect: { selectedTab = tab },
                        onHover: { _ in }
                    )
                    .padding(.leading, 12)
                }
            }
        }
    }
}

#Preview {
    CollapsibleSidebarSection(
        title: "ORGANIZE",
        icon: "folder.fill",
        tabs: [.projects, .areas, .resources],
        selectedTab: .constant(.projects),
        isExpanded: true
    )
    .padding()
}

