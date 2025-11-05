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
    
    var body: some View {
        if !results.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
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
                                
                                Text(result.subtitle)
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
                    
                    if index < results.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

