//
//  SelectionActionBar.swift
//  FocusOS
//
//  Shared floating bar for multi-select bulk actions with glass styling
//

import SwiftUI

struct SelectionActionBar: View {
    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        var role: GlassColorSystem.GlassRole = .accent
        let action: () -> Void
    }
    
    let count: Int
    let itemLabel: String
    let actions: [Action]
    let onCancel: () -> Void
    let onSelectAll: (() -> Void)?
    let totalItems: Int?
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var selectionText: String {
        if count == 0 {
            return "Selection mode active"
        }
        let pluralized = count == 1 ? itemLabel : "\(itemLabel)s"
        return "\(count) \(pluralized) selected"
    }
    
    private var instructionText: String {
        if count == 0 {
            return "Tap items to select or use Select All"
        }
        return "Choose an action or press Esc to cancel"
    }
    
    var body: some View {
        GlassPanel(tier: .floatingAction, cornerRadius: 20) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectionText)
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(glassColorSystem.textPrimary())
                        
                        Text(instructionText)
                            .font(.caption)
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                    
                    Spacer()
                    
                    GlassButton(icon: "xmark.circle.fill", style: .iconOnly, role: .surface) {
                        withAnimation(barAnimation) {
                            onCancel()
                        }
                    }
                    .accessibilityLabel("Cancel selection")
                }
                
                Divider()
                    .foregroundColor(glassColorSystem.dividerColor())
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Select All / Deselect All button
                        if let onSelectAll = onSelectAll, let totalItems = totalItems {
                            let allSelected = count >= totalItems && totalItems > 0
                            GlassButton(
                                allSelected ? "Deselect All" : "Select All",
                                icon: allSelected ? "circle" : "checkmark.circle",
                                style: .pill,
                                role: .surface
                            ) {
                                withAnimation(barAnimation) {
                                    onSelectAll()
                                }
                            }
                            .accessibilityLabel(allSelected ? "Deselect all items" : "Select all items")
                        }
                        
                        // Only show other actions when items are selected
                        if count > 0 {
                            ForEach(actions) { action in
                                GlassButton(action.title, icon: action.icon, style: .pill, role: action.role) {
                                    withAnimation(barAnimation) {
                                        action.action()
                                    }
                                }
                                .accessibilityLabel(action.title)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(barAnimation, value: count)
    }
    
    private var barAnimation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.35, dampingFraction: 0.8)
    }
}

// MARK: - Selection Indicator

struct SelectionIndicator: View {
    let isSelected: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(
                isSelected ?
                AnyShapeStyle(LinearGradient(
                    colors: [.kosmicBlue, .kosmicPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )) :
                AnyShapeStyle(glassColorSystem.textSecondary())
            )
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}


