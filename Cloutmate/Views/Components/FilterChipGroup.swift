//
//  FilterChipGroup.swift
//  Cloutmate
//
//  Horizontal filter chip group wrapper component
//

import SwiftUI

struct FilterChipGroup: View {
    let chips: [FilterChipData]
    
    struct FilterChipData: Identifiable {
        let id: String
        let title: String
        let isSelected: Bool
        let action: () -> Void
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    FilterChip(
                        title: chip.title,
                        isSelected: chip.isSelected,
                        action: chip.action
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    FilterChipGroup(chips: [
        FilterChipGroup.FilterChipData(
            id: "all",
            title: "All",
            isSelected: true,
            action: {}
        ),
        FilterChipGroup.FilterChipData(
            id: "tagged",
            title: "Tagged",
            isSelected: false,
            action: {}
        ),
        FilterChipGroup.FilterChipData(
            id: "recent",
            title: "Recent",
            isSelected: false,
            action: {}
        )
    ])
    .padding()
}

