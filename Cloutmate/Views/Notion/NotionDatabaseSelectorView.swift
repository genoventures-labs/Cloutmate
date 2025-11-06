//
//  NotionDatabaseSelectorView.swift
//  Cloutmate
//
//  View for selecting Notion databases to import
//

import SwiftUI
import os.log

struct NotionDatabaseSelectorView: View {
    @State private var databases: [NotionDatabase] = []
    @State private var selectedDatabases: Set<String> = []
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var accessToken: String
    @State private var showMappingSheet = false
    @State private var databaseToImport: NotionDatabase?
    @State private var propertyMappings: [String: String] = [:]
    @State private var importProgress: String?
    
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
                            .foregroundStyle(Color.kosmicBlue)
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
                
                if isLoading || isImporting {
                    VStack(spacing: 16) {
                        ProgressView()
                        if let progress = importProgress {
                            Text(progress)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
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
                    propertyMappings: $propertyMappings,
                    onImport: {
                        performImport(for: database, mappings: propertyMappings)
                    }
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
                    Logger.notion.info("Loaded \(response.results.count) Notion databases")
                }
            } catch NotionAPIError.tokenExpired {
                await MainActor.run {
                    errorMessage = "Your Notion connection has expired. Please reconnect."
                    isLoading = false
                }
                Logger.notion.error("Notion token expired while loading databases")
            } catch NotionAPIError.networkError(let error) {
                await MainActor.run {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    isLoading = false
                }
                Logger.notion.error("Network error loading databases: \(error.localizedDescription)")
            } catch NotionAPIError.apiError(let detail) {
                await MainActor.run {
                    errorMessage = "Notion API error: \(detail.message)"
                    isLoading = false
                }
                Logger.notion.error("Notion API error loading databases: \(detail.message)")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load databases: \(error.localizedDescription)"
                    isLoading = false
                }
                Logger.notion.error("Error loading databases: \(error.localizedDescription)")
            }
        }
    }
    
    private func importDatabase(_ database: NotionDatabase) {
        databaseToImport = database
        propertyMappings = [:]
        showMappingSheet = true
    }
    
    private func performImport(for database: NotionDatabase, mappings: [String: String]) {
        isImporting = true
        importProgress = "Importing \(extractDatabaseTitle(from: database))..."
        errorMessage = nil
        
        _Concurrency.Task {
            do {
                let cloutmateType = detectCloutmateType(database)
                
                try await NotionSyncService.shared.importDatabase(
                    databaseId: database.id,
                    cloutmateType: cloutmateType,
                    propertyMappings: mappings,
                    accessToken: accessToken,
                    context: modelContext
                )
                
                await MainActor.run {
                    isImporting = false
                    importProgress = nil
                    dismiss()
                }
                
                Logger.notion.info("Successfully imported database: \(database.id)")
            } catch {
                await MainActor.run {
                    isImporting = false
                    importProgress = nil
                    errorMessage = "Failed to import database: \(error.localizedDescription)"
                }
                Logger.notion.error("Import failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func importSelectedDatabases() {
        guard !selectedDatabases.isEmpty else { return }
        
        isImporting = true
        importProgress = "Preparing import..."
        errorMessage = nil
        
        _Concurrency.Task {
            var successCount = 0
            var failureCount = 0
            
            for databaseId in selectedDatabases {
                guard let database = databases.first(where: { $0.id == databaseId }) else {
                    failureCount += 1
                    continue
                }
                
                await MainActor.run {
                    importProgress = "Importing \(extractDatabaseTitle(from: database))..."
                }
                
                do {
                    let cloutmateType = detectCloutmateType(database)
                    
                    // Fetch full database structure to get properties
                    let fullDatabase = try await NotionService.shared.getDatabase(
                        databaseId: databaseId,
                        accessToken: accessToken
                    )
                    
                    // Generate smart mappings
                    let mappings = generateSmartMappings(for: fullDatabase.properties, cloutmateType: cloutmateType)
                    
                    // Perform import
                    try await NotionSyncService.shared.importDatabase(
                        databaseId: databaseId,
                        cloutmateType: cloutmateType,
                        propertyMappings: mappings,
                        accessToken: accessToken,
                        context: modelContext
                    )
                    
                    successCount += 1
                    Logger.notion.info("Successfully imported database: \(databaseId)")
                } catch {
                    failureCount += 1
                    Logger.notion.error("Failed to import database \(databaseId): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isImporting = false
                importProgress = nil
                
                if failureCount == 0 {
                    // All imports successful
                    dismiss()
                } else if successCount > 0 {
                    // Partial success
                    errorMessage = "Imported \(successCount) database(s). \(failureCount) failed."
                } else {
                    // All failed
                    errorMessage = "Failed to import databases. Please try again."
                }
            }
        }
    }
    
    private func generateSmartMappings(for properties: [String: NotionProperty], cloutmateType: String) -> [String: String] {
        var mappings: [String: String] = [:]
        
        for (notionProperty, property) in properties {
            let lowercased = property.name?.lowercased() ?? notionProperty.lowercased()
            
            // Smart matching based on property name
            if lowercased.contains("name") || lowercased.contains("title") {
                mappings[notionProperty] = "title"
            } else if lowercased.contains("status") {
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
    
    private func detectCloutmateType(_ database: NotionDatabase) -> String {
        let title = extractDatabaseTitle(from: database)
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
    
    private func extractDatabaseTitle(from database: NotionDatabase) -> String {
        // Try to extract title from NotionRichText array
        if let titleArray = database.title, !titleArray.isEmpty {
            let titleText = titleArray.compactMap { $0.plainText }.joined()
            if !titleText.isEmpty {
                Logger.notion.debug("Extracted database title: \(titleText)")
                return titleText
            }
        }
        
        // Fallback to URL if available
        if let url = database.url, !url.isEmpty {
            Logger.notion.debug("Using database URL as fallback: \(url)")
            return url
        }
        
        // Final fallback to truncated ID
        let truncatedId = String(database.id.prefix(8))
        Logger.notion.debug("Using database ID as fallback: \(truncatedId)")
        return "Database \(truncatedId)"
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
    
    private func extractDatabaseTitle(from database: NotionDatabase) -> String {
        // Try to extract title from NotionRichText array
        if let titleArray = database.title, !titleArray.isEmpty {
            let titleText = titleArray.compactMap { $0.plainText }.joined()
            if !titleText.isEmpty {
                return titleText
            }
        }
        
        // Fallback to URL if available
        if let url = database.url, !url.isEmpty {
            return url
        }
        
        // Final fallback to truncated ID
        let truncatedId = String(database.id.prefix(8))
        return "Database \(truncatedId)"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Selector
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.kosmicBlue : .secondary)
            }
            .buttonStyle(.plain)
            
            // Database info
            VStack(alignment: .leading, spacing: 4) {
                Text(extractDatabaseTitle(from: database))
                    .font(.headline)
                
                if let description = database.description, !description.isEmpty {
                    let descText = description.compactMap { $0.plainText }.joined()
                    if !descText.isEmpty {
                        Text(descText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Text("Database ID: \(database.id)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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

