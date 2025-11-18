//
//  TodoistImportSettingsView.swift
//  FocusOS
//
//  Settings drawer for Todoist import configuration
//

import SwiftUI
import SwiftData
import os.log
import FocusOSShared

struct TodoistImportSettingsView: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @ObservedObject private var importService = TodoistImportService.shared
    @ObservedObject private var settings = TodoistImportSettings.shared
    
    @State private var availableProjects: [TodoistProject] = []
    @State private var selectedProjectIds: Set<String> = []
    @State private var syncIntervalMinutes: Double = 15
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeDrawer()
                    }
                    .transition(.opacity)
                
                // Drawer
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
        .task {
            await loadAvailableProjects()
        }
        .onAppear {
            loadSettings()
        }
        .onKeyPress(.escape) {
            closeDrawer()
            return .handled
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Todoist Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Configure Todoist import and sync preferences")
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
    
    // MARK: - Content
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Connection Status
            DrawerSection(title: "Connection Status", icon: "link") {
                if settings.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.kosmicGreen)
                        Text("Connected to Todoist")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Not connected")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                }
            }
            
            // Enable/Disable Toggle
            DrawerSection(title: "Import Status", icon: "power") {
                Toggle(isOn: $settings.importEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Todoist Import")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Automatically sync projects and tasks from selected Todoist projects")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                .toggleStyle(.switch)
                .tint(.kosmicPurple)
                .disabled(!settings.isConnected)
                .onChange(of: settings.importEnabled) { newValue in
                    handleImportEnabledChange(newValue)
                }
            }
            
            // Project Selection
            DrawerSection(title: "Projects", icon: "folder") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which projects to import")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if availableProjects.isEmpty {
                        Text("No projects available")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(availableProjects.filter { !$0.isArchived }, id: \.id) { project in
                                    HStack {
                                        Circle()
                                            .fill(projectColor(project.color))
                                            .frame(width: 12, height: 12)
                                        
                                        Text(project.name)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: Binding(
                                            get: { selectedProjectIds.contains(project.id) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedProjectIds.insert(project.id)
                                                } else {
                                                    selectedProjectIds.remove(project.id)
                                                }
                                                settings.selectedProjectIds = Array(selectedProjectIds)
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .tint(.kosmicPurple)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            
            // Sync Interval
            DrawerSection(title: "Sync Interval", icon: "clock") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How often to check for Todoist changes")
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
            
            // Import Completed Tasks
            DrawerSection(title: "Completed Tasks", icon: "checkmark.circle") {
                Toggle(isOn: $settings.importCompletedTasks) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Completed Tasks")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Include tasks that are already marked as completed in Todoist")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                .toggleStyle(.switch)
                .tint(.kosmicPurple)
            }
            
            // Last Sync
            if let lastSync = settings.lastSyncDate {
                DrawerSection(title: "Last Sync", icon: "clock.arrow.circlepath") {
                    Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                GlassButton("Sync Now", icon: "arrow.clockwise", role: .primary) {
                    syncNow()
                }
                .disabled(importService.isSyncing || !settings.isConnected)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Actions
    
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
                try await importService.syncAllProjects(modelContext: modelContext)
            } catch {
                // Error handling could be added here
            }
        }
    }
    
    private func loadSettings() {
        syncIntervalMinutes = settings.syncInterval / 60
        selectedProjectIds = Set(settings.selectedProjectIds)
    }
    
    private func loadAvailableProjects() async {
        do {
            let projects = try await importService.getAvailableProjects()
            await MainActor.run {
                availableProjects = projects
                
                // If no projects are selected, select all by default
                if selectedProjectIds.isEmpty && !availableProjects.isEmpty {
                    selectedProjectIds = Set(availableProjects.filter { !$0.isArchived }.map { $0.id })
                    settings.selectedProjectIds = Array(selectedProjectIds)
                }
            }
        } catch {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "TodoistImportSettingsView").error("Failed to load projects: \(error.localizedDescription)")
        }
    }
    
    private func projectColor(_ colorString: String?) -> Color {
        // Todoist color strings are like "berry_red", "red", etc.
        // For now, return a default color
        guard let colorString = colorString else {
            return .kosmicBlue
        }
        
        // Map common Todoist colors
        switch colorString.lowercased() {
        case "berry_red", "red":
            return .red
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        case "olive_green", "green":
            return .green
        case "lime_green":
            return .green
        case "aqua", "cyan":
            return .cyan
        case "blue":
            return .blue
        case "grape", "purple":
            return .purple
        case "violet":
            return .purple
        case "pink":
            return .pink
        default:
            return .kosmicBlue
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

