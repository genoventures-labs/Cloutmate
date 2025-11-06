//
//  MenuBarPopoverView.swift
//  CloutmateMenuBar
//

import SwiftUI
import SwiftData
import CloutmateShared

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @FocusState private var isComposerFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("Section", selection: $selectedTab) {
                Text("Capture").tag(0)
                Text("Tasks").tag(1)
                Text("Quick Post").tag(2)
                Text("Artifacts").tag(3)
                Text("Settings").tag(4)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    MenuBarQuickCaptureView()
                case 1:
                    TasksView()
                case 2:
                    QuickComposerView()
                case 3:
                    UpcomingPostsView()
                case 4:
                    MenuBarSettingsView()
                default:
                    EmptyView()
                }
            }
        }
        .frame(width: 400, height: 500)
        .background(.ultraThinMaterial)
        .onAppear {
            // Set up keyboard shortcuts
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    switch event.keyCode {
                    case 13: // W key - open quick post
                        if !event.modifierFlags.contains(.shift) {
                            selectedTab = 0
                            return nil
                        }
                    case 9: // V key - open upcoming
                        selectedTab = 1
                        return nil
                    case 1: // S key - open settings
                        selectedTab = 2
                        return nil
                    default:
                        break
                    }
                }
                return event
            }
        }
    }
}

#Preview {
    MenuBarPopoverView()
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Artifact.self])
}

