//
//  PARATemplate.swift
//  FocusOS
//
//  Template system for PARA structure
//

import Foundation
import SwiftData
import Combine

enum TemplateType: String, Codable, CaseIterable {
    case project
    case task
    case note
    case post
    case ritual
    case area
    
    var displayName: String {
        switch self {
        case .project: return "Project"
        case .task: return "Task"
        case .note: return "Note"
        case .post: return "Post"
        case .ritual: return "Ritual"
        case .area: return "Area"
        }
    }
    
    var icon: String {
        switch self {
        case .project: return "folder.fill"
        case .task: return "checkmark.circle"
        case .note: return "doc.text"
        case .post: return "square.and.pencil"
        case .ritual: return "calendar"
        case .area: return "rectangle.stack.fill"
        }
    }
}

@Model
final class PARATemplate {
    var id: UUID = UUID()
    var typeRaw: String = TemplateType.project.rawValue
    var title: String = ""
    var templateDescription: String = ""
    var content: String = "" // JSON or Markdown
    var fields: [String: String] = [:] // Custom fields
    var category: String = "" // e.g., "Starter", "Custom", "Business"
    var isBuiltIn: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var usageCount: Int = 0
    
    init(
        type: TemplateType = .project,
        title: String,
        templateDescription: String = "",
        content: String = "",
        fields: [String: String] = [:],
        category: String = "Starter",
        isBuiltIn: Bool = true
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.title = title
        self.templateDescription = templateDescription
        self.content = content
        self.fields = fields
        self.category = category
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updatedAt = Date()
        self.usageCount = 0
    }
    
    var type: TemplateType {
        get { TemplateType(rawValue: typeRaw) ?? .project }
        set { typeRaw = newValue.rawValue }
    }
}

// MARK: - Built-in Templates

extension PARATemplate {
    static func builtInTemplates() -> [PARATemplate] {
        return [
            // Project Templates
            PARATemplate(
                type: .project,
                title: "Product Launch",
                templateDescription: "Complete checklist for launching a new product",
                content: """
                {
                  "goal": "Launch [product name] to market",
                  "status": "active",
                  "tasks": [
                    { "title": "Define target audience", "priority": "high" },
                    { "title": "Create landing page", "priority": "high" },
                    { "title": "Prepare marketing materials", "priority": "medium" },
                    { "title": "Set up analytics tracking", "priority": "high" },
                    { "title": "Launch announcement", "priority": "high" }
                  ]
                }
                """
            ),
            PARATemplate(
                type: .project,
                title: "Content Campaign",
                templateDescription: "Multi-week content campaign structure",
                content: """
                {
                  "goal": "Run 4-week content campaign",
                  "status": "active",
                  "cadence": 3
                }
                """
            ),
            
            // Task Templates
            PARATemplate(
                type: .task,
                title: "Content Drafting",
                templateDescription: "Checklist for creating social media content",
                content: """
                {
                  "title": "Draft content for [platform]",
                  "priority": "medium",
                  "subtasks": [
                    "Research trending topics",
                    "Write first draft",
                    "Add hashtags",
                    "Review and edit",
                    "Schedule post"
                  ]
                }
                """
            ),
            PARATemplate(
                type: .task,
                title: "QA Review",
                templateDescription: "Quality assurance checklist",
                content: """
                {
                  "title": "QA [feature]",
                  "priority": "high",
                  "subtasks": [
                    "Check functionality",
                    "Test on multiple devices",
                    "Review for typos",
                    "Check links",
                    "Get approval"
                  ]
                }
                """
            ),
            
            // Note Templates
            PARATemplate(
                type: .note,
                title: "Meeting Notes",
                templateDescription: "Structured meeting notes template",
                content: """
                # Meeting Notes
                
                **Date:** [date]
                **Attendees:** [names]
                
                ## Agenda
                - 
                
                ## Discussion
                
                
                ## Action Items
                - [ ] 
                
                ## Next Steps
                1. 
                """
            ),
            PARATemplate(
                type: .note,
                title: "Research Summary",
                templateDescription: "Template for research notes",
                content: """
                # Research Summary
                
                **Topic:** 
                **Source:** 
                **Date:** 
                
                ## Key Findings
                1. 
                2. 
                3. 
                
                ## Insights
                
                
                ## References
                - 
                """
            ),
            PARATemplate(
                type: .note,
                title: "Swipe File",
                templateDescription: "Capture inspiring content for reference",
                content: """
                # Swipe File
                
                **Source:** 
                **URL:** 
                **Date Saved:** 
                
                ## What worked
                
                
                ## Why it works
                
                
                ## How to adapt
                
                
                ## Tags
                
                """
            ),
            
            // Post Templates
            PARATemplate(
                type: .post,
                title: "Announcement",
                templateDescription: "Product or feature announcement post",
                content: """
                Announcing [feature/product]! 🎉
                
                We're excited to share that [description]
                
                What this means for you:
                • 
                • 
                • 
                
                Learn more: [link]
                
                #announcement
                """
            ),
            PARATemplate(
                type: .post,
                title: "Thread Post",
                templateDescription: "Multi-post thread structure",
                content: """
                1/ Thread: [Topic]
                
                2/ First key point
                
                3/ Second key point
                
                4/ Third key point with example
                
                5/ Conclusion + call to action
                """
            ),
            PARATemplate(
                type: .post,
                title: "Tip/Insight",
                templateDescription: "Quick tip or insight post",
                content: """
                Quick tip: [topic] 💡
                
                Instead of [common mistake],
                Try [better approach]:
                
                [explanation]
                
                Why it works: [benefit]
                
                Have you tried this? Share your results!
                """
            ),
            
            // Ritual Templates
            PARATemplate(
                type: .ritual,
                title: "Weekly Review",
                templateDescription: "Weekly review ritual checklist",
                content: """
                # Weekly Review
                
                ## Clear Inbox
                - [ ] Process all inbox items
                - [ ] Convert to tasks/notes/posts
                - [ ] Archive or delete
                
                ## Review Projects
                - [ ] Update project status
                - [ ] Mark completed tasks
                - [ ] Add new tasks for next week
                
                ## Check Schedule
                - [ ] Review upcoming posts
                - [ ] Schedule new content
                - [ ] Check task due dates
                
                ## Capture Learnings
                - [ ] What went well this week?
                - [ ] What could be improved?
                - [ ] Key insights to remember
                
                ## Plan Next Week
                - [ ] Top 3 priorities
                - [ ] Content calendar themes
                - [ ] Important deadlines
                """
            ),
            PARATemplate(
                type: .ritual,
                title: "Monthly Strategy",
                templateDescription: "Monthly planning ritual",
                content: """
                # Monthly Strategy
                
                ## Last Month Review
                - [ ] Completed projects
                - [ ] Wins and achievements
                - [ ] Challenges overcome
                - [ ] Lessons learned
                
                ## This Month Focus
                - [ ] Area 1: [outcome]
                - [ ] Area 2: [outcome]
                - [ ] Area 3: [outcome]
                
                ## Key Initiatives
                1. 
                2. 
                3. 
                
                ## Content Themes
                - Week 1: 
                - Week 2: 
                - Week 3: 
                - Week 4: 
                
                ## Success Metrics
                - 
                - 
                - 
                """
            ),
        ]
    }
}
