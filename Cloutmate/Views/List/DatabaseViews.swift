//
//  DatabaseViews.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct DatabaseViewPicker: View {
    @Binding var selectedView: ViewType
    var onManageProperties: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Picker("View", selection: $selectedView) {
                Text("Table").tag(ViewType.table)
                Text("Kanban").tag(ViewType.kanban)
                Text("Gallery").tag(ViewType.gallery)
                Text("Timeline").tag(ViewType.timeline)
            }
            .pickerStyle(.segmented)
            
            Spacer()
            
            if let onManageProperties {
                Button(action: onManageProperties) {
                    Label("Manage Properties", systemImage: "slider.horizontal.3")
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Kanban View

struct KanbanBoardView: View {
    let posts: [Post]
    
    private let columns: [(PostStatus, String, Color)] = [
        (.draft, "Draft", .gray),
        (.scheduled, "Scheduled", .orange),
        (.publishing, "Publishing", .kosmicPurple),
        (.published, "Published", .kosmicGreen),
        (.failed, "Failed", .red)
    ]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns, id: \.0) { column in
                    KanbanColumnView(
                        title: column.1,
                        color: column.2,
                        posts: posts.filter { $0.postStatus == column.0 }
                    )
                    .frame(width: 240)
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
}

private struct KanbanColumnView: View {
    let title: String
    let color: Color
    let posts: [Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(posts.count)")
                    .font(.caption)
                    .padding(6)
                    .background(color.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            VStack(spacing: 12) {
                ForEach(posts) { post in
                    KanbanCard(post: post, color: color)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(.thinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

private struct KanbanCard: View {
    let post: Post
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.caption.prefix(120) + (post.caption.count > 120 ? "..." : ""))
                .font(.subheadline)
                .lineLimit(4)
            
            HStack(spacing: 6) {
                ForEach(post.postPlatforms, id: \.self) { platform in
                    Text(platform.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            if let date = post.scheduledDate ?? post.publishedDate {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }
}

// MARK: - Gallery View

struct PostGalleryView: View {
    let posts: [Post]
    
    let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(posts) { post in
                    VStack(alignment: .leading, spacing: 10) {
                        if let firstMedia = post.mediaURLs.first {
                            let url = URL(mediaPath: firstMedia)
                            if let url = url {
                                if url.isFileURL, let nsImage = NSImage(contentsOf: url) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .clipped()
                                        .cornerRadius(12)
                                } else {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(Color.secondary.opacity(0.1))
                                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                                    }
                                    .frame(height: 180)
                                    .clipped()
                                    .cornerRadius(12)
                                }
                            } else {
                                PlaceholderImageView()
                            }
                        } else {
                            PlaceholderImageView()
                        }
                        
                        Text(post.caption.prefix(120) + (post.caption.count > 120 ? "..." : ""))
                            .font(.footnote)
                            .lineLimit(4)
                            .foregroundColor(.primary)
                        
                        HStack {
                            ForEach(post.postPlatforms, id: \.self) { platform in
                                Image(systemName: platform == .threads ? "number" : "f.square")
                                    .foregroundColor(platform == .threads ? .kosmicPurple : .kosmicBlue)
                            }
                            Spacer()
                            if let date = post.scheduledDate ?? post.publishedDate {
                                Text(date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(16)
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Timeline View

struct PostTimelineView: View {
    let posts: [Post]
    
    var groupedPosts: [(key: String, value: [Post])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let groups = Dictionary(grouping: posts) { post in
            let date = post.scheduledDate ?? post.publishedDate ?? Date()
            return formatter.string(from: date)
        }
        return groups.sorted { lhs, rhs in
            guard let lhsDate = DateFormatter.timelineFormatter.date(from: lhs.key),
                  let rhsDate = DateFormatter.timelineFormatter.date(from: rhs.key) else { return false }
            return lhsDate > rhsDate
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(groupedPosts, id: \.key) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(section.key)
                            .font(.headline)
                        
                        ForEach(section.value.sorted(by: { ($0.scheduledDate ?? $0.publishedDate ?? Date()) < ($1.scheduledDate ?? $1.publishedDate ?? Date()) })) { post in
                            HStack(alignment: .top, spacing: 12) {
                                Rectangle()
                                    .fill(Color.kosmicBlue)
                                    .frame(width: 2)
                                    .overlay(Circle()
                                        .fill(Color.kosmicBlue)
                                        .frame(width: 10, height: 10)
                                        .offset(x: -4)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if let date = post.scheduledDate ?? post.publishedDate {
                                        Text(date.formatted(date: .omitted, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(post.caption.prefix(140) + (post.caption.count > 140 ? "..." : ""))
                                        .font(.body)
                                    HStack(spacing: 6) {
                                        ForEach(post.postPlatforms, id: \.self) { platform in
                                            Text(platform.displayName)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Custom Property Editor

struct CustomPropertyEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomPostProperty.sortOrder) private var properties: [CustomPostProperty]
    @State private var newPropertyName = ""
    @State private var selectedType: PropertyType = .text
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Properties")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("Add Property") {
                    TextField("Name", text: $newPropertyName)
                    Picker("Type", selection: $selectedType) {
                        ForEach(PropertyType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    Button("Add") {
                        addProperty()
                    }
                    .disabled(newPropertyName.isEmpty)
                }
                
                Section("Existing Properties") {
                    ForEach(properties) { property in 
                        HStack {
                            VStack(alignment: .leading) {
                                Text(property.name)
                                Text(property.type.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                deleteProperty(property)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 420, height: 480)
    }
    
    private func addProperty() {
        let property = CustomPostProperty(
            name: newPropertyName,
            type: selectedType,
            sortOrder: (properties.last?.sortOrder ?? 0) + 1
        )
        modelContext.insert(property)
        try? modelContext.save()
        newPropertyName = ""
        selectedType = .text
    }
    
    private func deleteProperty(_ property: CustomPostProperty) {
        modelContext.delete(property)
        try? modelContext.save()
    }
}

private extension PropertyType {
    static var allCases: [PropertyType] { [.text, .number, .select, .multiselect, .date, .checkbox] }
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .number: return "Number"
        case .select: return "Select"
        case .multiselect: return "Multi-Select"
        case .date: return "Date"
        case .checkbox: return "Checkbox"
        }
    }
}

private struct PlaceholderImageView: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.08))
            .frame(height: 180)
            .overlay(
                Image(systemName: "text.alignleft")
                    .font(.title)
                    .foregroundColor(.secondary)
            )
            .cornerRadius(12)
    }
}

private extension URL {
    init?(mediaPath: String) {
        if mediaPath.hasPrefix("http") || mediaPath.hasPrefix("https") {
            self.init(string: mediaPath)
        } else if mediaPath.hasPrefix("file://") {
            self.init(string: mediaPath)
        } else {
            self.init(fileURLWithPath: mediaPath)
        }
    }
}

private extension DateFormatter {
    static let timelineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

