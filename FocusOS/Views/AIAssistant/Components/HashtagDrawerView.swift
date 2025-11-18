//
//  HashtagDrawerView.swift
//  FocusOS
//
//  V2 drawer for # hashtag/topic linking - matches MentionDrawerView design
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct HashtagDrawerView: View {
    let results: [WorkspaceObjectResult]
    let selectedIndex: Int
    let onSelect: (WorkspaceObjectResult) -> Void
    let arteGradientColors: [Color]
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var hoveredIndex: Int? = nil
    @State private var collapsedSections: Set<ObjectType> = []
    
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
            // Header - subtle, V2 polished
            HStack(spacing: 10) {
                Image(systemName: "number")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Text("Topic Linking")
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
            
            // Content - V2 polished hashtag result rows
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // Group results by type
                    let grouped = Dictionary(grouping: results) { $0.type }
                    let sortedTypes = grouped.keys.sorted { $0.rawValue < $1.rawValue }
                    
                    ForEach(sortedTypes, id: \.self) { type in
                        if let typeResults = grouped[type], !typeResults.isEmpty {
                            let isCollapsed = collapsedSections.contains(type)
                            
                            // Type header (collapsible)
                            Button {
                                if isCollapsed {
                                    collapsedSections.remove(type)
                                } else {
                                    collapsedSections.insert(type)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                    
                                    Text(WorkspaceObjectSearchService.shared.tabName(for: type))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                    
                                    Spacer()
                                    
                                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(glassColorSystem.glassTint(for: .surface).opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                            
                            if !isCollapsed {
                                ForEach(Array(typeResults.enumerated()), id: \.element.id) { typeIndex, result in
                                    let globalIndex = results.firstIndex(where: { $0.id == result.id }) ?? typeIndex
                                    HashtagRow(
                                        result: result,
                                        isSelected: selectedIndex == globalIndex,
                                        isHovered: hoveredIndex == globalIndex,
                                        descriptionFont: descriptionFont,
                                        onSelect: {
                                            onSelect(result)
                                        },
                                        onHover: { hovering in
                                            if hovering {
                                                hoveredIndex = globalIndex
                                            } else if hoveredIndex == globalIndex {
                                                hoveredIndex = nil
                                            }
                                        }
                                    )
                                }
                            }
                        }
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

private struct HashtagRow: View {
    let result: WorkspaceObjectResult
    let isSelected: Bool
    let isHovered: Bool
    let descriptionFont: Font
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    
    private func cleanSubtitle(_ subtitle: String) -> String {
        // Convert any structured mentions in subtitle to display names
        var display = MentionService.shared.convertToDisplayNames(
            text: subtitle,
            modelContext: modelContext
        )
        display = MentionParser.stripTerminators(from: display)
        
        // Remove lingering structured patterns and extra whitespace
        let structuredPattern = #"@\{[^}]+\}"#
        display = display.replacingOccurrences(of: structuredPattern, with: "", options: .regularExpression)
        display = display.replacingOccurrences(of: "  ", with: " ")
        display = display.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return display.isEmpty ? "No description available" : display
    }
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Icon in circular background - smaller, more compact
                Image(systemName: result.type.icon)
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
                
                // Result info
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(1)
                    
                    Text(cleanSubtitle(result.subtitle))
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(glassColorSystem.textSecondary())
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Type badge
                Text(result.type.rawValue.capitalized)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                    )
                    .overlay(
                        Capsule()
                            .stroke(glassColorSystem.glassTint(for: .surface).opacity(0.3), lineWidth: 0.5)
                    )
                
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

