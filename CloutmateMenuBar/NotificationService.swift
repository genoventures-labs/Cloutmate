//
//  NotificationService.swift
//  CloutmateMenuBar
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func showSuccessNotification(caption: String) {
        let content = UNMutableNotificationContent()
        content.title = "Post Published Successfully"
        content.body = String(caption.prefix(100)) + (caption.count > 100 ? "..." : "")
        content.sound = .default
        content.categoryIdentifier = "POST_SUCCESS"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing success notification: \(error)")
            }
        }
    }
    
    func showFailureNotification(error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Post Failed"
        content.body = error
        content.sound = .default
        content.categoryIdentifier = "POST_FAILURE"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing failure notification: \(error)")
            }
        }
    }
    
    func showScheduledNotification(caption: String, scheduledDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Post Scheduled"
        content.body = String(caption.prefix(100)) + (caption.count > 100 ? "..." : "")
        content.sound = .default
        content.categoryIdentifier = "POST_SCHEDULED"
        
        // Schedule notification for the same time as the post
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
