//
//  JournalCardV2.swift
//  Cloutmate
//
//  Modern journal card component for Journal V2 redesign
//

import SwiftUI
import SwiftData
import CloutmateShared

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
    
    var body: some View {
        HStack(spacing: 0) {
            // Left-edge gradient bar (accent indicator)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accentGradient)
                .frame(width: 4)
            
            // Main card content
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header: Date + tag badge
                    HStack(alignment: .center, spacing: 8) {
                        Text(dateText)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    
                    if journal.author == .aurora {
                        AuroraAuthorBadge()
                    }
                        
                        Spacer()
                        
                        // Tag badge
                        Text(tagBadgeText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [.kosmicBlue.opacity(0.2), .kosmicPurple.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.kosmicPurple)
                            .cornerRadius(6)
                    }
                    
                    // Body: Excerpt with fade gradient
                    Text(excerptText)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
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
                    
                    // Footer: Mood icon + sentiment tone
                    HStack(spacing: 6) {
                        Image(systemName: moodIcon)
                            .font(.caption)
                            .foregroundColor(moodColor)
                        
                        Text(sentimentTone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding(16)
                .frame(minHeight: 56)
            }
        }
        .floatLift()
        .shadow(
            color: isHovered ? .kosmicPurple.opacity(0.15) : .black.opacity(0.05),
            radius: isHovered ? 8 : 2,
            x: 0,
            y: isHovered ? 4 : 1
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isSelected ? [.kosmicBlue, .kosmicPurple] : [.clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                SelectionIndicator(isSelected: isSelected)
                    .padding(10)
                    .onTapGesture {
                        onSelectionToggle()
                    }
            }
        }
        .onTapGesture {
            if selectionMode {
                onSelectionToggle()
            } else {
                onTap()
            }
        }
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
        .accessibilityValue("\(dateText), \(tagBadgeText), \(sentimentTone)")
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

