//
//  AuroraChangelog.swift
//  Cloutmate
//
//  Aurora's self-awareness changelog system
//

import Foundation

// MARK: - Changelog Entry

struct AuroraChangelogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let date: String // ISO 8601 timestamp
    let version: String?
    let feature: String
    let changeType: ChangeType
    let description: String
    let impact: String
    let userFacing: Bool
    let tags: [String]
    let commitHash: String? // Git commit hash linking to code changes
    
    enum ChangeType: String, Codable {
        case added = "added"
        case modified = "modified"
        case improved = "improved"
        case fixed = "fixed"
        case deprecated = "deprecated"
    }
    
    var dateValue: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: date) ?? ISO8601DateFormatter().date(from: date)
    }
}

// MARK: - Changelog Container

struct AuroraChangelog: Codable, Sendable {
    let currentVersion: String
    let lastUpdated: String
    var entries: [AuroraChangelogEntry]
    
    init(currentVersion: String, lastUpdated: String, entries: [AuroraChangelogEntry]) {
        self.currentVersion = currentVersion
        self.lastUpdated = lastUpdated
        // Sort entries by date, newest first
        self.entries = entries.sorted { entry1, entry2 in
            guard let date1 = entry1.dateValue,
                  let date2 = entry2.dateValue else {
                return false
            }
            return date1 > date2
        }
    }
}

