//
//  SettingsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Combine
import CloutmateShared

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var themeManager = ReactiveThemeManager.shared
    @State private var selectedEntry: SettingsEntry = .glassEffects
    @State private var collapsedGroupIDs: Set<SettingsGroup> = []
    @State private var contextGuardEnabled = ContextGuardSettings.shared.isGuardEnabled
    
    var body: some View {
        V2GlassContentScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            showsSidebar: true,
            sidebarWidth: 280,
            header: { headerView },
            content: { selectedContent },
            sidebar: { settingsSidebar }
        )
        .background(
            ZStack {
                glassColorSystem.backgroundColor()
                glassColorSystem.emotionalBackgroundShift()
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Settings")
    }
}

private extension SettingsView {
    var headerView: some View {
        V2GlassHeaderBar(
            title: "Settings",
            subtitle: "Tune Cloutmate’s workspace to match your flow.",
            trailingAccessory: {
                Text(selectedEntry.title)
                    .font(.subheadline)
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
        )
    }
    
    @ViewBuilder
    var selectedContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionIntro(for: selectedEntry)
            
            switch selectedEntry {
            case .glassEffects:
                V2GlassControlStack {
                    GlassEffectsSection()
                }
            case .auroraTheme:
                auroraThemeControls
            case .aiAssistant:
                V2GlassControlStack {
                    AIAssistantSection()
                }
            case .rituals:
                ritualsControls
            case .contextGuard:
                contextGuardControls
            case .notion:
                V2GlassControlStack {
                    NotionIntegrationSection()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    var settingsSidebar: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(settingsSidebarGroups) { group in
                    DashboardTile(accent: glassColorSystem.emotionalAccent()) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: group.id.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(glassColorSystem.emotionalAccent())
                                Text(group.id.title)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                Spacer()
                                Button(action: {
                                    withAnimation(GlassMotion.Easing.spring) {
                                        if collapsedGroupIDs.contains(group.id) {
                                            collapsedGroupIDs.remove(group.id)
                                        } else {
                                            collapsedGroupIDs.insert(group.id)
                                        }
                                    }
                                }) {
                                    Image(systemName: collapsedGroupIDs.contains(group.id) ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if !collapsedGroupIDs.contains(group.id) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(group.entries) { entry in
                                        sidebarButton(for: entry)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func sidebarButton(for entry: SettingsEntry) -> some View {
        let isSelected = selectedEntry == entry
        Button {
            withAnimation(GlassMotion.Easing.spring) {
                selectedEntry = entry
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? glassColorSystem.textPrimary() : glassColorSystem.textSecondary())
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(glassColorSystem.emotionalAccent())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                        ? glassColorSystem.glassTint(for: .primary).opacity(0.24)
                        : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected
                                ? glassColorSystem.glassTint(for: .primary).opacity(0.45)
                                : glassColorSystem.borderColor().opacity(0.4),
                                lineWidth: isSelected ? 1.2 : 0.8
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    func sectionIntro(for entry: SettingsEntry) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(glassColorSystem.emotionalAccent().opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: entry.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(glassColorSystem.emotionalAccent())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
        }
    }
    
    var auroraThemeControls: some View {
        V2GlassControlStack(spacing: 18) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Aurora Reactive Theme Engine")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                Text(themeManager.isEnabled ? "ARTE actively adapts colors, motion, and lighting." : "Enable ARTE for adaptive moods, gradients, and motion.")
                                    .font(.footnote)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Toggle("", isOn: $themeManager.isEnabled)
                                .toggleStyle(.switch)
                                .onChange(of: themeManager.isEnabled) { _, newValue in
                                    handleArteToggleChange(newValue)
                                }
                        }

                        if themeManager.isEnabled {
                            HStack(spacing: 12) {
                                Image(systemName: themeManager.currentState.iconName)
                                    .font(.system(size: 28))
                                    .foregroundStyle(glassColorSystem.emotionalAccent())
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(glassColorSystem.emotionalAccent().opacity(0.18))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(themeManager.currentState.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    Text("Confidence \(Int(themeManager.confidence * 100))% · Intensity \(Int(themeManager.intensity * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                }
                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

            GlassDivider()

                        NavigationLink {
                            ARTESettingsView()
                                .navigationTitle("Aurora Theme Engine")
                        } label: {
                            HStack(spacing: 6) {
                                Text("Open full ARTE controls")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
    var ritualsControls: some View {
                        let settings = RitualSettings.shared
        return V2GlassControlStack(spacing: 18) {
            Text("Keep your rituals synchronized across morning, evening, and weekly cadences.")
                .font(.footnote)
                .foregroundStyle(glassColorSystem.textSecondary())
                .fixedSize(horizontal: false, vertical: true)
            
            GlassDivider()

            VStack(alignment: .leading, spacing: 12) {
                ritualRow(title: "Morning Ritual", value: formatTime(settings.morningTime), systemImage: "sunrise")
                GlassDivider()
                ritualRow(title: "Evening Reflection", value: formatTime(settings.eveningTime), systemImage: "moon.stars")
                GlassDivider()
                ritualRow(title: "Weekly Review", value: "\(weekdayName(settings.weeklyReviewDay)) · \(formatTime(settings.weeklyReviewTime))", systemImage: "calendar.badge.clock")
                GlassDivider()
                ritualRow(title: "Smart Nudges", value: settings.nudgesEnabled ? "Enabled" : "Disabled", systemImage: "sparkles", highlight: settings.nudgesEnabled ? .kosmicGreen : .secondary)
                        }
            
            GlassDivider()
            
            // Test Nudge Button
            Button {
                triggerTestNudge()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(glassColorSystem.emotionalAccent())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Test Nudge")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Preview how Aurora's nudges appear")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(glassColorSystem.emotionalAccent())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(glassColorSystem.emotionalAccent().opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            GlassDivider()

                        NavigationLink {
                            RitualSettingsView()
                                .navigationTitle("Rituals & Nudges")
                        } label: {
                            HStack(spacing: 6) {
                                Text("Open ritual controls")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
    var contextGuardControls: some View {
        V2GlassControlStack(spacing: 16) {
            Text("Pause before dramatic context switches and keep focused work uninterrupted.")
                .font(.footnote)
                .foregroundStyle(glassColorSystem.textSecondary())
            
            GlassDivider()
            
            Toggle(isOn: $contextGuardEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Context switch guard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    Text(contextGuardEnabled ? "Aurora will confirm intent before leaving your current workspace." : "Switch tabs instantly without guardrails.")
                        .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            .toggleStyle(.switch)
            .onChange(of: contextGuardEnabled) { _, newValue in
                ContextGuardSettings.shared.isGuardEnabled = newValue
            }
            
            GlassDivider()
            
            NavigationLink {
                TemporalIntelligenceSettingsView()
                    .navigationTitle("Temporal Intelligence")
            } label: {
                HStack(spacing: 6) {
                    Text("Open temporal controls")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.plain)
        }
    }
                
    func ritualRow(title: String, value: String, systemImage: String, highlight: Color? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(glassColorSystem.emotionalAccent())
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textPrimary())
                Text(value)
                    .font(.caption)
                    .foregroundStyle(highlight ?? glassColorSystem.textSecondary())
            }
            Spacer()
        }
    }
    
    var settingsSidebarGroups: [SettingsSidebarGroup] {
        [
            SettingsSidebarGroup(id: .appearance, entries: [.glassEffects, .auroraTheme]),
            SettingsSidebarGroup(id: .intelligence, entries: [.aiAssistant, .contextGuard]),
            SettingsSidebarGroup(id: .rituals, entries: [.rituals]),
            SettingsSidebarGroup(id: .integrations, entries: [.notion])
        ]
    }
    
    struct SettingsSidebarGroup: Identifiable {
        let id: SettingsGroup
        let entries: [SettingsEntry]
    }
    
    enum SettingsGroup: String, CaseIterable, Identifiable {
        case appearance
        case intelligence
        case rituals
        case integrations
        
        var id: SettingsGroup { self }
        
        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .intelligence: return "Intelligence"
            case .rituals: return "Rhythms"
            case .integrations: return "Integrations"
            }
        }
        
        var iconName: String {
            switch self {
            case .appearance: return "paintbrush.pointed"
            case .intelligence: return "brain.head.profile"
            case .rituals: return "target"
            case .integrations: return "link"
            }
        }
    }
    
    enum SettingsEntry: String, CaseIterable, Identifiable {
        case glassEffects
        case auroraTheme
        case aiAssistant
        case rituals
        case contextGuard
        case notion
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .glassEffects: return "Glass Effects"
            case .auroraTheme: return "Aurora Theme Engine"
            case .aiAssistant: return "AI Assistant"
            case .rituals: return "Rituals & Nudges"
            case .contextGuard: return "Context Guard"
            case .notion: return "Notion Integration"
            }
        }
        
        var subtitle: String? {
            switch self {
            case .glassEffects:
                return "Adjust blur, tint, and motion for the glassmorphic shell."
            case .auroraTheme:
                return "Let Aurora adapt colors and motion depending on how you feel."
            case .aiAssistant:
                return "Set how Aurora supports your creative and operational work."
            case .rituals:
                return "Review and tweak your daily and weekly rituals."
            case .contextGuard:
                return "Decide when Aurora should intercept tab switching."
            case .notion:
                return "Connect your Notion workspace for knowledge syncing."
            }
        }
        
        var icon: String {
            switch self {
            case .glassEffects: return "sparkles"
            case .auroraTheme: return "circle.dashed.inset.filled"
            case .aiAssistant: return "brain.head.profile"
            case .rituals: return "target"
            case .contextGuard: return "hourglass.circle"
            case .notion: return "externaldrive.badge.icloud"
                }
            }
        
        var group: SettingsGroup {
            switch self {
            case .glassEffects, .auroraTheme: return .appearance
            case .aiAssistant, .contextGuard: return .intelligence
            case .rituals: return .rituals
            case .notion: return .integrations
            }
        }
    }
    
    func formatTime(_ components: DateComponents) -> String {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        let date = Calendar.current.date(from: dateComponents) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
    }

    func handleArteToggleChange(_ newValue: Bool) {
        glassColorSystem.isARTEEnabled = newValue
        themeManager.saveConfiguration(modelContext: modelContext)
        if newValue {
            themeManager.restart(modelContext: modelContext)
        } else {
            themeManager.stop()
        }
    }
    
    func triggerTestNudge() {
        // Trigger actual nudge evaluation to show a real nudge
        // This will check all nudge conditions and deliver an actual nudge if available
        // SmartNudgeService is already @MainActor, so we can call it directly
        SmartNudgeService.shared.forceEvaluateTriggers(modelContext: modelContext)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [])
}
