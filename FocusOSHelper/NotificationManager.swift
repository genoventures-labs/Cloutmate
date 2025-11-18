//
//  NotificationManager.swift
//  FocusOSHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import UserNotifications
import os.log

final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                os_log("Notification authorization error: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
    
    func sendPostPublished(postID: String) {
        let content = UNMutableNotificationContent()
        content.title = "Post Published"
        content.body = "Your scheduled post has been published successfully."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: postID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendPostFailed(postID: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Post Failed"
        content.body = "Failed to publish post: \(error)"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: postID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

