//
//  V2GlassContentScaffold.swift
//  Cloutmate
//
//  Shared layout scaffold for glassmorphic content screens with optional sidebars.
//

import SwiftUI

struct V2GlassContentScaffold<Header: View, Content: View, Sidebar: View>: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    
    private let accentGradient: LinearGradient
    private let showsSidebar: Bool
    private let sidebarWidth: CGFloat
    private let header: Header
    private let content: Content
    private let sidebar: Sidebar
    
    init(
        accentGradient: LinearGradient = AuroraPalette.linearGradient(for: .dark),
        showsSidebar: Bool = false,
        sidebarWidth: CGFloat = 320,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder sidebar: () -> Sidebar
    ) {
        self.accentGradient = accentGradient
        self.showsSidebar = showsSidebar
        self.sidebarWidth = sidebarWidth
        self.header = header()
        self.content = content()
        self.sidebar = sidebar()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                V2GlassHeaderContainer(accentGradient: accentGradient) {
                    header
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        content
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(glassColorSystem.backgroundColor())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            
            if showsSidebar {
                Divider()
                    .blendMode(.overlay)
                    .opacity(0.08)
                
                VStack(spacing: 18) {
                    sidebar
                }
                .frame(width: sidebarWidth, alignment: .top)
                .frame(
                    minWidth: nil,
                    idealWidth: nil,
                    maxWidth: nil,
                    minHeight: nil,
                    idealHeight: nil,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(glassColorSystem.backgroundElevated().opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(glassColorSystem.borderColor(), lineWidth: 0.8)
                        )
                        .shadow(color: glassColorSystem.backgroundSecondary().opacity(0.18), radius: 24, y: 12)
                )
                .padding(.trailing, 18)
            }
        }
        .background(glassColorSystem.backgroundColor())
        .ignoresSafeArea(edges: [.bottom])
    }
}

private struct V2GlassHeaderContainer<Content: View>: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    let accentGradient: LinearGradient
    private let content: Content
    
    init(accentGradient: LinearGradient, @ViewBuilder content: () -> Content) {
        self.accentGradient = accentGradient
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(glassColorSystem.backgroundElevated().opacity(0.72))
                accentGradient
                    .opacity(0.16)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                if !reduceMotion {
                    AuroraPalette.linearGradient(for: colorScheme)
                        .opacity(0.10)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .auroraShimmer()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(glassColorSystem.borderColor(), lineWidth: 0.9)
            )
        )
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}

struct V2GlassHeaderBar<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    private let leadingAccessory: Leading
    private let trailingAccessory: Trailing
    
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leadingAccessory: () -> Leading = { EmptyView() },
        @ViewBuilder trailingAccessory: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingAccessory = leadingAccessory()
        self.trailingAccessory = trailingAccessory()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            leadingAccessory
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 12)
            
            trailingAccessory
        }
    }
}

struct V2GlassControlStack<Content: View>: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private let spacing: CGFloat
    private let content: Content
    
    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            GlassPanel(tier: .overlay, cornerRadius: 18) {
                glassColorSystem.cardElevated().opacity(0.82)
            }
        )
    }
}


