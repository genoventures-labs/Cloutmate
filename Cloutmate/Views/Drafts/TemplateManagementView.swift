//
//  TemplateManagementView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct TemplateManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.name) private var templates: [Template]
    
    @State private var selectedTemplate: Template?
    @State private var isCreatingNew = false
    @State private var newTemplateName = ""
    @State private var newTemplateCaption = ""
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTemplate) {
                ForEach(templates) { template in
                    NavigationLink(value: template) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                            Text(template.caption)
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
            .navigationTitle("Templates")
            .frame(minWidth: 300, idealWidth: 350)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        isCreatingNew = true
                    }) {
                        Label("New Template", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isCreatingNew) {
                CreateTemplateSheet(isPresented: $isCreatingNew)
            }
        } detail: {
            if let template = selectedTemplate {
                TemplateEditorView(template: template)
            } else {
                ContentUnavailableView(
                    "No Template Selected",
                    systemImage: "doc.text.fill",
                    description: Text("Select a template to edit or create a new one")
                )
            }
        }
    }
    
    private func deleteTemplates(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(templates[index])
            }
        }
    }
}

struct CreateTemplateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var caption = ""
    @State private var tags: [String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("Template Name", text: $name)
                }
                
                Section("Content") {
                    TextEditor(text: $caption)
                        .frame(minHeight: 100)
                }
                
                Section("Tags") {
                    TagsView(tags: $tags)
                }
            }
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTemplate()
                    }
                    .disabled(name.isEmpty || caption.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func createTemplate() {
        let template = Template(
            name: name,
            caption: caption,
            tags: tags
        )
        modelContext.insert(template)
        isPresented = false
    }
}

struct TemplateEditorView: View {
    @Bindable var template: Template
    
    var body: some View {
        Form {
            Section("Template Name") {
                TextField("Name", text: $template.name)
            }
            
            Section("Content") {
                TextEditor(text: $template.caption)
                    .frame(minHeight: 100)
            }
            
            Section("Tags") {
                TagsView(tags: $template.tags)
            }
        }
        .navigationTitle(template.name)
    }
}

#Preview {
    TemplateManagementView()
        .modelContainer(for: [Template.self])
}

