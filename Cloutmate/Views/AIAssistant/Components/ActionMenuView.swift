//
//  ActionMenuView.swift
//  Cloutmate
//
//  Aurora action menu embedded in the chat input row.
//

import SwiftUI
import CloutmateShared

enum AuroraChatQuickAction: String, CaseIterable, Identifiable {
    case createTask
    case createProject
    case createNote
    case createReminder
    case attachTab
    case smartRecap
    case exportDraft
    case toggleOffline

    var id: String { rawValue }

    var label: String {
        switch self {
        case .createTask: return "Create Task"
        case .createProject: return "Add Project"
        case .createNote: return "New Note"
        case .createReminder: return "Add Reminder"
        case .attachTab: return "Attach Tab"
        case .smartRecap: return "Smart Recap"
        case .exportDraft: return "Export to Drafts"
        case .toggleOffline: return "Toggle Offline Mode"
        }
    }

    var systemIcon: String {
        switch self {
        case .createTask: return "checkmark.circle"
        case .createProject: return "folder.badge.plus"
        case .createNote: return "note.text.badge.plus"
        case .createReminder: return "bell.badge"
        case .attachTab: return "square.on.square"
        case .smartRecap: return "sparkles"
        case .exportDraft: return "square.and.arrow.down"
        case .toggleOffline: return "airplane"
        }
    }
}

struct ActionMenuView: View {
    var isDisabled: Bool
    var isOfflineMode: Bool
    var tint: Color
    var onSelect: (AuroraChatQuickAction) -> Void
    var onAttachTab: ((TabIdentifier) -> Void)?

    @State private var isHovering = false

    private var label: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.95),
                        Color.kosmicPurple.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text("⚙︎")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(isDisabled ? 0.35 : 0.92))
            )
            .frame(width: 26, height: 26)
            .shadow(color: tint.opacity(isHovering ? 0.25 : 0.12), radius: isHovering ? 6 : 3, y: 2)
    }

    var body: some View {
        Menu {
            Section("Create") {
                menuButton(for: .createTask)
                menuButton(for: .createProject)
                menuButton(for: .createNote)
                menuButton(for: .createReminder)
            }

            Section("Workspace") {
                if let onAttachTab = onAttachTab {
                    Menu("Attach Tab") {
                        ForEach(TabIdentifier.allCases.filter { $0 != .aiAssistant }, id: \.self) { tab in
                            Button {
                                onAttachTab(tab)
                            } label: {
                                Label(tab.rawValue, systemImage: tab.icon)
                            }
                        }
                    }
                } else {
                    menuButton(for: .attachTab)
                }
            }

            Section("Utilities") {
                menuButton(for: .smartRecap)
                menuButton(for: .exportDraft)
                Toggle(isOn: .constant(isOfflineMode)) {
                    Label("Offline Mode", systemImage: AuroraChatQuickAction.toggleOffline.systemIcon)
                }
                .disabled(true)
                Button {
                    onSelect(.toggleOffline)
                } label: {
                    Text(isOfflineMode ? "Disable Offline Mode" : "Enable Offline Mode")
                }
            }
        } label: {
            label
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel("Aurora actions")
        .accessibilityHint("Quick actions like creating tasks, projects, notes, and more.")
    }

    private func menuButton(for action: AuroraChatQuickAction) -> some View {
        Button {
            onSelect(action)
        } label: {
            Label(action.label, systemImage: action.systemIcon)
        }
        .disabled(isDisabled)
    }
}

#Preview {
    ActionMenuView(
        isDisabled: false,
        isOfflineMode: true,
        tint: .kosmicBlue,
        onSelect: { _ in },
        onAttachTab: nil
    )
    .padding()
    .background(Color.black.opacity(0.85))
}

