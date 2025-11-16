//
//  CalendarHeaderView.swift
//  Cloutmate
//
//  Calendar V2 - Centered header with smooth transitions
//

import SwiftUI

struct CalendarHeaderView: View {
    let title: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    @State private var isHoveredPrevious = false
    @State private var isHoveredNext = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Previous button
            GlassButton(
                icon: "chevron.left",
                style: .iconOnly,
                tintColor: .kosmicBlue,
                action: onPrevious
            )
            .frame(width: 32, height: 32)
            .scaleEffect(isHoveredPrevious ? 1.1 : 1.0)
            .opacity(isHoveredPrevious ? 0.8 : 1.0)
            .onHover { hovering in
                withAnimation(GlassMotion.Easing.spring) {
                    isHoveredPrevious = hovering
                }
            }
            
            Spacer()
            
            // Centered title
            Text(title)
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.kosmicBlue, .kosmicPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
            
            // Next button
            GlassButton(
                icon: "chevron.right",
                style: .iconOnly,
                tintColor: .kosmicBlue,
                action: onNext
            )
            .frame(width: 32, height: 32)
            .scaleEffect(isHoveredNext ? 1.1 : 1.0)
            .opacity(isHoveredNext ? 0.8 : 1.0)
            .onHover { hovering in
                withAnimation(GlassMotion.Easing.spring) {
                    isHoveredNext = hovering
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    CalendarHeaderView(
        title: "November 2025",
        onPrevious: {},
        onNext: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

