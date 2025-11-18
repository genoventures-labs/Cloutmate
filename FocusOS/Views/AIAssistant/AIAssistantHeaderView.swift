//
//  AIAssistantHeaderView.swift
//  FocusOS
//
//  AI Assistant V2 - Header Component (Overlay Tier)
//

import SwiftUI
import FocusOSShared

enum ConversationFilter: String, CaseIterable {
    case all = "All"
    case ai = "AI"
    case archived = "Archived"
    case drafts = "Drafts"
}

struct AIAssistantHeaderView: View {
    let onSearch: () -> Void
    let onNewChat: () -> Void
    let onSettings: () -> Void
    @Binding var selectedFilter: DateFilter
    
    @Environment(\.glassTier) private var glassTier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        GlassPanel(tier: .overlay) {
            HStack(spacing: 16) {
                // Title with gradient
                    Text("Aurora")
                    .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                
                Spacer()
                
                // Search Button (⌘K or ⌘⇧A)
                GlassButton(
                    icon: "magnifyingglass",
                    style: .iconOnly,
                    action: onSearch
                )
                .frame(width: 32, height: 32)
                .keyboardShortcut("k", modifiers: .command)
                .help("Search conversations (⌘K)")
                
                // New Chat Button
                GlassButton(
                    icon: "plus.circle",
                    style: .iconOnly,
                    action: onNewChat
                )
                .frame(width: 32, height: 32)
                .keyboardShortcut("n", modifiers: .command)
                .help("New conversation (⌘N)")
                
                // Settings Button
                GlassButton(
                    icon: "gearshape",
                    style: .iconOnly,
                    action: onSettings
                )
                .frame(width: 32, height: 32)
                .help("Aurora Preferences")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    AIAssistantHeaderView(
        onSearch: {},
        onNewChat: {},
        onSettings: {},
        selectedFilter: .constant(.all)
    )
    .environment(\.glassTier, .overlay)
}

