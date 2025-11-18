//
//  TemplateLibraryView.swift
//  FocusOS
//
//  Template Library for PARA system
//

import SwiftUI
import SwiftData

struct TemplateLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PARATemplate.typeRaw) private var allTemplates: [PARATemplate]
    
    @State private var selectedTemplate: PARATemplate?
    @State private var selectedCategory: String = "All"
    @State private var searchText = ""
    @State private var showingCreateSheet = false
    
    private let categories = ["All", "Starter", "Custom", "Business"]
    
    var filteredTemplates: [PARATemplate] {
        var templates = allTemplates
        
        // Filter by category
        if selectedCategory != "All" {
            templates = templates.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.title.localizedCaseInsensitiveContains(searchText) ||
                template.templateDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return templates
    }
    
    var templatesByType: [TemplateType: [PARATemplate]] {
        Dictionary(grouping: filteredTemplates) { $0.type }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Template Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    GlassButton("New Template", icon: "plus.circle", tintColor: .kosmicBlue, action: { showingCreateSheet = true })
                }
                .padding()
                
                // Search and filter
                HStack(spacing: 12) {
                    TextField("Search templates...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    Menu {
                        ForEach(categories, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Label(category, systemImage: selectedCategory == category ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategory)
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // Templates grouped by type
                ForEach(TemplateType.allCases, id: \.self) { type in
                    if let templates = templatesByType[type], !templates.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(Color.kosmicBlue)
                                    .font(.title3)
                                Text(type.displayName)
                                    .font(.headline)
                                Text("(\(templates.count))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(templates) { template in
                                TemplateCard(template: template)
                                    .onTapGesture {
                                        selectedTemplate = template
                                    }
                            }
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .navigationTitle("Templates")
        .sheet(item: $selectedTemplate) { template in
            TemplateDetailSheet(template: template)
        }
        .sheet(isPresented: $showingCreateSheet) {
            PARACreateTemplateSheet()
        }
    }
}

struct TemplateCard: View {
    let template: PARATemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: template.type.icon)
                    .foregroundStyle(Color.kosmicBlue)
                    .font(.title3)
                Text(template.title)
                    .font(.headline)
                Spacer()
                if template.isBuiltIn {
                    Label("Built-in", systemImage: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.kosmicBlue)
                }
            }
            
            if !template.templateDescription.isEmpty {
                Text(template.templateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            if template.usageCount > 0 {
                Text("Used \(template.usageCount) times")
                    .font(.caption2)
                    .foregroundStyle(Color.kosmicBlue)
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .padding(.horizontal)
    }
}

struct TemplateDetailSheet: View {
    let template: PARATemplate
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: template.type.icon)
                            .foregroundStyle(Color.kosmicBlue)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(template.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .glassPanel(tier: .overlay, cornerRadius: 12)
                    
                    // Description
                    if !template.templateDescription.isEmpty {
                        Text(template.templateDescription)
                            .font(.body)
                            .padding()
                            .glassPanel(tier: .contentCard, cornerRadius: 12)
                    }
                    
                    // Content preview
                    Text("Preview:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(template.content)
                        .font(.body)
                        .monospaced()
                        .padding()
                        .glassPanel(tier: .contentCard, cornerRadius: 12)
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle("Template Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PARACreateTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var templateDescription = ""
    @State private var selectedType: TemplateType = .project
    @State private var content = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Template Title", text: $title)
                    TextField("Description", text: $templateDescription)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(TemplateType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(height: 200)
                }
            }
            .padding()
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTemplate()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func createTemplate() {
        let template = PARATemplate(
            type: selectedType,
            title: title,
            templateDescription: templateDescription,
            content: content,
            category: "Custom",
            isBuiltIn: false
        )
        modelContext.insert(template)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    TemplateLibraryView()
        .modelContainer(for: [PARATemplate.self])
}
