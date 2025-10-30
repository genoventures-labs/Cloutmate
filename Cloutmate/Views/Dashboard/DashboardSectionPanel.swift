//
//  DashboardSectionPanel.swift
//  Cloutmate
//
//  Collapsible glass section panel matching Insights styling
//

import SwiftUI

struct DashboardSectionPanel<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    @Binding var isCollapsed: Bool
    private let content: () -> Content

    init(
        title: String,
        icon: String,
        accent: Color,
        isCollapsed: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self._isCollapsed = isCollapsed
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isCollapsed {
                collapsedCard
                    .transition(.opacity.combined(with: .scale))
            } else {
                GlassPanel(tier: .contentCard, cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        content()
                    }
                    .padding(20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isCollapsed)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .foregroundColor(accent)
                    .imageScale(.medium)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .sectionTitleStyle()
                if isCollapsed {
                    Text("Section collapsed")
                        .metricLabelStyle()
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isCollapsed ? 180 : 0))
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
                    .accessibilityLabel(isCollapsed ? "Expand section" : "Collapse section")
            }
            .buttonStyle(.plain)
        }
    }

    private var collapsedCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(accent.opacity(0.08))
            .frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.2), lineWidth: 1)
            )
            .overlay(
                HStack(spacing: 10) {
                    Image(systemName: "arrow.uturn.down.circle.fill")
                        .foregroundColor(accent)
                    Text("Tap the chevron to reopen this section.")
                        .metricLabelStyle()
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
            )
    }
}
