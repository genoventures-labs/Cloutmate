//
//  CalendarDayDetailDrawer.swift
//  Cloutmate
//
//  Drawer listing calendar items for a specific day
//

import SwiftUI
import CloutmateShared

struct CalendarDayDetailDrawer: View {
    struct Item: Identifiable {
        enum Kind {
            case post(CloutmateShared.Post)
            case artifact(CloutmateShared.Artifact)
            case task(CloutmateShared.Task)
        }
        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        let accent: Color
        let timestamp: Date?
    }
    
    let date: Date
    let items: [Item]
    @Binding var isPresented: Bool
    let onSelect: (Item.Kind) -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var headerFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                accentSidebar
                
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if items.isEmpty {
                                ContentUnavailableView(
                                    "No items",
                                    systemImage: "calendar",
                                    description: Text("Nothing scheduled for this day")
                                )
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 80)
                            } else {
                                ForEach(items) { item in
                                    Button {
                                        onSelect(item.kind)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: item.icon)
                                                .foregroundColor(item.accent)
                                                .frame(width: 28, height: 28)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.title)
                                                    .font(.body)
                                                    .foregroundColor(glassColorSystem.textPrimary())
                                                Text(item.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(glassColorSystem.textSecondary())
                                            }
                                            
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        .padding()
                                        .background(glassColorSystem.cardColor())
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(24)
                    }
                    .background(Color(.windowBackgroundColor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .frame(minWidth: 400, minHeight: 480)
        .frame(idealWidth: 520, idealHeight: 560)
    }
    
    private var accentSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.kosmicBlue.opacity(0.8), .kosmicPurple.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headerFormatter.string(from: date))
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text("\(items.count) item\(items.count == 1 ? "" : "s") scheduled")
                .font(.caption)
                .foregroundColor(glassColorSystem.textSecondary())
        }
    }
}

extension CalendarDayDetailDrawer.Item {
    static func post(_ post: CloutmateShared.Post) -> CalendarDayDetailDrawer.Item {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let timestamp = post.scheduledDate ?? post.publishedDate
        let subtitle = timestamp.map { dateFormatter.string(from: $0) } ?? "No schedule"
        return CalendarDayDetailDrawer.Item(
            kind: .post(post),
            title: post.caption.isEmpty ? "Untitled Post" : post.caption,
            subtitle: subtitle,
            icon: "paperplane.fill",
            accent: .kosmicBlue,
            timestamp: timestamp
        )
    }
    
    static func artifact(_ artifact: CloutmateShared.Artifact) -> CalendarDayDetailDrawer.Item {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let timestamp = artifact.publishedAt ?? artifact.createdAt
        let subtitle = dateFormatter.string(from: timestamp)
        return CalendarDayDetailDrawer.Item(
            kind: .artifact(artifact),
            title: artifact.title.isEmpty ? "Untitled Artifact" : artifact.title,
            subtitle: subtitle,
            icon: "sparkles",
            accent: .kosmicPurple,
            timestamp: artifact.publishedAt ?? Optional(artifact.createdAt)
        )
    }
    
    static func task(_ task: CloutmateShared.Task) -> CalendarDayDetailDrawer.Item {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let timestamp = task.dueDate
        let subtitle = timestamp.map { dateFormatter.string(from: $0) } ?? "No due date"
        return CalendarDayDetailDrawer.Item(
            kind: .task(task),
            title: task.title.isEmpty ? "Untitled Task" : task.title,
            subtitle: subtitle,
            icon: task.status == .done ? "checkmark.circle.fill" : "circle",
            accent: task.status == .done ? .kosmicGreen : .orange,
            timestamp: timestamp
        )
    }
}
