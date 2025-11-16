//
//  SlashCommandDrawerView.swift
//  Cloutmate
//
//  V2DrawerScaffold-based slash command drawer that appears in the welcome area
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SlashCommandDrawerView: View {
    let commands: [SlashCommand]
    let selectedIndex: Int
    let onSelect: (SlashCommand) -> Void
    let arteGradientColors: [Color]
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredIndex: Int? = nil
    
    private var accentGradient: LinearGradient {
        if arteGradientColors.isEmpty {
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicPurple],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: arteGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var descriptionFont: Font {
        #if os(macOS)
        if NSFont(name: "Inter-Regular", size: 12) != nil {
            return Font.custom("Inter-Regular", size: 12)
        } else if NSFont(name: "Inter", size: 12) != nil {
            return Font.custom("Inter", size: 12)
        }
        #endif
        return Font.system(size: 12, weight: .regular, design: .default)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - more subtle, V2 polished
            HStack(spacing: 10) {
                Image(systemName: "command.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Text("Slash Commands")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            
            // Content - V2 polished command rows
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                        SlashCommandRow(
                            command: command,
                            isSelected: selectedIndex == index,
                            isHovered: hoveredIndex == index,
                            descriptionFont: descriptionFont,
                            onSelect: {
                                onSelect(command)
                            },
                            onHover: { hovering in
                                if hovering {
                                    hoveredIndex = index
                                } else if hoveredIndex == index {
                                    hoveredIndex = nil
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(glassColorSystem.backgroundColor())
        }
        .background(glassColorSystem.backgroundColor())
        .frame(height: 400)
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

private struct SlashCommandRow: View {
    let command: SlashCommand
    let isSelected: Bool
    let isHovered: Bool
    let descriptionFont: Font
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Icon in circular background - smaller, more compact
                Image(systemName: command.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(
                                isSelected || isHovered
                                ? glassColorSystem.glassTint(for: .accent).opacity(0.25)
                                : glassColorSystem.glassTint(for: .surface).opacity(0.2)
                            )
                    )
                
                // Command info
                VStack(alignment: .leading, spacing: 2) {
                    Text("/\(command.rawValue)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Text(command.label)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected || isHovered
                        ? glassColorSystem.glassTint(for: .surface).opacity(0.3)
                        : glassColorSystem.glassTint(for: .surface).opacity(0.15)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected || isHovered
                        ? glassColorSystem.glassTint(for: .accent).opacity(0.4)
                        : glassColorSystem.glassTint(for: .surface).opacity(0.25),
                        lineWidth: isSelected || isHovered ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
}

