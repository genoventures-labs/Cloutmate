//
//  AppleRemindersImportSettingsView.swift
//  FocusOS
//
//  Settings drawer for Apple Reminders import configuration
//

import SwiftUI
import EventKit
import SwiftData
import FocusOSShared

struct AppleRemindersImportSettingsView: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @ObservedObject private var importService = AppleRemindersImportService.shared
    @ObservedObject private var settings = AppleRemindersImportSettings.shared
    
    @State private var availableReminderLists: [EKCalendar] = []
    @State private var selectedReminderListIds: Set<String> = []
    @State private var syncIntervalMinutes: Double = 15
    @State private var importRangeForward: Int = 90
    
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
        .onAppear {
            loadSettings()
            loadAvailableReminderLists()
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
                Text("Apple Reminders Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Configure reminder import and sync preferences")
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
            // Enable/Disable Toggle
            DrawerSection(title: "Import Status", icon: "power") {
                Toggle(isOn: $settings.importEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Reminders Import")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Automatically sync reminders from selected lists")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                .toggleStyle(.switch)
                .tint(.kosmicPurple)
                .onChange(of: settings.importEnabled) { newValue in
                    handleImportEnabledChange(newValue)
                }
            }
            
            // Reminder List Selection
            DrawerSection(title: "Reminder Lists", icon: "list.bullet") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which reminder lists to import")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if availableReminderLists.isEmpty {
                        Text("No reminder lists available")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(availableReminderLists, id: \.calendarIdentifier) { list in
                                    HStack {
                                        Circle()
                                            .fill(Color(cgColor: list.cgColor))
                                            .frame(width: 12, height: 12)
                                        
                                        Text(list.title)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: Binding(
                                            get: { selectedReminderListIds.contains(list.calendarIdentifier) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedReminderListIds.insert(list.calendarIdentifier)
                                                } else {
                                                    selectedReminderListIds.remove(list.calendarIdentifier)
                                                }
                                                settings.selectedReminderListIds = Array(selectedReminderListIds)
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
                    Text("How often to check for reminder changes")
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
            
            // Import Range
            DrawerSection(title: "Import Range", icon: "calendar.badge.clock") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How far forward to import reminders")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    Stepper(value: $importRangeForward, in: 1...365, step: 1) {
                        Text("\(importRangeForward) days forward")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                    }
                    .onChange(of: importRangeForward) { newValue in
                        settings.importRangeDaysForward = newValue
                    }
                }
            }
            
            // Import Completed Reminders
            DrawerSection(title: "Completed Reminders", icon: "checkmark.circle") {
                Toggle(isOn: $settings.importCompletedReminders) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Completed Reminders")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Include reminders that are already marked as completed")
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
                .disabled(importService.isSyncing)
                
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
                try await importService.syncAllReminderLists(modelContext: modelContext)
            } catch {
                // Error handling could be added here
            }
        }
    }
    
    private func loadSettings() {
        syncIntervalMinutes = settings.syncInterval / 60
        importRangeForward = settings.importRangeDaysForward
        selectedReminderListIds = Set(settings.selectedReminderListIds)
    }
    
    private func loadAvailableReminderLists() {
        availableReminderLists = importService.getAvailableReminderLists()
        
        // If no lists are selected, select all by default
        if selectedReminderListIds.isEmpty && !availableReminderLists.isEmpty {
            selectedReminderListIds = Set(availableReminderLists.map { $0.calendarIdentifier })
            settings.selectedReminderListIds = Array(selectedReminderListIds)
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

