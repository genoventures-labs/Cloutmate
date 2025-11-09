//
//  AIAssistantSidebar.swift
//  Cloutmate
//
//  AI Assistant V2 - Sidebar Component (ContentCard Tier)
//  Displays pinned and recent conversations with ARTE color accents
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AIAssistantSidebar: View {
    let conversations: [AIConversation]
    let selectedConversation: AIConversation?
    @Binding var searchText: String
    @Binding var selectedDateFilter: DateFilter
    @Binding var selectedTags: Set<String>
    
    let onConversationTap: (AIConversation) -> Void
    let onRename: (AIConversation) -> Void
    let onDelete: (AIConversation) -> Void
    let onTogglePin: (AIConversation) -> Void
    let onRefreshSummary: (AIConversation) -> Void
    let onExportToDraft: (AIConversation) -> Void
    
    @Environment(\.glassTier) private var glassTier
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ReactiveThemeManager.shared
    @State private var cpsPriorities: [UUID] = []
    
    // ARTE color accent based on emotional state
    private var arteAccentColor: Color {
        switch themeManager.currentState {
        case .focused:
            return .blue
        case .reflective:
            return .purple
        case .fatigued:
            return .gray
        case .calm:
            return .kosmicBlue
        case .energized:
            return .cyan
        }
    }
    
    // Filtered and sorted conversations
    private var filteredConversations: [AIConversation] {
        var filtered = conversations
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { conversation in
                (conversation.title ?? "").localizedCaseInsensitiveContains(searchText) ||
                (conversation.summary ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { conversation in
                !Set(conversation.tags).isDisjoint(with: selectedTags)
            }
        }
        
        // Apply date filter
        if selectedDateFilter != .all {
            let calendar = Calendar.current
            let now = Date()
            
            filtered = filtered.filter { conversation in
                guard let createdAt = conversation.createdAt else { return false }
                
                switch selectedDateFilter {
                case .today:
                    return calendar.isDateInToday(createdAt)
                case .thisWeek:
                    return calendar.isDate(createdAt, equalTo: now, toGranularity: .weekOfYear)
                case .thisMonth:
                    return calendar.isDate(createdAt, equalTo: now, toGranularity: .month)
                case .older:
                    return createdAt < calendar.date(byAdding: .month, value: -1, to: now) ?? now
                case .all:
                    return true
                }
            }
        }
        
        // Sort: pinned first, then by CPS weight, then by date
        return filtered.sorted { conv1, conv2 in
            // Pinned conversations first
            if conv1.isPinned != conv2.isPinned {
                return conv1.isPinned
            }
            
            // Then by CPS priority (if available)
            if !cpsPriorities.isEmpty {
                let index1 = cpsPriorities.firstIndex(of: conv1.id) ?? Int.max
                let index2 = cpsPriorities.firstIndex(of: conv2.id) ?? Int.max
                if index1 != index2 {
                    return index1 < index2
                }
            }
            
            // Finally by date
            let date1 = conv1.createdAt ?? Date.distantPast
            let date2 = conv2.createdAt ?? Date.distantPast
            return date1 > date2
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversations")
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Spacer()
            }
            
            Divider()
            
            // Reflection Panel (if 5+ conversations)
            if conversations.count >= 5 {
                ReflectionPanel(conversations: conversations)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                Divider()
            }
            
            // Search and Filter Bar
            ConversationSearchBar(
                searchText: $searchText,
                selectedFilter: $selectedDateFilter,
                selectedTags: $selectedTags,
                allTags: conversations.flatMap { $0.tags }.removingDuplicates().sorted()
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Conversations List
            ScrollView {
                VStack(spacing: 12) {
                    if filteredConversations.isEmpty {
                        ContentUnavailableView(
                            "No conversations found",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("No conversations match your search or filter criteria")
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        ForEach(filteredConversations) { conversation in
                            ConversationCardV2(
                                conversation: conversation,
                                isSelected: selectedConversation?.id == conversation.id,
                                onTap: {
                                    onConversationTap(conversation)
                                },
                                onRename: {
                                    onRename(conversation)
                                },
                                onDelete: {
                                    onDelete(conversation)
                                },
                                onTogglePin: {
                                    onTogglePin(conversation)
                                },
                                onRefreshSummary: {
                                    onRefreshSummary(conversation)
                                },
                                onExportToDraft: {
                                    onExportToDraft(conversation)
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
        }
        .background(.ultraThinMaterial)
        .onAppear {
            loadCPSPriorities()
        }
    }
    
    private func loadCPSPriorities() {
        guard !conversations.isEmpty else {
            cpsPriorities = []
            return
        }
        
        _Concurrency.Task { @MainActor in
            // Query PriorityScore objects for conversations
            let conversationIds = Set(conversations.map { $0.id })
            
            // Fetch PriorityScore objects for these conversations
            // Use "conversation" as objectType (PriorityEngine uses string types)
            let descriptor = FetchDescriptor<PriorityScore>(
                predicate: #Predicate<PriorityScore> { score in
                    conversationIds.contains(score.objectId) && 
                    (score.objectType == "conversation" || score.objectType == "aiConversation")
                },
                sortBy: [SortDescriptor(\.totalScore, order: .reverse)]
            )
            
            if let scores = try? modelContext.fetch(descriptor) {
                // Extract IDs in priority order (highest score first)
                let prioritizedIds = scores.map { $0.objectId }
                
                // Also include conversations without CPS scores (at the end, sorted by date)
                let scoredIds = Set(prioritizedIds)
                let unscoredConversations = conversations
                    .filter { !scoredIds.contains($0.id) }
                    .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                    .map { $0.id }
                
                cpsPriorities = prioritizedIds + unscoredConversations
            } else {
                // Fallback: sort by date if CPS is unavailable
                cpsPriorities = conversations
                    .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                    .map { $0.id }
            }
        }
    }
}

#Preview {
    AIAssistantSidebar(
        conversations: [],
        selectedConversation: nil,
        searchText: .constant(""),
        selectedDateFilter: .constant(.all),
        selectedTags: .constant([]),
        onConversationTap: { _ in },
        onRename: { _ in },
        onDelete: { _ in },
        onTogglePin: { _ in },
        onRefreshSummary: { _ in },
        onExportToDraft: { _ in }
    )
    .environment(\.glassTier, .contentCard)
}

