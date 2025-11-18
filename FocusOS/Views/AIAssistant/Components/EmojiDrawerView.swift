//
//  EmojiDrawerView.swift
//  FocusOS
//
//  Emoji picker drawer matching MentionDrawerView glassmorphic design.
//

import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

struct EmojiDrawerView: View {
    let filteredKeyword: String?
    let searchQuery: String
    let onSelect: (String) -> Void
    let arteGradientColors: [Color]
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategoryIndex = 0
    @State private var hoveredEmoji: String? = nil
    @State private var hoveredEmojiPosition: CGPoint? = nil
    @State private var displayedEmojis: [String] = []
    @State private var debounceSearch = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    private let emojiService = EmojiService.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Text("Emojis")
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
            
            // Search field (read-only display)
            if !searchQuery.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    Text(searchQuery)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                )
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            
            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(emojiService.allCategories.enumerated()), id: \.offset) { index, category in
                        Button {
                            selectedCategoryIndex = index
                            updateDisplayedEmojis()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 16, weight: .medium))
                                Text(category.name)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(
                                selectedCategoryIndex == index
                                ? glassColorSystem.textPrimary()
                                : glassColorSystem.textSecondary()
                            )
                            .frame(width: 60, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        selectedCategoryIndex == index
                                        ? glassColorSystem.glassTint(for: .accent).opacity(0.2)
                                        : glassColorSystem.glassTint(for: .surface).opacity(0.1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 8)
            
            // Emoji grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(displayedEmojis, id: \.self) { emoji in
                        EmojiCell(
                            emoji: emoji,
                            isHovered: hoveredEmoji == emoji,
                            onSelect: {
                                onSelect(emoji)
                            },
                            onHover: { hovering, position in
                                if hovering {
                                    hoveredEmoji = emoji
                                    hoveredEmojiPosition = position
                                } else if hoveredEmoji == emoji {
                                    hoveredEmoji = nil
                                    hoveredEmojiPosition = nil
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .coordinateSpace(name: "emojiGrid")
            }
            .background(glassColorSystem.backgroundColor())
            .overlay(alignment: .topLeading) {
                if let hoveredEmoji = hoveredEmoji, let position = hoveredEmojiPosition {
                    EmojiMagnifierView(emoji: hoveredEmoji)
                        .position(x: position.x, y: max(50, position.y - 50))
                }
            }
        }
        .background(glassColorSystem.backgroundColor())
        .frame(height: 400)
        .onAppear {
            setupDebounce()
            updateDisplayedEmojis()
        }
        .onChange(of: searchQuery) { newValue in
            debounceSearch.send(newValue)
        }
        .onChange(of: filteredKeyword) { _ in
            updateDisplayedEmojis()
        }
        .onChange(of: selectedCategoryIndex) { _ in
            updateDisplayedEmojis()
        }
    }
    
    private func setupDebounce() {
        debounceSearch
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [self] query in
                updateDisplayedEmojis()
            }
            .store(in: &cancellables)
    }
    
    private func updateDisplayedEmojis() {
        if let keyword = filteredKeyword, !keyword.isEmpty {
            // Use filtered keyword from autocomplete
            displayedEmojis = emojiService.emojis(forKeyword: keyword)
        } else if !searchQuery.isEmpty {
            // Use search query
            displayedEmojis = emojiService.search(searchQuery)
        } else {
            // Show selected category
            let categories = emojiService.allCategories
            if selectedCategoryIndex < categories.count {
                displayedEmojis = categories[selectedCategoryIndex].emojis
            } else {
                displayedEmojis = []
            }
        }
        
        // If no emojis found and we have a search query, show empty state
        if displayedEmojis.isEmpty && (!searchQuery.isEmpty || filteredKeyword != nil) {
            displayedEmojis = []
        }
    }
}

private struct EmojiCell: View {
    let emoji: String
    let isHovered: Bool
    let onSelect: () -> Void
    let onHover: (Bool, CGPoint) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var localPosition: CGPoint = .zero
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isHovered
                            ? glassColorSystem.glassTint(for: .surface).opacity(0.3)
                            : Color.clear
                        )
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.16, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: EmojiPositionPreferenceKey.self,
                        value: CGPoint(
                            x: geometry.frame(in: .named("emojiGrid")).midX,
                            y: geometry.frame(in: .named("emojiGrid")).minY
                        )
                    )
            }
        )
        .onPreferenceChange(EmojiPositionPreferenceKey.self) { position in
            localPosition = position
        }
        .onHover { hovering in
            onHover(hovering, localPosition)
        }
    }
}

private struct EmojiPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

private struct EmojiMagnifierView: View {
    let emoji: String
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 48))
                .scaleEffect(scale)
            
            Text(emoji)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.16, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
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

