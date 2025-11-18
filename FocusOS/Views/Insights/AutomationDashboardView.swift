//
//  AutomationDashboardView.swift
//  FocusOS
//
//  Phase 6.1 - Smart Automation & Workflow Management
//

import SwiftUI
import SwiftData

struct AutomationDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var patterns: [WorkflowPattern] = []
    @State private var rules: [AutomationRule] = []
    @State private var templates: [WorkflowTemplate] = []
    @State private var suggestions: [WorkflowSuggestion] = []
    @State private var selectedPattern: WorkflowPattern?
    @State private var showNewRuleSheet = false
    @State private var isDetectingPatterns = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Navigation
            List {
                Section("Overview") {
                    NavigationLink(destination: AutomationOverviewView(
                        patterns: patterns,
                        rules: rules,
                        suggestions: suggestions
                    )) {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                }
                
                Section("Management") {
                    NavigationLink(destination: PatternListView(patterns: patterns)) {
                        Label("Detected Patterns", systemImage: "waveform.path.ecg")
                        if !patterns.isEmpty {
                            Text("\(patterns.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: RuleListView(rules: rules)) {
                        Label("Automation Rules", systemImage: "gearshape.2")
                        if !rules.isEmpty {
                            Text("\(rules.filter { $0.isEnabled }.count)/\(rules.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: TemplateListView(templates: templates)) {
                        Label("Workflow Templates", systemImage: "doc.on.doc")
                        if !templates.isEmpty {
                            Text("\(templates.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Actions") {
                    Button(action: detectPatterns) {
                        Label("Detect Patterns", systemImage: "sparkles")
                    }
                    .disabled(isDetectingPatterns)
                    
                    Button(action: { showNewRuleSheet = true }) {
                        Label("New Rule", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Automation")
        } detail: {
            AutomationOverviewView(
                patterns: patterns,
                rules: rules,
                suggestions: suggestions
            )
        }
        .sheet(isPresented: $showNewRuleSheet) {
            NewAutomationRuleView(modelContext: modelContext)
        }
        .task {
            loadData()
        }
    }
    
    private func loadData() {
        // Load patterns
        let patternDescriptor = FetchDescriptor<WorkflowPattern>(
            predicate: #Predicate { pattern in
                pattern.isActive
            },
            sortBy: [SortDescriptor(\WorkflowPattern.confidence, order: .reverse)]
        )
        patterns = (try? modelContext.fetch(patternDescriptor)) ?? []
        
        // Load rules
        let ruleDescriptor = FetchDescriptor<AutomationRule>(
            sortBy: [SortDescriptor(\AutomationRule.createdAt, order: .reverse)]
        )
        rules = (try? modelContext.fetch(ruleDescriptor)) ?? []
        
        // Load templates
        let templateDescriptor = FetchDescriptor<WorkflowTemplate>()
        templates = (try? modelContext.fetch(templateDescriptor)) ?? []
        
        // Load suggestions
        suggestions = SmartAutomationEngine.shared.getWorkflowSuggestions(modelContext: modelContext)
    }
    
    private func detectPatterns() {
        isDetectingPatterns = true
        
        Task {
            await SmartAutomationEngine.shared.detectPatterns(modelContext: modelContext)
            
            await MainActor.run {
                loadData()
                isDetectingPatterns = false
            }
        }
    }
}

// MARK: - Automation Overview

struct AutomationOverviewView: View {
    let patterns: [WorkflowPattern]
    let rules: [AutomationRule]
    let suggestions: [WorkflowSuggestion]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Stats
                HStack(spacing: 16) {
                    StatCard(
                        title: "Active Patterns",
                        value: "\(patterns.count)",
                        icon: "waveform.path.ecg",
                        color: .kosmicBlue
                    )
                    
                    StatCard(
                        title: "Automation Rules",
                        value: "\(rules.filter { $0.isEnabled }.count)",
                        icon: "gearshape.2.fill",
                        color: .kosmicGreen
                    )
                    
                    StatCard(
                        title: "Suggestions",
                        value: "\(suggestions.count)",
                        icon: "lightbulb.fill",
                        color: .yellow
                    )
                }
                .padding(.horizontal)
                
                // Workflow Suggestions
                if !suggestions.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Smart Suggestions", systemImage: "sparkles")
                                .font(.headline)
                            
                            ForEach(suggestions) { suggestion in
                                WorkflowSuggestionCard(suggestion: suggestion)
                                
                                if suggestion.id != suggestions.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                
                // Active Rules
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Active Automation Rules", systemImage: "gearshape.2")
                            .font(.headline)
                        
                        if !rules.filter({ $0.isEnabled }).isEmpty {
                            ForEach(rules.filter { $0.isEnabled }.prefix(5), id: \.id) { rule in
                                RuleCard(rule: rule)
                                
                                if rule.id != rules.filter({ $0.isEnabled }).prefix(5).last?.id {
                                    Divider()
                                }
                            }
                        } else {
                            Text("No active rules yet")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Pattern Insights
                if !patterns.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Pattern Insights", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.headline)
                            
                            ForEach(WorkflowPatternType.allCases, id: \.self) { type in
                                let count = patterns.filter { $0.patternType == type.rawValue }.count
                                if count > 0 {
                                    HStack {
                                        Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                        Text("\(count)")
                                            .font(.headline)
                                            .foregroundColor(.kosmicBlue)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Automation Overview")
    }
}

// MARK: - Workflow Suggestion Card

struct WorkflowSuggestionCard: View {
    let suggestion: WorkflowSuggestion
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                    Text(suggestion.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.0f%%", suggestion.confidence * 100))
                    .font(.headline)
                            .foregroundColor(.kosmicBlue)
            }
            
            if !suggestion.suggestedActions.isEmpty {
                HStack {
                    ForEach(suggestion.suggestedActions, id: \.self) { action in
                        Text(action)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.kosmicBlue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            
            if suggestion.canAutomate {
                Button("Enable Automation") {
                    // Enable automation for this pattern
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rule Card

struct RuleCard: View {
    let rule: AutomationRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.headline)
                    Text(rule.ruleDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    if rule.isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.kosmicGreen)
                    } else {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            HStack {
                Label("\(rule.executionCount) runs", systemImage: "play.circle")
                Spacer()
                if rule.executionCount > 0 {
                    let successRate = Double(rule.successCount) / Double(rule.executionCount)
                    Text(String(format: "%.0f%% success", successRate * 100))
                        .foregroundColor(successRate > 0.8 ? .kosmicGreen : .orange)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pattern List View

struct PatternListView: View {
    let patterns: [WorkflowPattern]
    
    var body: some View {
        List(patterns, id: \.id) { pattern in
            NavigationLink(destination: PatternDetailView(pattern: pattern)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.name)
                        .font(.headline)
                    Text(pattern.patternDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Confidence: \(Int(pattern.confidence * 100))%")
                        Spacer()
                        Text("\(pattern.occurrenceCount) occurrences")
                    }
                    .font(.caption)
                            .foregroundColor(.kosmicBlue)
                }
            }
        }
        .navigationTitle("Detected Patterns")
    }
}

struct PatternDetailView: View {
    let pattern: WorkflowPattern
    
    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Name", value: pattern.name)
                LabeledContent("Type", value: pattern.patternType.replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent("Confidence", value: String(format: "%.0f%%", pattern.confidence * 100))
                LabeledContent("Occurrences", value: "\(pattern.occurrenceCount)")
            }
            
            Section("Description") {
                Text(pattern.patternDescription)
            }
            
            if !pattern.suggestedActions.isEmpty {
                Section("Suggested Actions") {
                    ForEach(pattern.suggestedActions, id: \.self) { action in
                        Text(action)
                    }
                }
            }
        }
        .navigationTitle("Pattern Details")
    }
}

// MARK: - Rule List View

struct RuleListView: View {
    let rules: [AutomationRule]
    
    var body: some View {
        List(rules, id: \.id) { rule in
            NavigationLink(destination: RuleDetailView(rule: rule)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(rule.name)
                            .font(.headline)
                        Text(rule.ruleDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if rule.isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.kosmicGreen)
                    }
                }
            }
        }
        .navigationTitle("Automation Rules")
    }
}

struct RuleDetailView: View {
    let rule: AutomationRule
    
    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Name", value: rule.name)
                LabeledContent("Trigger Type", value: rule.triggerType.replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent("Status", value: rule.isEnabled ? "Enabled" : "Disabled")
                LabeledContent("Created By", value: rule.createdBy)
            }
            
            Section("Statistics") {
                LabeledContent("Executions", value: "\(rule.executionCount)")
                LabeledContent("Successes", value: "\(rule.successCount)")
                LabeledContent("Failures", value: "\(rule.failureCount)")
                if rule.executionCount > 0 {
                    let successRate = Double(rule.successCount) / Double(rule.executionCount)
                    LabeledContent("Success Rate", value: String(format: "%.1f%%", successRate * 100))
                }
            }
        }
        .navigationTitle("Rule Details")
    }
}

// MARK: - Template List View

struct TemplateListView: View {
    let templates: [WorkflowTemplate]
    
    var body: some View {
        List(templates, id: \.id) { template in
            NavigationLink(destination: TemplateDetailView(template: template)) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.title2)
                            .foregroundColor(.kosmicBlue)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading) {
                        Text(template.name)
                            .font(.headline)
                        Text(template.templateDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Workflow Templates")
    }
}

struct TemplateDetailView: View {
    let template: WorkflowTemplate
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 60))
                            .foregroundColor(.kosmicBlue)
                    
                    Spacer()
                }
                
                Text(template.name)
                    .font(.largeTitle.bold())
                
                Text(template.templateDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if template.usageCount > 0 {
                    HStack {
                        Label("\(template.usageCount) uses", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if template.avgSuccessRate > 0 {
                            Text(String(format: "%.0f%% success rate", template.avgSuccessRate * 100))
                                .foregroundColor(.kosmicGreen)
                        }
                    }
                    .font(.caption)
                }
                
                Button("Apply Template") {
                    Task {
                        try? await SmartAutomationEngine.shared.applyTemplate(template, modelContext: modelContext)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle("Template")
    }
}

// MARK: - New Rule Sheet

struct NewAutomationRuleView: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var triggerType: AutomationTriggerType = .timeOfDay
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Rule Information") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Trigger") {
                    Picker("Trigger Type", selection: $triggerType) {
                        ForEach(AutomationTriggerType.allCases, id: \.self) { type in
                            Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(type)
                        }
                    }
                }
            }
            .navigationTitle("New Automation Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createRule()
                    }
                    .disabled(name.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func createRule() {
        let rule = AutomationRule(
            name: name,
            ruleDescription: description,
            triggerType: triggerType.rawValue
        )
        rule.createdBy = "user"
        
        modelContext.insert(rule)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    AutomationDashboardView()
        .modelContainer(for: [WorkflowPattern.self, AutomationRule.self, WorkflowTemplate.self])
}

