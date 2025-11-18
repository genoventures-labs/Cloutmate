//
//  V2DrawerScaffold.swift
//  FocusOS
//
//  Shared layout scaffolding for glassmorphic V2 drawers.
//

import SwiftUI

struct V2DrawerScaffold<Header: View, Content: View, Sidebar: View>: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    
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
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        AuroraShimmerView(colorScheme: colorScheme)
                    }
                )
                .overlay(
                    Divider()
                        .opacity(0.08),
                    alignment: .bottom
                )
                
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
            .frame(maxWidth: .infinity)
            
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
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
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
        VStack(alignment: .leading, spacing: 16) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let title {
                        HStack(spacing: 10) {
                            if let icon {
                                Image(systemName: icon)
                                    .foregroundStyle(.secondary)
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
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(glassColorSystem.cardColor().opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.14))
                )
                .shadow(
                    color: glassColorSystem.backgroundElevated().opacity(0.18),
                    radius: 18,
                    x: 0,
                    y: 14
                )
        )
    }
}

private struct AuroraShimmerView: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        Rectangle()
            .fill(
                AuroraPalette.linearGradient(
                    for: colorScheme,
                    start: .leading,
                    end: .trailing
                )
            )
            .opacity(0.12)
            .auroraShimmer()
            .allowsHitTesting(false)
    }
}


// MARK: - Focus Glow Support

private struct DrawerFocusGlowModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.01))
                    .shadow(
                        color: isFocused ? Color.kosmicPurple.opacity(0.28) : .clear,
                        radius: 18,
                        x: 0,
                        y: 8
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isFocused
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.kosmicBlue.opacity(0.9), .kosmicPurple.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                  )
                                : AnyShapeStyle(Color.white.opacity(0.08)),
                                lineWidth: isFocused ? 1.8 : 1
                            )
                    )
            )
    }
}

extension View {
    func drawerFocusGlow() -> some View {
        modifier(DrawerFocusGlowModifier())
    }
}

