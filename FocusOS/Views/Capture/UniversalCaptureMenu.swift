//
//  UniversalCaptureMenu.swift
//  FocusOS
//
//  Universal New menu replacing single New Post button
//

import SwiftUI
import AppKit

struct UniversalCaptureMenu: View {
    @State private var showMenu = false
    @State private var hoveredOption: CaptureOption?
    
    var body: some View {
        Menu {
            ForEach(CaptureOption.allCases, id: \.self) { option in
                Button(action: { option.action() }) {
                    HStack {
                        Image(systemName: option.icon)
                        Text(option.title)
                        if let shortcut = option.keyboardShortcut {
                            Spacer()
                            Text(shortcut)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
 Label(option.title, systemImage: option.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                Text("New...")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassPanel(tier: .floatingAction, cornerRadius: 10)
        }
        .menuStyle(.borderlessButton)
    }
}

enum CaptureOption: String, CaseIterable {
    case inbox = "Inbox Item"
    case task = "Task"
    case note = "Note"
    case post = "Post"
    case project = "Project"
    case area = "Area"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .inbox: return "tray.fill"
        case .task: return "checkmark.circle"
        case .note: return "note.text"
        case .post: return "square.and.pencil"
        case .project: return "folder.fill"
        case .area: return "rectangle.stack.fill"
        }
    }
    
    var keyboardShortcut: String? {
        switch self {
        case .inbox: return "⌥␣"
        case .task: return "⌥T"
        case .note: return "⌥N"
        case .post: return "⌘N"
        case .project: return "⌥P"
        case .area: return "⌥A"
        @unknown default: return nil
        }
    }
    
    func action() {
        switch self {
        case .inbox:
            // Open Quick Capture drawer
            NotificationCenter.default.post(name: .showQuickCapture, object: nil)
        case .task:
            // Open task creation
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
        case .note:
            // Open note creation
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.notes)
        case .post:
            // Open calendar composer drawer
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.calendar)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openComposer, object: CalendarComposerRequest())
            }
        case .project:
            // Navigate to Projects and show creation
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
        case .area:
            // Navigate to Areas and show creation
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.areas)
        }
    }
}

#Preview {
    UniversalCaptureMenu()
}

