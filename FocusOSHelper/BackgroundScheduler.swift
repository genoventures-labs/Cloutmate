//
//  BackgroundScheduler.swift
//  FocusOSHelper
//
//  Background scheduler (deprecated - no longer publishing to social media)
//

import Foundation
import SwiftData
import FocusOSShared
import os.log

final class BackgroundScheduler {
    static let shared = BackgroundScheduler()
    
    private var timer: Timer?
    private let modelContainer: ModelContainer
    
    private init() {
        self.modelContainer = SharedDataManager.createSharedModelContainer()
    }
    
    func start() {
        os_log("BackgroundScheduler started (publishing disabled)", log: .default, type: .info)
        // No longer publishing posts - keeping for backward compatibility
    }
    
    func checkScheduledPosts() {
        // No-op: Social media publishing has been removed
        os_log("checkScheduledPosts called but publishing is disabled", log: .default, type: .debug)
    }
}
