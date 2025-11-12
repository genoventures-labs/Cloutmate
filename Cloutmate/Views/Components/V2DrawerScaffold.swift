//
//  V2DrawerScaffold.swift
//  Cloutmate
//
//  Shared layout scaffolding for glassmorphic V2 drawers.
//

import SwiftUI

struct V2DrawerScaffold<Header: View, Content: View, Sidebar: View>: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private let accentGradient: LinearGradient
    private let accentWidth: CGFloat
    private let showsSidebar: Bool
    private let sidebarWidth: CGFloat
    private let header: Header
    private let content: Content
    private let sidebar: Sidebar
    
    init(
        accentGradient: LinearGradient = LinearGradient(
            colors: [.kosmicBlue, .kosmicPurple],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentWidth: CGFloat = 6,
        showsSidebar: Bool = false,
        sidebarWidth: CGFloat = 320,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder sidebar: () -> Sidebar
    ) {
        self.accentGradient = accentGradient
        self.accentWidth = accentWidth
        self.showsSidebar = showsSidebar
        self.sidebarWidth = sidebarWidth
        self.header = header()
        self.content = content()
        self.sidebar = sidebar()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Accent Bar
            Rectangle()
                .fill(accentGradient)
                .frame(width: accentWidth)
            
            // Primary Column
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial)
                .overlay(
                    Divider()
                        .opacity(0.08),
                    alignment: .bottom
                )
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        content
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 760, alignment: .leading)
                }
                .background(glassColorSystem.backgroundColor())
            }
            
            if showsSidebar {
                Divider()
                    .opacity(0.08)
                
                VStack(spacing: 0) {
                    sidebar
                }
                .frame(width: sidebarWidth)
                .background(glassColorSystem.backgroundElevated())
            }
        }
        .background(glassColorSystem.backgroundColor())
    }
}

struct DrawerSection<Content: View>: View {
    let title: String?
    let icon: String?
    let subtitle: String?
    private let content: Content
    
    init(
        title: String? = nil,
        icon: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                if title != nil || subtitle != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        if let title {
                            HStack(spacing: 8) {
                                if let icon {
                                    Image(systemName: icon)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(title)
                                    .font(.headline)
                            }
                        }
                        
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                content
            }
            .padding(20)
        }
    }
}


