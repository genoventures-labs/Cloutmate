//
//  MondayImportSettingsView.swift
//  FocusOS
//
//  Settings drawer for Monday.com import configuration
//

import SwiftUI
import SwiftData
import os.log
import FocusOSShared

struct MondayImportSettingsView: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @ObservedObject private var importService = MondayImportService.shared
    @ObservedObject private var settings = MondayImportSettings.shared
    
    @State private var availableBoards: [MondayBoard] = []
    @State private var selectedBoardIds: Set<String> = []
    @State private var syncIntervalMinutes: Double = 15
    @State private var importCompleted: Bool = false
    
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
                await loadAvailableBoards()
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
                Text("Monday.com Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Configure Monday.com import and sync preferences")
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
                        Text("Connected to Monday.com")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                } else {
                    Text("Not connected to Monday.com. Connect from the Integrations drawer.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
            }
            
            DrawerSection(title: "Import Status", icon: "power") {
                Toggle(isOn: $settings.importEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Monday.com Import")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Automatically sync boards and items from selected Monday.com boards")
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
            
            DrawerSection(title: "Boards", icon: "folder") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which Monday.com boards to import")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if availableBoards.isEmpty {
                        Text("No boards available or not connected to Monday.com.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(availableBoards, id: \.id) { board in
                                    HStack {
                                        Image(systemName: "tablecells")
                                            .foregroundStyle(.kosmicBlue)
                                            .frame(width: 20)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(board.name)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(glassColorSystem.textPrimary())
                                            
                                            if let itemsCount = board.itemsCount {
                                                Text("\(itemsCount) items")
                                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                                    .foregroundStyle(glassColorSystem.textSecondary())
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: Binding(
                                            get: { selectedBoardIds.contains(board.id) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedBoardIds.insert(board.id)
                                                } else {
                                                    selectedBoardIds.remove(board.id)
                                                }
                                                settings.selectedBoardIds = Array(selectedBoardIds)
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .tint(.kosmicBlue)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
            
            DrawerSection(title: "Sync Settings", icon: "clock") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Interval")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        Picker("", selection: $syncIntervalMinutes) {
                            Text("15 minutes").tag(15.0)
                            Text("30 minutes").tag(30.0)
                            Text("1 hour").tag(60.0)
                            Text("Manual").tag(0.0)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: syncIntervalMinutes) { newValue in
                            settings.syncInterval = newValue * 60
                        }
                    }
                    
                    Toggle(isOn: $importCompleted) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import Completed Items")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                            Text("Include completed/done items from Monday.com boards")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.kosmicBlue)
                    .onChange(of: importCompleted) { newValue in
                        settings.importCompletedItems = newValue
                    }
                }
            }
            
            DrawerSection(title: "Last Sync", icon: "clock.arrow.circlepath") {
                if let lastSync = settings.lastSyncDate {
                    Text("Last synced: \(lastSync, style: .relative)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                } else {
                    Text("Never synced")
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
        .padding(24)
    }
    
    private func loadSettings() {
        selectedBoardIds = Set(settings.selectedBoardIds)
        syncIntervalMinutes = settings.syncInterval / 60
        importCompleted = settings.importCompletedItems
    }
    
    private func loadAvailableBoards() async {
        do {
            availableBoards = try await importService.getAvailableBoards()
        } catch {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "MondayImportSettingsView").error("Failed to load boards: \(error.localizedDescription)")
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
                try await importService.syncAllBoards(modelContext: modelContext)
            } catch {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "MondayImportSettingsView").error("Failed to sync boards: \(error.localizedDescription)")
            }
        }
    }
    
    private func closeDrawer() {
        withAnimation {
            isPresented = false
        }
    }
}

