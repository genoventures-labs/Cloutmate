//
//  NotionDatabaseSelectorView.swift
//  Cloutmate
//
//  View for selecting Notion databases to import
//

import SwiftUI

struct NotionDatabaseSelectorView: View {
    @State private var databases: [NotionDatabase] = []
    @State private var selectedDatabases: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var accessToken: String
    @State private var showMappingSheet = false
    @State private var databaseToImport: NotionDatabase?
    @State private var propertyMappings: [String: String] = [:]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    init(accessToken: String) {
        self._accessToken = State(initialValue: accessToken)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "externaldrive")
                            .font(.title2)
                            .foregroundStyle(.blue.gradient)
                        Text("Select Notion Databases")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Choose which databases to import into Cloutmate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassPanel(tier: .overlay, cornerRadius: 12)
                .padding()
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            loadDatabases()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Database list
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(databases, id: \.id) { database in
                                DatabaseCard(
                                    database: database,
                                    isSelected: selectedDatabases.contains(database.id),
                                    onToggle: {
                                        if selectedDatabases.contains(database.id) {
                                            selectedDatabases.remove(database.id)
                                        } else {
                                            selectedDatabases.insert(database.id)
                                        }
                                    },
                                    onImport: {
                                        importDatabase(database)
                                    }
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
                        
                        if !selectedDatabases.isEmpty {
                            Button("Import Selected (\(selectedDatabases.count))") {
                                importSelectedDatabases()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.clear)
            .navigationTitle("Notion Import")
        }
        .onAppear {
            loadDatabases()
        }
        .sheet(isPresented: $showMappingSheet) {
            if let database = databaseToImport {
                NotionMappingSheet(
                    databaseId: database.id,
                    cloutmateType: detectCloutmateType(database),
                    notionProperties: getPropertiesAsDict(database.properties ?? [:]),
                    propertyMappings: $propertyMappings
                )
            }
        }
    }
    
    private func loadDatabases() {
        isLoading = true
        errorMessage = nil
        
        _Concurrency.Task {
            do {
                let response = try await NotionService.shared.searchDatabases(accessToken: accessToken)
                await MainActor.run {
                    databases = response.results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func importDatabase(_ database: NotionDatabase) {
        databaseToImport = database
        propertyMappings = [:]
        showMappingSheet = true
    }
    
    private func importSelectedDatabases() {
        // Import logic would go here
        // For now, just dismiss
        dismiss()
    }
    
    private func detectCloutmateType(_ database: NotionDatabase) -> String {
        let title = database.title?.first?.plainText ?? ""
        let lowercased = title.lowercased()
        
        if lowercased.contains("project") || lowercased.contains("proj") {
            return "Project"
        } else if lowercased.contains("task") || lowercased.contains("todo") {
            return "Task"
        } else if lowercased.contains("note") || lowercased.contains("resource") {
            return "Note"
        } else if lowercased.contains("area") || lowercased.contains("arena") {
            return "Area"
        }
        
        return "Task" // Default
    }
    
    private func getPropertiesAsDict(_ properties: [String: NotionProperty]) -> [String: Any] {
        // Convert NotionProperty dictionary to simple dictionary for the mapping sheet
        var dict: [String: Any] = [:]
        for (key, property) in properties {
            dict[key] = [
                "type": property.type,
                "name": property.name ?? key
            ]
        }
        return dict
    }
}

struct DatabaseCard: View {
    let database: NotionDatabase
    let isSelected: Bool
    let onToggle: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selector
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            // Database info
            VStack(alignment: .leading, spacing: 4) {
                Text(database.title?.first?.plainText ?? "Untitled Database")
                    .font(.headline)
                
                Text("Database ID: \(database.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            Button("Configure") {
                onImport()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .glassPanel(tier: isSelected ? .overlay : .contentCard, cornerRadius: 8)
    }
}

