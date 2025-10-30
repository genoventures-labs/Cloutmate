//
//  NotionIntegrationSection.swift
//  Cloutmate
//
//  Settings section for Notion integration
//

import SwiftUI
import SwiftData
import AuthenticationServices
import os.log

struct NotionIntegrationSection: View {
    @Query private var syncConfigs: [NotionSyncConfig]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var showDatabaseSelector = false
    @State private var accessToken: String?
    @State private var showRemoveConfirmation = false
    @State private var configToRemove: NotionSyncConfig?
    
    var connectedDatabases: [NotionSyncConfig] {
        syncConfigs.filter { $0.isActive }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isConnected {
                // Connect button
                Button(action: connectToNotion) {
                    HStack {
                        Image(systemName: "link.badge.plus")
                            .foregroundColor(.blue)
                        Text(isConnecting ? "Connecting..." : "Connect Notion")
                        Spacer()
                        if isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isConnecting)
                
                Text("Import your projects, tasks, and notes from Notion")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Connected state
                VStack(alignment: .leading, spacing: 12) {
                    // Status and disconnect
                    HStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to Notion")
                                .font(.subheadline)
                        }
                        Spacer()
                        Button("Disconnect") {
                            disconnectFromNotion()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Add database button
                    Button(action: {
                        showDatabaseSelector = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                            Text("Import Database")
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Active databases
                    if !connectedDatabases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Imported Databases (\(connectedDatabases.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            
                            ForEach(connectedDatabases) { config in
                                DatabaseSyncStatusRow(config: config) {
                                    configToRemove = config
                                    showRemoveConfirmation = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDatabaseSelector) {
            if let token = accessToken {
                NotionDatabaseSelectorView(accessToken: token)
            }
        }
        .alert("Remove Database", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let config = configToRemove {
                    modelContext.delete(config)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Are you sure you want to remove this database import?")
        }
        .onAppear {
            checkConnectionStatus()
        }
    }
    
    private func connectToNotion() {
        isConnecting = true
        
        // Start OAuth flow
        _Concurrency.Task {
            do {
                // Get OAuth URL
                guard let oauthURL = NotionService.shared.getOAuthURL() else {
                    Logger.notion.error("Failed to generate OAuth URL")
                    await MainActor.run {
                        isConnecting = false
                    }
                    return
                }
                
                // Use ASWebAuthenticationSession
                let callbackURL = try await ASWebAuthenticationSession.start(
                    url: oauthURL,
                    callbackURLScheme: "cloutmate"
                )
                
                // Parse the callback URL
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    await MainActor.run {
                        isConnecting = false
                    }
                    return
                }
                
                // Extract code and state
                guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                      let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                    await MainActor.run {
                        isConnecting = false
                    }
                    return
                }
                
                // Verify the state contains "notion"
                guard state.hasPrefix("notion:") else {
                    Logger.notion.error("Invalid state parameter: \(state)")
                    await MainActor.run {
                        isConnecting = false
                    }
                    return
                }
                
                // Exchange code for token
                let tokenResponse = try await NotionService.shared.exchangeCodeForToken(code)
                
                // Store token in keychain
                try KeychainService.shared.storeToken(tokenResponse.accessToken, forAccount: "notion_access_token")
                
                // Also store workspace info if needed
                await MainActor.run {
                    accessToken = tokenResponse.accessToken
                    isConnected = true
                    isConnecting = false
                }
                
                Logger.notion.info("Notion OAuth completed successfully")
                
            } catch {
                Logger.notion.error("Notion OAuth failed: \(error.localizedDescription)")
                await MainActor.run {
                    isConnecting = false
                }
            }
        }
    }
    
    private func disconnectFromNotion() {
        isConnected = false
        accessToken = nil
        
        // Delete all sync configs
        for config in syncConfigs {
            modelContext.delete(config)
        }
        
        try? modelContext.save()
    }
    
    private func checkConnectionStatus() {
        // Check if there's a valid token in keychain
        do {
            let token = try KeychainService.shared.getToken(forAccount: "notion_access_token")
            accessToken = token
            isConnected = true
        } catch {
            isConnected = false
        }
        
        // Also check if there are any active sync configs
        if !connectedDatabases.isEmpty {
            isConnected = true
        }
    }
}

struct DatabaseSyncStatusRow: View {
    let config: NotionSyncConfig
    let onRemove: () -> Void
    @State private var isActive: Bool
    
    init(config: NotionSyncConfig, onRemove: @escaping () -> Void) {
        self.config = config
        self.onRemove = onRemove
        self._isActive = State(initialValue: config.isActive)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "externaldrive")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(config.databaseTitle ?? "Database")
                    .font(.subheadline)
                Text(config.cloutmateType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let lastSynced = config.lastSyncedAt {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Synced")
                        .font(.caption)
                    Text(lastSynced, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Button(action: {
                isActive.toggle()
                config.isActive = isActive
            }) {
                Image(systemName: isActive ? "pause.circle" : "play.circle")
                    .foregroundColor(isActive ? .orange : .green)
            }
            .buttonStyle(.plain)
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct NotionOAuthView: View {
    @Binding var accessToken: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Notion OAuth")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Opening browser to authenticate...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ProgressView()
                    .padding()
            }
            .frame(minWidth: 400, minHeight: 200)
            .navigationTitle("Connect Notion")
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

