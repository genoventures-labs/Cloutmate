//
//  SlashCommandAutocompleteView.swift
//  FocusOS
//
//  Autocomplete dropdown for slash command suggestions
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

enum SlashCommand: String, CaseIterable, Identifiable {
    case tab
    case think
    case web
    case project
    case task
    case research
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .tab: return "Attach tab reference"
        case .think: return "Toggle deep thinking"
        case .web: return "Toggle web search"
        case .project: return "Attach project reference"
        case .task: return "Attach task reference"
        case .research: return "Deep research mode"
        }
    }
    
    var icon: String {
        switch self {
        case .tab: return "square.on.square"
        case .think: return "brain.head.profile"
        case .web: return "globe"
        case .project: return "folder.fill"
        case .task: return "checkmark.circle.fill"
        case .research: return "magnifyingglass.circle.fill"
        }
    }
}

struct SlashCommandAutocompleteView: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void
    @Binding var selectedIndex: Int
    var arteGradientColors: [Color] = []
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredIndex: Int? = nil
    
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 23/255, green: 28/255, blue: 45/255).opacity(0.95),
            Color(red: 15/255, green: 18/255, blue: 33/255).opacity(0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let drawerShadow = Color.black.opacity(0.45)
    private let glowColor = Color(red: 93/255, green: 137/255, blue: 1.0).opacity(0.4)
    private let iconTint = Color(red: 146/255, green: 175/255, blue: 1.0)
    
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
        if !commands.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                        if index > 0 {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.leading, 56)
                        }
                        
                        Button {
                            onSelect(command)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: command.icon)
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundStyle(iconTint)
                                    .frame(width: 26, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("/\(command.rawValue)")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text(command.label)
                                        .font(descriptionFont)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer(minLength: 0)
                            }
                            .frame(height: 52)
                            .padding(.horizontal, 18)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(rowBackground(for: index))
                        .onHover { hovering in
                            if hovering {
                                hoveredIndex = index
                                selectedIndex = index
                            } else if hoveredIndex == index {
                                hoveredIndex = nil
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, 8)
            .background(backgroundLayer)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(innerBorder)
            .shadow(color: drawerShadow, radius: 28, x: 0, y: 24)
            .compositingGroup()
        }
    }
    
    @ViewBuilder
    private func rowBackground(for index: Int) -> some View {
        let isActive = selectedIndex == index || hoveredIndex == index
        
        // Hover: subtle glow around border (rgba(93, 137, 255, 0.4))
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(isActive ? 0.07 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(glowColor, lineWidth: isActive ? 1 : 0)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
    }
    
    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(backgroundGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .blur(radius: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.2))
                    )
            )
    }
    
    private var innerBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: arteGradientColors.isEmpty
                        ? [Color.white.opacity(0.15), Color.white.opacity(0.05)]
                        : arteGradientColors.map { $0.opacity(0.18) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.65
            )
    }
}
