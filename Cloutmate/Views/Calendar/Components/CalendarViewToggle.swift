//
//  CalendarViewToggle.swift
//  Cloutmate
//
//  Calendar V2 - Pill-style toggle for Monthly/Weekly views
//

import SwiftUI

struct CalendarViewToggle: View {
    @Binding var isWeeklyView: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        HStack(spacing: 0) {
            // Monthly button
            Button(action: {
                withAnimation(GlassMotion.Easing.spring) {
                    isWeeklyView = false
                }
            }) {
                Text("Monthly")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isWeeklyView ? .secondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        Group {
                            if !isWeeklyView {
                                // Selected state
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.kosmicPurple.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.kosmicPurple.opacity(0.5), Color.kosmicPurple.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                            } else {
                                // Unselected state
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.clear)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
            
            // Weekly button
            Button(action: {
                withAnimation(GlassMotion.Easing.spring) {
                    isWeeklyView = true
                }
            }) {
                Text("Weekly")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isWeeklyView ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        Group {
                            if isWeeklyView {
                                // Selected state
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.kosmicPurple.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.kosmicPurple.opacity(0.5), Color.kosmicPurple.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                            } else {
                                // Unselected state
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.clear)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(glassColorSystem.cardColor())
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    @Previewable @State var isWeekly = false
    
    CalendarViewToggle(isWeeklyView: $isWeekly)
        .padding()
        .environmentObject(GlassColorSystem())
}

