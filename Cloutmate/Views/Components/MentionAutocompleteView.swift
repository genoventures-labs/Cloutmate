//
//  MentionAutocompleteView.swift
//  Cloutmate
//
//  Autocomplete dropdown for @ mention suggestions
//

import SwiftUI
import SwiftData

struct MentionAutocompleteView: View {
    let results: [WorkspaceObjectResult]
    let onSelect: (WorkspaceObjectResult) -> Void
    @Binding var selectedIndex: Int
    var tabFilter: ObjectType? = nil // Optional tab filter to show header
    @Environment(\.modelContext) private var modelContext
    @State private var collapsedSections: Set<ObjectType> = []
    
    var body: some View {
        if !results.isEmpty {
            VStack(spacing: 0) {
                // Show tab header if filtered
                if let filter = tabFilter {
                    HStack {
                        Image(systemName: filter.icon)
                            .foregroundColor(.kosmicBlue)
                            .font(.caption)
                        Text(WorkspaceObjectSearchService.shared.tabName(for: filter))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    
                    Divider()
                }
                
                // Group results by type if no tab filter
                if tabFilter == nil {
                    let grouped = Dictionary(grouping: results) { $0.type }
                    let sortedTypes = grouped.keys.sorted { $0.rawValue < $1.rawValue }
                    
                    ForEach(sortedTypes, id: \.self) { type in
                        if let typeResults = grouped[type], !typeResults.isEmpty {
                            let isCollapsed = collapsedSections.contains(type)
                            
                            Button {
                                if isCollapsed {
                                    collapsedSections.remove(type)
                                } else {
                                    collapsedSections.insert(type)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: type.icon)
                                        .foregroundColor(.kosmicBlue)
                                        .font(.caption)
                                    Text(WorkspaceObjectSearchService.shared.tabName(for: type))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                            }
                            .buttonStyle(.plain)
                            
                            if !isCollapsed {
                                Divider()
                                
                                // Items for this type
                                ForEach(Array(typeResults.enumerated()), id: \.element.id) { index, result in
                                    let globalIndex = results.firstIndex(where: { $0.id == result.id }) ?? index
                                    autocompleteItem(result: result, index: globalIndex)
                                    
                                    if globalIndex < results.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 12)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Single tab - show items directly
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        autocompleteItem(result: result, index: index)
                        
                        if index < results.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.6))
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func autocompleteItem(result: WorkspaceObjectResult, index: Int) -> some View {
                    Button(action: {
                        onSelect(result)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: result.type.icon)
                                .foregroundColor(.kosmicBlue)
                                .font(.body)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                    Text(cleanSubtitle(result.subtitle))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(result.type.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedIndex == index ? Color.kosmicBlue.opacity(0.1) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
        .id(index) // Add ID for ScrollViewReader
        .onHover { hovering in
            if hovering {
                selectedIndex = index
            }
        }
    }
    
    private func cleanSubtitle(_ subtitle: String) -> String {
        // Convert any structured mentions in subtitle to display names
        var display = MentionService.shared.convertToDisplayNames(
            text: subtitle,
            modelContext: modelContext
        )
        display = MentionParser.stripTerminators(from: display)
        
        // Remove lingering structured patterns and extra whitespace
        let structuredPattern = #"@\{[^}]+\}"#
        display = display.replacingOccurrences(of: structuredPattern, with: "", options: .regularExpression)
        display = display.replacingOccurrences(of: "  ", with: " ")
        display = display.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return display.isEmpty ? "No description available" : display
    }
}

