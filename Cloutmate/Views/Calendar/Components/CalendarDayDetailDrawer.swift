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
            case event(CalendarEventOccurrence)
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
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var hoveredItemID: UUID?
    
    private var headerFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme, start: .top, end: .bottom),
            accentWidth: 8,
            showsSidebar: false,
            sidebarWidth: 0,
            header: { headerContent },
            content: { drawerContent },
            sidebar: { EmptyView() }
        )
        .frame(minWidth: 560, idealWidth: 620, idealHeight: 560)
        .background(glassColorSystem.backgroundColor())
        .onEscape {
            closeDrawer()
        }
    }
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerFormatter.string(from: date))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Text("\(items.count) item\(items.count == 1 ? "" : "s") scheduled")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(glassColorSystem.textSecondary().opacity(0.85))
                }
                
                headerChips
            }
            
            Spacer()
            
            GlassButton(icon: "xmark", style: .iconOnly, role: .surface, tintColor: glassColorSystem.backgroundSecondary())
            {
                closeDrawer()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        if sections.isEmpty {
            DrawerSection(title: "Nothing Scheduled", icon: "calendar") {
                ContentUnavailableView(
                    "No items",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("There are no events, tasks, artifacts, or posts scheduled for this day.")
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            }
        } else {
            ForEach(sections) { section in
                DrawerSection(
                    title: section.kind.title,
                    icon: section.kind.icon,
                    subtitle: section.kind.subtitle(for: section.items.count)
                ) {
                    VStack(spacing: 12) {
                        ForEach(section.items) { item in
                            itemRow(item)
                        }
                    }
                }
            }
        }
    }
    
    private func itemRow(_ item: Item) -> some View {
        let isHovered = hoveredItemID == item.id
        
        return Button {
            onSelect(item.kind)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.accent.opacity(isHovered ? 0.22 : 0.18))
                        .frame(width: 44, height: 44)
                        .shadow(color: item.accent.opacity(isHovered ? 0.45 : 0.2), radius: isHovered ? 10 : 6, y: isHovered ? 5 : 3)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(glassColorSystem.textPrimary())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(2)
                    
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary().opacity(0.85))
                        .lineLimit(2)
                }
                
                Spacer()
                
                if let timestamp = timestampText(for: item) {
                    Text(timestamp)
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(glassColorSystem.backgroundSecondary().opacity(0.26))
                                .overlay(
                                    Capsule()
                                        .stroke(glassColorSystem.backgroundSecondary().opacity(0.32), lineWidth: 1)
                                )
                        )
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(glassColorSystem.backgroundSecondary().opacity(isHovered ? 0.32 : 0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        item.accent.opacity(isHovered ? 0.55 : 0.32),
                                        item.accent.opacity(isHovered ? 0.28 : 0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : nil
        }
    }
    
    private func timestampText(for item: Item) -> String? {
        guard let timestamp = item.timestamp else { return nil }
        if Calendar.current.isDate(timestamp, inSameDayAs: date) {
            return Self.timeFormatter.string(from: timestamp)
        }
        return Self.dateTimeFormatter.string(from: timestamp)
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    @ViewBuilder
    private var headerChips: some View {
        HStack(spacing: 10) {
            headerChip(
                icon: "square.grid.2x2",
                text: "\(items.count) total",
                tint: glassColorSystem.glassTint(for: .primary)
            )
            
            if count(for: .events) > 0 {
                headerChip(icon: "calendar", text: "\(count(for: .events)) events", tint: .cyan)
            }
            if count(for: .tasks) > 0 {
                headerChip(icon: "checkmark.circle", text: "\(count(for: .tasks)) tasks", tint: .kosmicGreen)
            }
            if count(for: .artifacts) > 0 {
                headerChip(icon: "sparkles", text: "\(count(for: .artifacts)) artifacts", tint: .kosmicPurple)
            }
            if count(for: .posts) > 0 {
                headerChip(icon: "paperplane.fill", text: "\(count(for: .posts)) posts", tint: .kosmicBlue)
            }
        }
    }
    
    private func headerChip(icon: String, text: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: icon)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
        .foregroundStyle(glassColorSystem.textPrimary())
    }
    
    private func count(for kind: SectionKind) -> Int {
        sections.first(where: { $0.kind == kind })?.items.count ?? 0
    }
    
    private var sections: [ItemSection] {
        var grouped: [SectionKind: [Item]] = [:]
        
        for item in items {
            if let kind = SectionKind(itemKind: item.kind) {
                grouped[kind, default: []].append(item)
            }
        }
        
        return SectionKind.allCases.compactMap { kind in
            guard var collected = grouped[kind] else { return nil }
            collected.sort { (lhs, rhs) -> Bool in
                let lhsDate = lhs.timestamp ?? date
                let rhsDate = rhs.timestamp ?? date
                return lhsDate < rhsDate
            }
            return ItemSection(kind: kind, items: collected)
        }
    }
    
    // MARK: - Formatters
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ItemSection: Identifiable {
    let id = UUID()
    let kind: SectionKind
    let items: [CalendarDayDetailDrawer.Item]
}

private enum SectionKind: CaseIterable {
    case events
    case tasks
    case artifacts
    case posts
    
    init?(itemKind: CalendarDayDetailDrawer.Item.Kind) {
        switch itemKind {
        case .event:
            self = .events
        case .task:
            self = .tasks
        case .artifact:
            self = .artifacts
        case .post:
            self = .posts
        }
    }
    
    var title: String {
        switch self {
        case .events: return "Events"
        case .tasks: return "Tasks"
        case .artifacts: return "Artifacts"
        case .posts: return "Posts"
        }
    }
    
    var icon: String {
        switch self {
        case .events: return "calendar"
        case .tasks: return "checkmark.circle"
        case .artifacts: return "sparkles"
        case .posts: return "paperplane.fill"
        }
    }
    
    func subtitle(for count: Int) -> String {
        let label: String
        switch self {
        case .events: label = count == 1 ? "Event" : "Events"
        case .tasks: label = count == 1 ? "Task" : "Tasks"
        case .artifacts: label = count == 1 ? "Artifact" : "Artifacts"
        case .posts: label = count == 1 ? "Post" : "Posts"
        }
        return "\(count) \(label)"
    }
}

extension CalendarDayDetailDrawer.Item {
    static func event(_ occurrence: CalendarEventOccurrence) -> CalendarDayDetailDrawer.Item {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        
        let subtitle: String
        if occurrence.event.allDay {
            subtitle = "All-day"
        } else {
            let start = dateFormatter.string(from: occurrence.startDate)
            let end = dateFormatter.string(from: occurrence.endDate)
            subtitle = "\(start) – \(end)"
        }
        
        return CalendarDayDetailDrawer.Item(
            kind: .event(occurrence),
            title: occurrence.event.title.isEmpty ? "Untitled Event" : occurrence.event.title,
            subtitle: subtitle,
            icon: "calendar",
            accent: .cyan,
            timestamp: occurrence.startDate
        )
    }
    
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
