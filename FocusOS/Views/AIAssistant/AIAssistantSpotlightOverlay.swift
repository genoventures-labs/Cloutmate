//
//  AIAssistantSpotlightOverlay.swift
//  FocusOS
//
//  AI Assistant V2 - Spotlight Overlay for Global Search
//  ⌘+K → Search all Aurora conversations and entities
//  ⌘+⇧+A → Aurora Spotlight overlay (quick command)
//

import SwiftUI
import SwiftData
import FocusOSShared

struct AIAssistantSpotlightOverlay: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool
    @State private var searchText = ""
    @State private var searchResults: [AIAssistantSearchResult] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Large text field
            TextField("Search Aurora conversations and entities...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($isInputFocused)
                .padding(20)
                .background(.ultraThinMaterial)
                .onChange(of: searchText) { _, newValue in
                    performSearch(newValue)
                }
                .onAppear {
                    isInputFocused = true
                }
                .onKeyPress(.escape) {
                    dismiss()
                    return .handled
                }
            
            Divider()
            
            // Search results
            if !searchResults.isEmpty {
                List(searchResults) { result in
                    AIAssistantSearchResultRow(result: result)
                        .onTapGesture {
                            handleResultTap(result)
                        }
                }
            } else if !searchText.isEmpty {
                VStack {
                    Text("No results found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 600, height: 500)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20)
    }
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Use WorkspaceObjectSearchService for entity search
        let results = WorkspaceObjectSearchService.shared.search(
            query: query,
            modelContext: modelContext,
            limit: 20
        )
        
        searchResults = results.map { result in
            AIAssistantSearchResult(
                id: result.id,
                title: result.title,
                subtitle: result.type.rawValue,
                type: result.type
            )
        }
    }
    
    private func handleResultTap(_ result: AIAssistantSearchResult) {
        // Deep link to entity
        switch result.type {
        case .project:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .task:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.tasks)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .note:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.notes)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .artifact:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.posts)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .area:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.areas)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .post:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.posts)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .reminder:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.tasks)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .inboxItem:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.inbox)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .focusSession:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
        case .event:
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.calendar)
            NotificationCenter.default.post(name: .openEntity, object: result.id)
}
        dismiss()
    }
}

struct AIAssistantSearchResult: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let type: ObjectType
}

struct AIAssistantSearchResultRow: View {
    let result: AIAssistantSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(result.type))
                .foregroundColor(.kosmicBlue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func iconForType(_ type: ObjectType) -> String {
        switch type {
        case .project: return "folder.fill"
        case .task: return "checkmark.circle"
        case .note: return "doc.text.fill"
        case .artifact: return "doc.richtext"
        case .area: return "rectangle.stack.fill"
        case .post: return "square.and.pencil"
        case .reminder: return "bell.fill"
        case .inboxItem: return "tray.fill"
        case .focusSession: return "timer"
        case .event: return "calendar"
}
    }
}

#Preview {
    AIAssistantSpotlightOverlay()
        .modelContainer(for: [AIMessage.self, AIConversation.self])
}

