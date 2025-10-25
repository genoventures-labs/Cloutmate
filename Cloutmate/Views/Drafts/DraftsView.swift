//
//  DraftsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData

struct DraftsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Draft.updatedAt, order: .reverse) private var drafts: [Draft]
    @Query(sort: \Template.name) private var templates: [Template]
    
    @State private var selectedDraft: Draft?
    @State private var showTemplates = false
    
    var body: some View {
        HSplitView {
            // Drafts list
            List(selection: $selectedDraft) {
                ForEach(drafts) { draft in
                    DraftRow(draft: draft)
                        .tag(draft)
                }
                .onDelete(perform: deleteDrafts)
            }
            .frame(minWidth: 250)
            
            // Editor
            if let draft = selectedDraft {
                DraftEditor(draft: draft)
            } else {
                ContentUnavailableView(
                    "No Draft Selected",
                    systemImage: "doc.text",
                    description: Text("Select a draft to edit or create a new one")
                )
            }
        }
        .navigationTitle("Drafts & Templates")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    showTemplates = true
                }) {
                    Label("Templates", systemImage: "doc.on.doc")
                }
                
                Button(action: createNewDraft) {
                    Label("New Draft", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showTemplates) {
            TemplateManagementView()
        }
    }
    
    private func createNewDraft() {
        let newDraft = Draft()
        modelContext.insert(newDraft)
        selectedDraft = newDraft
    }
    
    private func deleteDrafts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(drafts[index])
            }
        }
    }
}

struct DraftRow: View {
    let draft: Draft
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.caption.isEmpty ? "Untitled Draft" : draft.caption)
                .lineLimit(2)
                .font(.body)
            
            Text(draft.updatedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DraftsView()
        .modelContainer(for: [Draft.self])
}

