//
//  FocusGravityView.swift
//  Cloutmate
//
//  Phase 3: CPS-Driven Priority View
//  Shows the top priority items dynamically ranked by the Contextual Priority System
//

import SwiftUI
import SwiftData
import CloutmateShared

struct FocusGravityView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var priorityItems: [PriorityItem] = []
    @State private var selectedType: String = "all"
    @State private var isLoading = false
    
    let objectTypes = ["all", "task", "project", "note", "draft", "post", "inbox"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Gravity")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Dynamically ranked by the Contextual Priority System")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: refreshPriorities) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
            }
            .padding(.bottom, 8)
            
            // Type Filter
            Picker("Filter by type", selection: $selectedType) {
                Text("All Types").tag("all")
                ForEach(objectTypes.dropFirst(), id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)
            .onChange(of: selectedType) { oldValue, newValue in
                refreshPriorities()
            }
            
            // Priority List
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading priorities...")
                    Spacer()
                }
                .padding()
            } else if priorityItems.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(priorityItems) { item in
                            PriorityItemCard(item: item)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .task {
            refreshPriorities()
        }
    }
    
    private func refreshPriorities() {
        isLoading = true
        
        if selectedType == "all" {
            priorityItems = PriorityEngine.shared.getTopObjects(limit: 20, modelContext: modelContext)
        } else {
            priorityItems = PriorityEngine.shared.getTopObjects(ofType: selectedType, limit: 20, modelContext: modelContext)
        }
        
        isLoading = false
    }
}

// MARK: - Priority Item Card

private struct PriorityItemCard: View {
    let item: PriorityItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority Score Indicator
            VStack {
                ZStack {
                    Circle()
                        .fill(scoreColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Text(String(format: "%.0f", item.score * 100))
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                }
                
                Text(item.objectType)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                // TODO: Navigate to item
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(scoreColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var scoreColor: Color {
        if item.score > 0.7 {
            return .red
        } else if item.score > 0.5 {
            return .orange
        } else if item.score > 0.3 {
            return .yellow
        } else {
            return .kosmicBlue
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Priority Items Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Priority scores are calculated as you work. Start creating tasks, projects, notes, or drafts to see them ranked here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    FocusGravityView()
        .modelContainer(for: [PriorityScore.self, CloutmateShared.Task.self, CloutmateShared.Project.self], inMemory: true)
}

