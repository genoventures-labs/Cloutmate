//
//  TasksView.swift
//  CloutmateMenuBar
//
//  Menu Bar Tasks View - Quick Task Management
//

import SwiftUI
import SwiftData
import CloutmateShared

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloutmateShared.Draft.updatedAt, order: .reverse) private var drafts: [CloutmateShared.Draft]
    
    @State private var newCaption = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Quick Add Draft
                HStack {
                    TextField("Add draft...", text: $newCaption)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    
                    Button(action: addDraft) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(newCaption.isEmpty)
                }
                .padding(.horizontal)
                
                if !drafts.isEmpty {
                    Text("Recent Drafts")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(drafts.prefix(10)) { draft in
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text(draft.caption.isEmpty ? "(No caption)" : draft.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(draft.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private func addDraft() {
        guard !newCaption.isEmpty else { return }
        let draft = CloutmateShared.Draft(caption: newCaption)
        modelContext.insert(draft)
        do {
            try modelContext.save()
            newCaption = ""
        } catch {
            print("Failed to save draft: \(error)")
        }
    }
}

#Preview {
    TasksView()
        .modelContainer(for: [CloutmateShared.Draft.self])
}


