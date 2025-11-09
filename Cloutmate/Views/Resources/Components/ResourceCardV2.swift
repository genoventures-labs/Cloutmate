//
//  ResourceCardV2.swift
//  Cloutmate
//
//  Resources V2 - Gallery Card System
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ResourceCardV2: View {
    let note: Note
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    
    private var typeColor: Color {
        switch note.type {
        case .note, .reference:
            return .kosmicBlue
        case .video, .podcast:
            return .kosmicPurple
        case .book:
            return .kosmicGreen
        case .article, .link:
            return .kosmicYellow
        case .idea:
            return .kosmicPurple
        }
    }
    
    private var typeIcon: String {
        switch note.type {
        case .note: return "doc.text"
        case .article: return "newspaper"
        case .video: return "play.rectangle"
        case .book: return "book"
        case .podcast: return "waveform"
        case .link: return "link"
        case .idea: return "lightbulb"
        case .reference: return "doc.append"
        }
    }
    
    private var subtitleText: String {
        if let source = note.source, !source.isEmpty {
            if source.hasPrefix("http") {
                return "Saved from \(URL(string: source)?.host ?? "web")"
            }
            return source
        }
        return note.type.rawValue
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left Edge Gradient Bar
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            colors: [typeColor.opacity(0.8), typeColor.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Cover/Thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        typeColor.opacity(0.2),
                                        typeColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 100)
                        
                        Image(systemName: typeIcon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(typeColor.opacity(0.6))
                    }
                    
                    // Body
                    VStack(alignment: .leading, spacing: 10) {
                        // Title
                        Text(note.title)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Subtitle
                        Text(subtitleText)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.top, 2)
                        
                        // Tags Row
                        if !note.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(.caption2, design: .rounded))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(typeColor.opacity(0.15))
                                            )
                                            .foregroundColor(typeColor)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Footer
                    HStack {
                        Text(note.createdAt, style: .relative)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Aurora recommendation badge (placeholder for now)
                        if note.tags.contains("AI") || note.tags.contains("Study") {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8))
                                Text("Recommended")
                                    .font(.system(.caption2, design: .rounded))
                            }
                            .foregroundColor(.kosmicPurple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.kosmicPurple.opacity(0.1))
                            )
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glassColorSystem.cardColor())
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isHovered ? typeColor.opacity(0.4) : glassColorSystem.borderColor(),
                            lineWidth: isHovered ? 2 : 1
                        )
                )
                .shadow(
                    color: isHovered ? typeColor.opacity(0.15) : Color.black.opacity(0.05),
                    radius: isHovered ? 8 : 3,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
        )
        .scaleEffect(reduceMotion ? 1.0 : (isHovered ? 1.02 : 1.0))
        .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("\(note.title), \(note.type.rawValue) resource")
        .accessibilityHint("Double tap to open resource details")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: config)
    let note = Note(title: "Sample Resource", markdown: "This is a sample resource", type: .article)
    note.tags = ["Study", "Design", "Technical"]
    
    return HStack {
        ResourceCardV2(note: note, onTap: {})
            .frame(width: 280)
    }
    .padding()
    .environmentObject(GlassColorSystem())
    .modelContainer(container)
}

