//
//  NotionMappingSheet.swift
//  Cloutmate
//
//  Sheet for mapping Notion properties to Cloutmate fields
//

import SwiftUI

struct NotionPropertyMapping {
    let notionPropertyName: String
    let notionPropertyType: String
    var mappedCloutmateField: String?
}

struct NotionMappingSheet: View {
    let databaseId: String
    let cloutmateType: String // "Project", "Task", "Note", "Area"
    let notionProperties: [String: Any] // Notion database properties
    @Binding var propertyMappings: [String: String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var localMappings: [String: String] = [:]
    @State private var showPreview = false
    @State private var previewData: [String: String] = [:]
    
    var availableCloutmateFields: [String] {
        switch cloutmateType {
        case "Project":
            return ["title", "goal", "statusRaw", "dueDate", "tags", "areaId"]
        case "Task":
            return ["title", "notes", "statusRaw", "priorityRaw", "dueDate", "projectId", "effort", "areaId", "tags"]
        case "Note":
            return ["title", "markdown", "tags", "projectId", "areaId", "source", "type"]
        case "Area":
            return ["title", "notes", "cadenceSetting", "tags"]
        default:
            return []
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.title2)
                            .foregroundStyle(Color.kosmicBlue)
                        Text("Map Properties")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Match your Notion database properties to Cloutmate fields")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassPanel(tier: .overlay, cornerRadius: 12)
                
                // Mapping list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(notionProperties.keys).sorted(), id: \.self) { notionProperty in
                            PropertyMappingRow(
                                notionPropertyName: notionProperty,
                                notionPropertyType: getPropertyType(notionProperty),
                                availableFields: availableCloutmateFields,
                                selectedField: Binding(
                                    get: { localMappings[notionProperty] },
                                    set: { localMappings[notionProperty] = $0 }
                                )
                            )
                        }
                    }
                    .padding()
                }
                
                // Actions
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        showPreview = true
                    }) {
                        Label("Preview", systemImage: "eye")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import") {
                        propertyMappings = localMappings
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .frame(minWidth: 600, minHeight: 500)
            .background(Color.clear)
        }
        .sheet(isPresented: $showPreview) {
            MappingPreviewSheet(
                mappings: localMappings,
                notionProperties: notionProperties,
                cloutmateType: cloutmateType
            )
        }
        .onAppear {
            // Initialize with smart matching
            localMappings = generateSmartMappings()
        }
    }
    
    private func getPropertyType(_ propertyName: String) -> String {
        // This would parse the actual Notion property type
        // For now, return a placeholder
        return "text"
    }
    
    private func generateSmartMappings() -> [String: String] {
        var mappings: [String: String] = [:]
        
        for (notionProperty, _) in notionProperties {
            let lowercased = notionProperty.lowercased()
            
            // Smart matching based on property name
            if lowercased.contains("name") || lowercased.contains("title") {
                mappings[notionProperty] = "title"
            } else if lowercased.contains("status") && cloutmateType == "Project" {
                mappings[notionProperty] = "statusRaw"
            } else if lowercased.contains("status") && cloutmateType == "Task" {
                mappings[notionProperty] = "statusRaw"
            } else if lowercased.contains("priority") {
                mappings[notionProperty] = "priorityRaw"
            } else if lowercased.contains("due") || lowercased.contains("deadline") {
                mappings[notionProperty] = "dueDate"
            } else if lowercased.contains("goal") && cloutmateType == "Project" {
                mappings[notionProperty] = "goal"
            } else if lowercased.contains("note") || lowercased.contains("description") {
                if cloutmateType == "Task" {
                    mappings[notionProperty] = "notes"
                } else if cloutmateType == "Note" {
                    mappings[notionProperty] = "markdown"
                }
            } else if lowercased.contains("tag") {
                mappings[notionProperty] = "tags"
            } else if lowercased.contains("project") && cloutmateType == "Task" {
                mappings[notionProperty] = "projectId"
            } else if lowercased.contains("area") {
                mappings[notionProperty] = "areaId"
            } else if lowercased.contains("effort") && cloutmateType == "Task" {
                mappings[notionProperty] = "effort"
            }
        }
        
        return mappings
    }
}

struct PropertyMappingRow: View {
    let notionPropertyName: String
    let notionPropertyType: String
    let availableFields: [String]
    @Binding var selectedField: String?
    
    var body: some View {
        HStack(spacing: 16) {
            // Notion property
            VStack(alignment: .leading, spacing: 4) {
                Text(notionPropertyName)
                    .font(.headline)
                Text(notionPropertyType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            
            // Cloutmate field selector
            Picker("Map to", selection: $selectedField) {
                Text("Don't import").tag(String?.none)
                ForEach(availableFields, id: \.self) { field in
                    Text(getFieldDisplayName(field)).tag(String?.some(field))
                }
            }
            .frame(maxWidth: .infinity)
            .labelsHidden()
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 8)
    }
    
    private func getFieldDisplayName(_ field: String) -> String {
        switch field {
        case "statusRaw": return "Status"
        case "priorityRaw": return "Priority"
        case "dueDate": return "Due Date"
        case "areaId": return "Area"
        case "projectId": return "Project"
        default:
            return field.capitalized
        }
    }
}

struct MappingPreviewSheet: View {
    let mappings: [String: String]
    let notionProperties: [String: Any]
    let cloutmateType: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Preview Your Import")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("These fields will be imported with the following mappings:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(mappings.keys.sorted()), id: \.self) { notionProp in
                        if let cloutmateField = mappings[notionProp] {
                            HStack {
                                Text(notionProp)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Text(cloutmateField)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .glassPanel(tier: .contentCard, cornerRadius: 8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Preview")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

