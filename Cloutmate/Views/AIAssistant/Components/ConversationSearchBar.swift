//
//  ConversationSearchBar.swift
//  Cloutmate
//
//  Search and Filter Bar for AI Conversations
//

import SwiftUI

struct ConversationSearchBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: DateFilter
    @Binding var selectedTags: Set<String>
    
    var allTags: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            // Search TextField
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            // Date Filter Menu
            Menu {
                ForEach(DateFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Label(filter.rawValue, systemImage: selectedFilter == filter ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(selectedFilter.rawValue)
                        .font(.caption)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Tag Filter
            if !allTags.isEmpty {
                Menu {
                    ForEach(allTags.sorted(), id: \.self) { tag in
                        Button(action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }) {
                            Label(tag, systemImage: selectedTags.contains(tag) ? "checkmark" : "")
                        }
                    }
                    
                    if !selectedTags.isEmpty {
                        Divider()
                        Button("Clear All") {
                            selectedTags.removeAll()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "tag")
                            .font(.caption)
                        Text(selectedTags.isEmpty ? "All Tags" : "\(selectedTags.count) tags")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    ConversationSearchBar(
        searchText: .constant(""),
        selectedFilter: .constant(.all),
        selectedTags: .constant([]),
        allTags: ["Content Strategy", "Copywriting", "Engagement"]
    )
    .frame(width: 280)
    .padding()
}
