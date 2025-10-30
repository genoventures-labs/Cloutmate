//
//  GlassCalendarDayCell.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Floating Glass Calendar Capsule
//

import SwiftUI
import CloutmateShared

struct GlassCalendarDayCell: View {
    let date: Date
    let posts: [CloutmateShared.Post]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    var onPostClick: ((CloutmateShared.Post) -> Void)?
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    
    @State private var isHovered = false
    @State private var refractionPhase: CGFloat = 0
    @State private var showMorph = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, minHeight: 60)
            .glassPanel(tier: .overlay, cornerRadius: 12, tintColor: tintColor)
            .overlay(countBadgeOverlay)
            .overlay(refractionOverlay)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            .scaleEffect(isHovered || showMorph ? 1.05 : 1.0)
            .overlay(morphOverlay)
            .animation(GlassMotion.Easing.spring, value: isHovered)
            .animation(GlassMotion.Easing.spring, value: showMorph)
            .onHover { hovering in isHovered = hovering }
            .onTapGesture { onSelect() }
            .onTapGesture(count: 2) {
                showMorph = true
                withAnimation(Animation.easeOut(duration: 0.2)) {
                    showMorph = false
                }
                onDoubleClick()
            }
            .onAppear {
                if isToday {
                    withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                        refractionPhase = 200
                    }
                }
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 4) {
            Text(dayText)
                .font(.system(.subheadline, design: .rounded, weight: isToday ? .bold : .medium))
                .foregroundColor(textColor)
            
            if !posts.isEmpty {
                postIndicators
            }
        }
    }
    
    private var postIndicators: some View {
        HStack(spacing: 3) {
            ForEach(Array(posts.prefix(3)), id: \.id) { post in
                ZStack {
                    Circle()
                        .fill(indicatorColor(for: post))
                        .frame(width: 5, height: 5)
                    if posts.count == 1 {
                        if post.postStatus == .published {
                            Image(systemName: "checkmark")
                                .font(.system(size: 4))
                                .foregroundColor(.white)
                        } else if post.postStatus == .scheduled {
                            Image(systemName: "clock")
                                .font(.system(size: 4))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            if posts.count > 3 {
                Text("+\(posts.count - 3)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.8))
                            .blur(radius: 2)
                    )
            }
        }
    }
    
    private var countBadgeOverlay: some View {
        Group {
            if posts.count > 1 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(posts.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            )
                            .offset(x: -4, y: 4)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var refractionOverlay: some View {
        Group {
            if isToday {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: refractionPhase - 60)
                    .blendMode(.overlay)
            }
        }
    }
    
    private var morphOverlay: some View {
        Group {
            if showMorph {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.3))
                    .blur(radius: 20)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var dayText: String {
        calendar.component(.day, from: date).description
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isToday {
            return .blue
        } else if isSelected {
            return .primary
        } else {
            return .primary.opacity(0.8)
        }
    }
    
    private var tintColor: Color? {
        if isToday {
            return .blue.opacity(0.15)
        } else if isSelected {
            return .blue.opacity(0.1)
        } else {
            return nil
        }
    }
    
    private var shadowColor: Color {
        if isToday {
            return .blue.opacity(0.3)
        } else if isSelected {
            return .blue.opacity(0.2)
        } else {
            return .black.opacity(0.05)
        }
    }
    
    private var shadowRadius: CGFloat {
        if isToday || isSelected {
            return 8
        } else {
            return 2
        }
    }
    
    private var shadowY: CGFloat {
        if isToday || isSelected {
            return 4
        } else {
            return 1
        }
    }
    
    private func indicatorColor(for post: CloutmateShared.Post) -> Color {
        switch post.postStatus {
        case .scheduled: return .blue
        case .published: return .green
        case .failed: return .red
        case .publishing: return .orange
        case .draft: return .gray
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        GlassCalendarDayCell(
            date: Date(),
            posts: [],
            isSelected: false,
            isToday: true,
            isCurrentMonth: true,
            onSelect: {},
            onDoubleClick: {}
        )
        
        GlassCalendarDayCell(
            date: Date().addingTimeInterval(86400),
            posts: [],
            isSelected: true,
            isToday: false,
            isCurrentMonth: true,
            onSelect: {},
            onDoubleClick: {}
        )
        
        GlassCalendarDayCell(
            date: Date().addingTimeInterval(172800),
            posts: [],
            isSelected: false,
            isToday: false,
            isCurrentMonth: true,
            onSelect: {},
            onDoubleClick: {}
        )
    }
    .padding()
}
