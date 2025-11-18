//
//  JournalCardV2.swift
//  FocusOS
//
//  Modern journal card component for Journal V2 redesign
//

import SwiftUI
import SwiftData
import FocusOSShared

struct JournalCardV2: View {
    @Bindable var journal: Journal
    let selectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var excerptText: String {
        let lines = journal.content.components(separatedBy: .newlines)
        let firstFiveLines = Array(lines.prefix(5)).joined(separator: "\n")
        return firstFiveLines.isEmpty ? "No content" : firstFiveLines
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: journal.entryDate)
    }
    
    private var tagBadgeText: String {
        // Determine tag based on entry type or time of day
        if journal.journalEntryType == .reflection {
            let hour = Calendar.current.component(.hour, from: journal.entryDate)
            if hour >= 5 && hour < 12 {
                return "Morning"
            } else if hour >= 17 && hour < 22 {
                return "Evening"
            } else {
                return "Reflection"
            }
        } else {
            return journal.journalEntryType.rawValue
        }
    }
    
    private var moodColor: Color {
        switch journal.journalMood {
        case .excited: return .orange
        case .grateful: return .yellow
        case .reflective: return .kosmicBlue
        case .motivated: return .kosmicGreen
        case .contemplative: return .kosmicPurple
        case .creative: return .pink
        case .frustrated: return .red
        case .calm: return .cyan
        case .none: return .gray
        }
    }
    
    private var accentGradient: LinearGradient {
        // Left-edge gradient bar based on mood and emotional tone
        switch journal.journalMood {
        case .motivated, .grateful, .excited:
            // Positive/accomplished - green to blue
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .top,
                endPoint: .bottom
            )
        case .creative, .contemplative:
            // Creative - purple
            return LinearGradient(
                colors: [.kosmicPurple, .kosmicPurple.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .reflective, .calm:
            // Focused - blue
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicBlue.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            // Neutral/default
            return LinearGradient(
                colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var sentimentTone: String {
        // TODO: Integrate with ARTE for actual sentiment percentage
        // For now, use mood as proxy
        if journal.journalMood != .none {
            return "\(journal.journalMood.rawValue) • 84%"
        }
        return "Neutral • 50%"
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                moodColor.opacity(0.6),
                moodColor.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .center, spacing: 12) {
                    // Left-edge accent indicator
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accentGradient)
                        .frame(width: 3)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 10) {
                            Text(journal.title.isEmpty ? "Untitled Entry" : journal.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                                .lineLimit(1)
                            
                            if journal.author == .aurora {
                                AuroraAuthorBadge()
                            }
                            
                            Spacer()
                            
                            // Tag badge
                            Text(tagBadgeText)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(glassColorSystem.emotionalAccent().opacity(0.18))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(glassColorSystem.emotionalAccent().opacity(0.35), lineWidth: 0.8)
                                )
                                .foregroundStyle(glassColorSystem.emotionalAccent())
                        }
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11, weight: .medium))
                                Text(dateText)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(glassColorSystem.textSecondary())
                            
                            HStack(spacing: 4) {
                                Image(systemName: moodIcon)
                                    .font(.system(size: 11, weight: .medium))
                                Text(journal.journalMood.rawValue.capitalized)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(moodColor)
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                .onTapGesture(count: 2, perform: onEdit)
                .onHover { hovering in
                    guard !selectionMode else {
                        isHovered = hovering
                        return
                    }
                    if reduceMotion {
                        isHovered = hovering
                    } else {
                        withAnimation(GlassMotion.Easing.spring) {
                            isHovered = hovering
                        }
                    }
                }
                
                // Body: Excerpt
                if !journal.content.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .background(glassColorSystem.borderColor().opacity(0.3))
                        
                        Text(excerptText)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 18)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .black, location: 0),
                                        .init(color: .black, location: 0.85),
                                        .init(color: .clear, location: 1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: isSelected ? 1.6 : 0.6)
                .animation(GlassMotion.Easing.spring, value: isSelected)
        )
        .shadow(
            color: moodColor.opacity(isHovered ? 0.22 : 0.12),
            radius: isHovered ? 18 : 12,
            x: 0,
            y: isHovered ? 12 : 6
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(GlassMotion.Easing.spring, value: isHovered)
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .padding(12)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
        }
        .contextMenu {
            if !selectionMode {
                Button("Edit") {
                    onEdit()
                }
                Button("Duplicate") {
                    onDuplicate()
                }
                Button("Export") {
                    onExport()
                }
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
        .accessibilityLabel("Journal entry: \(journal.title.isEmpty ? "Untitled" : journal.title)")
        .accessibilityHint("Double tap to open")
        .accessibilityValue("\(dateText), \(tagBadgeText)")
        .onChange(of: selectionMode) { _, newValue in
            if newValue {
                isHovered = false
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    private var moodIcon: String {
        switch journal.journalMood {
        case .excited: return "sparkles"
        case .grateful: return "heart.fill"
        case .reflective: return "brain.head.profile"
        case .motivated: return "bolt.fill"
        case .contemplative: return "moon.fill"
        case .creative: return "paintbrush.fill"
        case .frustrated: return "exclamationmark.triangle.fill"
        case .calm: return "leaf.fill"
        case .none: return "circle.fill"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        JournalCardV2(
            journal: {
                let journal = Journal(
                    title: "Morning Reflection",
                    content: "Today I intend to focus on deep work and complete the project proposal. I'm feeling motivated and ready to tackle the challenges ahead.\n\nI want to make sure I take breaks and stay hydrated throughout the day.",
                    entryDate: Date(),
                    entryType: .reflection,
                    mood: .motivated
                )
                return journal
            }(),
            selectionMode: false,
            isSelected: false,
            onSelectionToggle: {},
            onTap: {},
            onEdit: {},
            onDuplicate: {},
            onExport: {},
            onDelete: {}
        )
        
        JournalCardV2(
            journal: {
                let journal = Journal(
                    title: "Evening Reflection",
                    content: "Today I learned that taking breaks actually improves my productivity. I completed more tasks than expected and felt less stressed.",
                    entryDate: Date(),
                    entryType: .reflection,
                    mood: .grateful
                )
                return journal
            }(),
            selectionMode: true,
            isSelected: true,
            onSelectionToggle: {},
            onTap: {},
            onEdit: {},
            onDuplicate: {},
            onExport: {},
            onDelete: {}
        )
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

