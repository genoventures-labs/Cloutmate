//
//  NotionImportSettingsView.swift
//  FocusOS
//
//  Settings drawer for Notion import configuration
//

import SwiftUI
import SwiftData
import os.log
import FocusOSShared
import NotionSwift

struct NotionImportSettingsView: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @ObservedObject private var importService = NotionImportService.shared
    @ObservedObject private var settings = NotionImportSettings.shared
    
    @State private var availableDatabases: [Database] = []
    @State private var selectedDatabaseIds: Set<String> = []
    @State private var syncIntervalMinutes: Double = 15
    @State private var importCompleted: Bool = false
    @State private var autoDetectTypes: Bool = true
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeDrawer()
                    }
                    .transition(.opacity)
                
                VStack(spacing: 0) {
                    V2DrawerScaffold(
                        accentGradient: accentGradient,
                        showsSidebar: false,
                        header: { headerView },
                        content: { contentView },
                        sidebar: { EmptyView() }
                    )
                }
                .frame(width: min(800, geometry.size.width * 0.85))
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .onAppear {
            loadSettings()
            _Concurrency.Task { @MainActor in
                await loadAvailableDatabases()
            }
        }
        .onKeyPress(.escape) {
            closeDrawer()
            return .handled
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notion Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Configure Notion import and sync preferences")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface
            ) {
                closeDrawer()
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 28) {
            DrawerSection(title: "Connection Status", icon: "link") {
                if settings.accessToken != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.kosmicGreen)
                        Text("Connected to Notion")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                } else {
                    Text("Not connected to Notion. Connect from the Integrations drawer.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
            }
            
            DrawerSection(title: "Import Status", icon: "power") {
                Toggle(isOn: $settings.importEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Notion Import")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Automatically sync databases and pages from selected Notion databases")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                .toggleStyle(.switch)
                .tint(.kosmicBlue)
                .disabled(settings.accessToken == nil)
                .onChange(of: settings.importEnabled) { newValue in
                    handleImportEnabledChange(newValue)
                }
            }
            
            DrawerSection(title: "Databases", icon: "folder") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which Notion databases to import")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if availableDatabases.isEmpty {
                        Text("No databases available or not connected to Notion.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(availableDatabases, id: \.id) { database in
                                    HStack {
                                        Image(systemName: "square.grid.2x2")
                                            .foregroundStyle(.kosmicBlue)
                                        
                                        Text(database.title.first?.plainText ?? "Untitled Database")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: Binding(
                                            get: { selectedDatabaseIds.contains(database.id.rawValue) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedDatabaseIds.insert(database.id.rawValue)
                                                } else {
                                                    selectedDatabaseIds.remove(database.id.rawValue)
                                                }
                                                settings.selectedDatabaseIds = Array(selectedDatabaseIds)
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .tint(.kosmicBlue)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            
            DrawerSection(title: "Sync Interval", icon: "clock") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How often to check for Notion changes")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    Picker("Sync Interval", selection: $syncIntervalMinutes) {
                        Text("15 minutes").tag(15.0)
                        Text("30 minutes").tag(30.0)
                        Text("1 hour").tag(60.0)
                        Text("Manual only").tag(0.0)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: syncIntervalMinutes) { newValue in
                        settings.syncInterval = newValue > 0 ? newValue * 60 : 0
                    }
                }
            }
            
            DrawerSection(title: "Import Options", icon: "gearshape") {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $importCompleted) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import Completed Items")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            Text("Include items that are already marked as complete")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.kosmicBlue)
                    .onChange(of: importCompleted) { newValue in
                        settings.importCompletedItems = newValue
                    }
                    
                    Toggle(isOn: $autoDetectTypes) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Detect Types")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            Text("Automatically determine if pages are Tasks, Projects, Notes, or Areas")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.kosmicBlue)
                    .onChange(of: autoDetectTypes) { newValue in
                        settings.autoDetectTypes = newValue
                    }
                }
            }
            
            if let lastSync = settings.lastSyncDate {
                DrawerSection(title: "Last Sync", icon: "clock.arrow.circlepath") {
                    Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            
            HStack(spacing: 12) {
                GlassButton("Sync Now", icon: "arrow.clockwise", role: .primary) {
                    syncNow()
                }
                .disabled(importService.isSyncing || settings.accessToken == nil)
                
                Spacer()
            }
        }
    }
    
    private func handleImportEnabledChange(_ enabled: Bool) {
        if enabled {
            _Concurrency.Task { @MainActor in
                await importService.start(modelContext: modelContext)
            }
        } else {
            importService.stop()
        }
    }
    
    private func syncNow() {
        _Concurrency.Task { @MainActor in
            do {
                try await importService.syncAllDatabases(modelContext: modelContext)
            } catch {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "NotionImportSettingsView").error("Failed to sync databases: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadSettings() {
        syncIntervalMinutes = settings.syncInterval / 60
        importCompleted = settings.importCompletedItems
        autoDetectTypes = settings.autoDetectTypes
        selectedDatabaseIds = Set(settings.selectedDatabaseIds)
    }
    
    private func loadAvailableDatabases() async {
        do {
            let databases = try await importService.getAvailableDatabases()
            await MainActor.run {
                availableDatabases = databases
                
                // If no databases are selected, select all by default
                if selectedDatabaseIds.isEmpty && !availableDatabases.isEmpty {
                    selectedDatabaseIds = Set(availableDatabases.map { $0.id.rawValue })
                    settings.selectedDatabaseIds = Array(selectedDatabaseIds)
                }
            }
        } catch {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "NotionImportSettingsView").error("Failed to load databases: \(error.localizedDescription)")
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

