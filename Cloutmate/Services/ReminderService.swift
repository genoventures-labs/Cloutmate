//
//  ReminderService.swift
//  Cloutmate
//
//  Service for scheduling and managing reminder notifications
//

import Foundation
import UserNotifications
import SwiftData
import os.log
import CloutmateShared

@MainActor
final class ReminderService {
    static let shared = ReminderService()
    
    private init() {
        requestNotificationPermission()
    }
    
    /// Request notification permission if not already granted
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error = error {
                        os_log("Notification authorization error: %{public}@", log: .default, type: .error, error.localizedDescription)
                    } else if granted {
                        os_log("Notification permission granted", log: .default, type: .info)
                    }
                }
            }
        }
    }
    
    /// Schedule a notification for a reminder
    func scheduleReminder(_ reminder: Reminder) {
        // Cancel any existing notification for this reminder
        if let existingId = reminder.notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [existingId])
        }
        
        // Don't schedule if reminder date is in the past
        guard reminder.reminderDate > Date() else {
            os_log("Reminder date is in the past, skipping notification: %{public}@", log: .default, type: .info, reminder.title)
            return
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(reminder.title)"
        
        if let notes = reminder.notes, !notes.isEmpty {
            content.body = notes
        } else {
            content.body = "Time to check on this"
        }
        
        content.sound = .default
        content.categoryIdentifier = "REMINDER"
        content.userInfo = [
            "reminderId": reminder.id.uuidString,
            "type": "reminder"
        ]
        
        // Create calendar trigger
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create notification request
        let identifier = reminder.id.uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                os_log("Error scheduling reminder notification: %{public}@", log: .default, type: .error, error.localizedDescription)
            } else {
                reminder.notificationIdentifier = identifier
                os_log("Reminder scheduled: %{public}@ at %{public}@", log: .default, type: .info, reminder.title, reminder.reminderDate.formatted())
            }
        }
    }
    
    /// Cancel a scheduled reminder notification
    func cancelReminder(_ reminder: Reminder) {
        if let identifier = reminder.notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            reminder.notificationIdentifier = nil
            os_log("Reminder cancelled: %{public}@", log: .default, type: .info, reminder.title)
        }
    }
    
    /// Reschedule a reminder notification (useful when reminder date changes)
    func rescheduleReminder(_ reminder: Reminder) {
        cancelReminder(reminder)
        scheduleReminder(reminder)
    }
    
    /// Mark reminder as completed and cancel notification
    func completeReminder(_ reminder: Reminder, modelContext: ModelContext) {
        reminder.isCompleted = true
        reminder.updatedAt = Date()
        cancelReminder(reminder)
        
        do {
            try modelContext.save()
        } catch {
            os_log("Error saving completed reminder: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
}

