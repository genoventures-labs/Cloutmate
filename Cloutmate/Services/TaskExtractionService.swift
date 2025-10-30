//
//  TaskExtractionService.swift
//  Cloutmate
//
//  Extract tasks from notes via markdown checkboxes and AI
//

import Foundation
import SwiftData

enum TaskExtractionService {
    static func extractTasksFromNote(_ note: Note, context: ModelContext) throws {
        let markdown = note.markdown
        
        // Parse markdown checkboxes: - [ ] task text
        let checkboxPattern = #"^[\s]*- \[ \] (.+)$"#
        let regex = try NSRegularExpression(pattern: checkboxPattern, options: .anchorsMatchLines)
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        
        let matches = regex.matches(in: markdown, options: [], range: range)
        
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            
            if let taskRange = Range(match.range(at: 1), in: markdown) {
                let taskText = String(markdown[taskRange]).trimmingCharacters(in: .whitespaces)
                
                if !taskText.isEmpty {
                    let task = Task(
                        title: taskText,
                        notes: "From note: \(note.title)",
                        priority: .medium,
                        projectId: note.projectId,
                        areaId: note.areaId
                    )
                    
                    context.insert(task)
                    
                    // Add backlink to note
                    note.backlinks.append(task.id)
                }
            }
        }
        
        // Also parse numbered task lists
        let numberedPattern = #"^\d+\. \[ \] (.+)$"#
        let numberedRegex = try NSRegularExpression(pattern: numberedPattern, options: .anchorsMatchLines)
        let numberedMatches = numberedRegex.matches(in: markdown, options: [], range: range)
        
        for match in numberedMatches {
            guard match.numberOfRanges > 1 else { continue }
            
            if let taskRange = Range(match.range(at: 1), in: markdown) {
                let taskText = String(markdown[taskRange]).trimmingCharacters(in: .whitespaces)
                
                if !taskText.isEmpty {
                    let task = Task(
                        title: taskText,
                        notes: "From note: \(note.title)",
                        priority: .medium,
                        projectId: note.projectId,
                        areaId: note.areaId
                    )
                    
                    context.insert(task)
                    note.backlinks.append(task.id)
                }
            }
        }
        
        note.updatedAt = Date()
        try? context.save()
    }
    
    static func extractTasksFromHighlights(note: Note, context: ModelContext) throws {
        for highlight in note.highlights {
            // Try to detect if highlight looks like a task
            if highlight.contains("TODO") || highlight.contains("FIXME") || highlight.contains("REMINDER") {
                let taskTitle = highlight
                    .replacingOccurrences(of: "TODO", with: "")
                    .replacingOccurrences(of: "FIXME", with: "")
                    .replacingOccurrences(of: "REMINDER", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !taskTitle.isEmpty {
                    let task = Task(
                        title: taskTitle,
                        notes: "From note highlight: \(note.title)",
                        priority: .high,
                        projectId: note.projectId,
                        areaId: note.areaId
                    )
                    
                    context.insert(task)
                    note.backlinks.append(task.id)
                }
            }
        }
        
        note.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - AI-Assisted Task Extraction

extension TaskExtractionService {
    static func extractTasksWithAI(_ note: Note, context: ModelContext) async throws {
        guard AISettings.shared.isAIEnabled else { return }
        
        let markdown = note.markdown
        let prompt = """
        Extract actionable tasks from this note text. Return only a JSON array of task titles.
        
        Note text:
        \(markdown)
        
        Return JSON format: {"tasks": ["task 1", "task 2", ...]}
        """
        
        do {
            let geminiService = GeminiService.shared
            let response = try await geminiService.generateResponse(for: prompt)
            
            // Parse JSON response
            if let jsonData = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let tasks = json["tasks"] as? [String] {
                
                for taskText in tasks {
                    let task = Task(
                        title: taskText,
                        notes: "AI extracted from: \(note.title)",
                        priority: .medium,
                        projectId: note.projectId,
                        areaId: note.areaId
                    )
                    
                    context.insert(task)
                    note.backlinks.append(task.id)
                }
                
                note.updatedAt = Date()
                try? context.save()
            }
        } catch {
            print("AI task extraction failed: \(error)")
        }
    }
}

