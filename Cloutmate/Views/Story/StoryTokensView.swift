//
//  StoryTokensView.swift
//  Cloutmate
//
//  Story Tokens collection view
//

import SwiftUI
import SwiftData

struct StoryTokensView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoryToken.createdAt, order: .reverse) private var tokens: [StoryToken]
    
    @State private var selectedToken: StoryToken?
    @State private var showingExportSheet = false
    @State private var exportToken: StoryToken?
    @State private var filterType: String? = nil
    @State private var dateRange: ClosedRange<Date>?
    
    var filteredTokens: [StoryToken] {
        var result = tokens
        
        if let filterType = filterType {
            result = result.filter { $0.storyType == filterType }
        }
        
        if let dateRange = dateRange {
            result = result.filter { token in
                dateRange.contains(token.startDate) || dateRange.contains(token.endDate)
            }
        }
        
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                filtersSection
                tokensGrid
            }
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .sheet(item: $selectedToken) { token in
            StoryTokenDetailView(token: token)
        }
        .sheet(item: $exportToken) { token in
            StoryTokenExportSheet(token: token)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Story Tokens")
                .font(.system(size: 28, weight: .bold))
            
            Text("Collectible moments from your journey")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("\(filteredTokens.count) token\(filteredTokens.count == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.system(size: 14, weight: .semibold))
            
            HStack(spacing: 12) {
                // Story type filter
                Menu {
                    Button("All Types") {
                        filterType = nil
                    }
                    ForEach(["weekly", "monthly", "milestone", "insight"], id: \.self) { type in
                        Button(type.capitalized) {
                            filterType = type
                        }
                    }
                } label: {
                    Label(filterType?.capitalized ?? "All Types", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                
                // Date range filter
                DateRangePicker(range: $dateRange)
            }
        }
    }
    
    private var tokensGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
        ], spacing: 16) {
            ForEach(filteredTokens) { token in
                StoryTokenCard(
                    token: token,
                    onTap: {
                        selectedToken = token
                    },
                    onExport: {
                        exportToken = token
                    }
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct DateRangePicker: View {
    @Binding var range: ClosedRange<Date>?
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: {
            showingPicker.toggle()
        }) {
            Label(
                range != nil ? "Date Range" : "All Dates",
                systemImage: "calendar"
            )
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .popover(isPresented: $showingPicker) {
            VStack(spacing: 16) {
                DatePicker("Start", selection: Binding(
                    get: { range?.lowerBound ?? Date() },
                    set: { newValue in
                        if let upper = range?.upperBound {
                            range = newValue...upper
                        } else {
                            range = newValue...Date()
                        }
                    }
                ), displayedComponents: .date)
                
                DatePicker("End", selection: Binding(
                    get: { range?.upperBound ?? Date() },
                    set: { newValue in
                        if let lower = range?.lowerBound {
                            range = lower...newValue
                        } else {
                            range = Date()...newValue
                        }
                    }
                ), displayedComponents: .date)
                
                Button("Clear") {
                    range = nil
                    showingPicker = false
                }
            }
            .padding()
        }
    }
}

struct StoryTokenDetailView: View {
    let token: StoryToken
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(token.title)
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("\(formatDate(token.startDate)) - \(formatDate(token.endDate))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    // Summary
                    Text(token.summary)
                        .font(.system(size: 16))
                        .lineSpacing(4)
                    
                    // Full markdown content
                    Text(token.markdown)
                        .font(.system(size: 14))
                        .lineSpacing(6)
                    
                    // Themes
                    if !token.themes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Themes")
                                .font(.system(size: 16, weight: .semibold))
                            
                            ThemeFlowLayout(spacing: 8) {
                                ForEach(token.themes, id: \.self) { theme in
                                    Text(theme)
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Metrics
                    if !token.metrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Metrics")
                                .font(.system(size: 16, weight: .semibold))
                            
                            ForEach(Array(token.metrics.keys), id: \.self) { key in
                                if let value = token.metrics[key] {
                                    HStack {
                                        Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                        Spacer()
                                        Text(String(format: "%.2f", value))
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(28)
            }
            .navigationTitle("Story Token")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StoryTokenExportSheet: View {
    let token: StoryToken
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .markdown
    
    enum ExportFormat {
        case markdown
        case pdf
        case visualCard
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Export Story Token")
                    .font(.system(size: 20, weight: .semibold))
                
                Picker("Format", selection: $exportFormat) {
                    Text("Markdown").tag(ExportFormat.markdown)
                    Text("PDF").tag(ExportFormat.pdf)
                    Text("Visual Card").tag(ExportFormat.visualCard)
                }
                .pickerStyle(.segmented)
                
                Button("Export") {
                    Task {
                        await exportToken()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportToken() async {
        // Implementation will be in StoryTokenExportService
        await StoryTokenExportService.shared.export(
            token: token,
            format: exportFormat,
            completion: { success in
                if success {
                    dismiss()
                }
            }
        )
    }
}

// Simple FlowLayout for themes
struct ThemeFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

