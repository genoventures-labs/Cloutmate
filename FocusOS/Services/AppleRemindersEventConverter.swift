//
//  AppleRemindersEventConverter.swift
//  FocusOS
//
//  Converts EKReminder properties to Task models
//

import Foundation
import EventKit
import FocusOSShared

struct AppleRemindersEventConverter {
    
    /// Convert an EKReminder to a Task
    static func convert(_ ekReminder: EKReminder, listId: String) -> Task {
        let task = Task(
            title: ekReminder.title ?? "Untitled Reminder",
            notes: ekReminder.notes,
            status: convertStatus(ekReminder),
            priority: convertPriority(ekReminder),
            dueDate: convertDueDate(ekReminder)
        )
        
        // Set external tracking fields
        task.externalReminderId = ekReminder.calendarItemIdentifier
        task.externalReminderListId = listId
        task.externalSource = "apple_reminders"
        task.lastSyncedAt = Date()
        
        // Set completedAt if reminder is completed
        if ekReminder.isCompleted {
            task.completedAt = ekReminder.completionDate ?? Date()
        }
        
        return task
    }
    
    /// Convert EKReminder due date components to Date
    static func convertDueDate(_ reminder: EKReminder) -> Date? {
        guard let dueDateComponents = reminder.dueDateComponents else {
            return nil
        }
        
        // Convert DateComponents to Date using current calendar
        return Calendar.current.date(from: dueDateComponents)
    }
    
    /// Convert EKReminderPriority to TaskPriority
    static func convertPriority(_ reminder: EKReminder) -> TaskPriority {
        switch reminder.priority {
        case 0: // EKReminderPriority.none
            return .medium
        case 1: // EKReminderPriority.low
            return .low
        case 9: // EKReminderPriority.high
            return .high
        default:
            return .medium
        }
    }
    
    /// Convert EKReminder completion status to TaskStatus
    static func convertStatus(_ reminder: EKReminder) -> TaskStatus {
        return reminder.isCompleted ? .done : .todo
    }
    
    /// Update an existing Task with data from EKReminder
    static func update(_ task: Task, from ekReminder: EKReminder) {
        task.title = ekReminder.title ?? "Untitled Reminder"
        task.notes = ekReminder.notes
        task.dueDate = convertDueDate(ekReminder)
        task.priority = convertPriority(ekReminder)
        task.status = convertStatus(ekReminder)
        task.lastSyncedAt = Date()
        
        // Update completedAt if reminder is completed
        if ekReminder.isCompleted {
            task.completedAt = ekReminder.completionDate ?? task.completedAt ?? Date()
        } else {
            task.completedAt = nil
        }
        
        task.updatedAt = Date()
    }
}

