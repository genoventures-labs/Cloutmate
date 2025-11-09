//
//  AuroraChangelogService.swift
//  Cloutmate
//
//  Service for managing Aurora's changelog and self-awareness
//

import Foundation

actor AuroraChangelogService {
    static let shared = AuroraChangelogService()
    
    private var changelog: AuroraChangelog?
    private let changelogFileName = "aurora_changelog"
    private let lastSeenVersionKey = "com.kosmicapps.cloutmate.aurora.lastSeenVersion"
    private let lastSeenDateKey = "com.kosmicapps.cloutmate.aurora.lastSeenDate"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadChangelog()
    }
    
    // MARK: - Loading
    
    private func loadChangelog() {
        guard let url = Bundle.main.url(forResource: changelogFileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AuroraChangelog.self, from: data) else {
            print("[AuroraChangelogService] Failed to load changelog from bundle")
            changelog = nil
            return
        }
        
        changelog = decoded
        print("[AuroraChangelogService] Loaded changelog with \(decoded.entries.count) entries")
    }
    
    // MARK: - Query Methods
    
    func getRecentChanges(days: Int) -> [AuroraChangelogEntry] {
        guard let changelog = changelog else { return [] }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return changelog.entries.filter { entry in
            guard let entryDate = entry.dateValue else { return false }
            return entryDate >= cutoffDate
        }
    }
    
    func getChangesForFeature(_ feature: String) -> [AuroraChangelogEntry] {
        guard let changelog = changelog else { return [] }
        
        let lowercasedFeature = feature.lowercased()
        return changelog.entries.filter { entry in
            entry.feature.lowercased().contains(lowercasedFeature) ||
            entry.tags.contains { $0.lowercased() == lowercasedFeature }
        }
    }
    
    func getChangesSince(_ date: Date) -> [AuroraChangelogEntry] {
        guard let changelog = changelog else { return [] }
        
        return changelog.entries.filter { entry in
            guard let entryDate = entry.dateValue else { return false }
            return entryDate >= date
        }
    }
    
    func getAllChanges() -> [AuroraChangelogEntry] {
        return changelog?.entries ?? []
    }
    
    func getUserFacingChanges(days: Int) -> [AuroraChangelogEntry] {
        return getRecentChanges(days: days).filter { $0.userFacing }
    }
    
    // MARK: - Formatting
    
    func formatChangesForPrompt(_ entries: [AuroraChangelogEntry]) -> String {
        guard !entries.isEmpty else { return "" }
        
        var sections: [String: [AuroraChangelogEntry]] = [:]
        
        for entry in entries {
            let section: String
            switch entry.changeType {
            case .added:
                section = "New Features"
            case .improved:
                section = "Improvements"
            case .modified:
                section = "Updates"
            case .fixed:
                section = "Fixes"
            case .deprecated:
                section = "Deprecations"
            }
            
            sections[section, default: []].append(entry)
        }
        
        var formatted = "**RECENT UPDATES:**\n\n"
        
        let sectionOrder = ["New Features", "Improvements", "Updates", "Fixes", "Deprecations"]
        for section in sectionOrder {
            if let sectionEntries = sections[section], !sectionEntries.isEmpty {
                formatted += "**\(section):**\n"
                for entry in sectionEntries {
                    formatted += "- \(entry.feature): \(entry.description)"
                    if !entry.impact.isEmpty {
                        formatted += " (\(entry.impact))"
                    }
                    formatted += "\n"
                }
                formatted += "\n"
            }
        }
        
        formatted += "You can reference these updates naturally when relevant. If a user asks about new features or changes, you can mention these updates."
        
        return formatted
    }
    
    // MARK: - Diff & Patch Notes
    
    func auroraChangelogDiff() -> [AuroraChangelogEntry] {
        guard let changelog = changelog else { return [] }
        
        let lastSeenVersion = userDefaults.string(forKey: lastSeenVersionKey)
        let lastSeenDateString = userDefaults.string(forKey: lastSeenDateKey)
        
        // If we've never seen a version, return all entries
        guard let lastSeenVersion = lastSeenVersion,
              let lastSeenDateString = lastSeenDateString else {
            return changelog.entries
        }
        
        // Parse last seen date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let lastSeenDate = formatter.date(from: lastSeenDateString) else {
            return changelog.entries
        }
        
        // If current version is different, return all entries
        if changelog.currentVersion != lastSeenVersion {
            return changelog.entries
        }
        
        // Otherwise, return entries since last seen date
        return getChangesSince(lastSeenDate)
    }
    
    func markChangelogAsSeen() {
        guard let changelog = changelog else { return }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = formatter.string(from: Date())
        
        userDefaults.set(changelog.currentVersion, forKey: lastSeenVersionKey)
        userDefaults.set(now, forKey: lastSeenDateKey)
        
        print("[AuroraChangelogService] Marked changelog as seen (version: \(changelog.currentVersion))")
    }
    
    func getPatchNotes() -> String {
        let diffEntries = auroraChangelogDiff()
        guard !diffEntries.isEmpty else { return "" }
        
        var sections: [String: [AuroraChangelogEntry]] = [:]
        
        for entry in diffEntries {
            let section: String
            switch entry.changeType {
            case .added:
                section = "New Features"
            case .improved:
                section = "Improvements"
            case .modified:
                section = "Updates"
            case .fixed:
                section = "Fixes"
            case .deprecated:
                section = "Deprecations"
            }
            
            sections[section, default: []].append(entry)
        }
        
        var patchNotes = "**Patch Notes (v\(changelog?.currentVersion ?? "unknown")):**\n\n"
        
        let sectionOrder = ["New Features", "Improvements", "Updates", "Fixes", "Deprecations"]
        for section in sectionOrder {
            if let sectionEntries = sections[section], !sectionEntries.isEmpty {
                patchNotes += "**\(section):**\n"
                for entry in sectionEntries {
                    patchNotes += "• \(entry.feature): \(entry.description)"
                    if !entry.impact.isEmpty {
                        patchNotes += " — \(entry.impact)"
                    }
                    patchNotes += "\n"
                }
                patchNotes += "\n"
            }
        }
        
        return patchNotes
    }
    
    // MARK: - Query Capability
    
    func queryChangelog(feature: String?, days: Int?, userFacingOnly: Bool) -> String {
        var entries: [AuroraChangelogEntry] = []
        
        if let feature = feature {
            entries = getChangesForFeature(feature)
        } else if let days = days {
            entries = userFacingOnly ? getUserFacingChanges(days: days) : getRecentChanges(days: days)
        } else {
            entries = userFacingOnly ? getAllChanges().filter { $0.userFacing } : getAllChanges()
        }
        
        guard !entries.isEmpty else {
            return "No matching changes found in the changelog."
        }
        
        return formatChangesForPrompt(entries)
    }
    
    // MARK: - Git Commit History
    
    func getCommitHistory(days: Int? = nil) -> [GitCommit] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        
        var arguments = ["log", "--pretty=format:%H|%ai|%an|%s", "--name-only"]
        
        if let days = days {
            let sinceDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            arguments.append("--since=\(formatter.string(from: sinceDate))")
        }
        
        arguments.append("--")
        arguments.append("Cloutmate/")
        
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            return parseGitLog(output)
        } catch {
            print("[AuroraChangelogService] Error getting commit history: \(error)")
            return []
        }
    }
    
    func getCommitsForFeature(_ feature: String) -> [GitCommit] {
        let allCommits = getCommitHistory()
        let lowercasedFeature = feature.lowercased()
        
        return allCommits.filter { commit in
            commit.message.lowercased().contains(lowercasedFeature) ||
            commit.files.contains { $0.lowercased().contains(lowercasedFeature) }
        }
    }
    
    func getCommitDetails(_ hash: String) -> GitCommit? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["show", "--pretty=format:%H|%ai|%an|%s", "--name-only", hash]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let commits = parseGitLog(output)
            return commits.first
        } catch {
            print("[AuroraChangelogService] Error getting commit details: \(error)")
            return nil
        }
    }
    
    func formatCommitHistory(_ commits: [GitCommit]) -> String {
        guard !commits.isEmpty else {
            return "No commit history found."
        }
        
        var formatted = "**Recent Git Commits:**\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        for commit in commits.prefix(10) { // Limit to 10 most recent
            let dateStr = dateFormatter.string(from: commit.date)
            formatted += "• **\(commit.hash.prefix(7))** - \(commit.message)\n"
            formatted += "  \(dateStr) by \(commit.author)\n"
            if !commit.files.isEmpty {
                formatted += "  Files: \(commit.files.prefix(3).joined(separator: ", "))"
                if commit.files.count > 3 {
                    formatted += " (+\(commit.files.count - 3) more)"
                }
                formatted += "\n"
            }
            formatted += "\n"
        }
        
        return formatted
    }
    
    private func parseGitLog(_ output: String) -> [GitCommit] {
        var commits: [GitCommit] = []
        var currentCommit: (hash: String, date: Date, author: String, message: String)?
        var currentFiles: [String] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        for line in output.components(separatedBy: .newlines) {
            if line.isEmpty {
                continue
            }
            
            // Check if this is a commit header line (format: hash|date|author|message)
            if line.contains("|") && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                // Save previous commit if exists
                if let commit = currentCommit {
                    commits.append(GitCommit(
                        hash: commit.hash,
                        date: commit.date,
                        message: commit.message,
                        author: commit.author,
                        files: currentFiles,
                        changelogEntryId: findChangelogEntryId(for: commit.hash)
                    ))
                }
                
                // Parse new commit
                let parts = line.components(separatedBy: "|")
                if parts.count >= 4 {
                    let hash = parts[0]
                    let dateStr = parts[1]
                    let author = parts[2]
                    let message = parts[3...].joined(separator: "|")
                    
                    if let date = dateFormatter.date(from: dateStr) {
                        currentCommit = (hash: hash, date: date, author: author, message: message)
                        currentFiles = []
                    }
                }
            } else if currentCommit != nil {
                // This is a file name
                let file = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !file.isEmpty && file.hasPrefix("Cloutmate/") {
                    currentFiles.append(file)
                }
            }
        }
        
        // Save last commit
        if let commit = currentCommit {
            commits.append(GitCommit(
                hash: commit.hash,
                date: commit.date,
                message: commit.message,
                author: commit.author,
                files: currentFiles,
                changelogEntryId: findChangelogEntryId(for: commit.hash)
            ))
        }
        
        return commits
    }
    
    private func findChangelogEntryId(for commitHash: String) -> UUID? {
        guard let changelog = changelog else { return nil }
        
        return changelog.entries.first { entry in
            entry.commitHash == commitHash
        }?.id
    }
    
    // MARK: - Update Information
    
    func getLastUpdatedDate() -> Date? {
        guard let changelog = changelog else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: changelog.lastUpdated) ?? ISO8601DateFormatter().date(from: changelog.lastUpdated)
    }
    
    func getLatestUpdate() -> AuroraChangelogEntry? {
        return changelog?.entries.first
    }
    
    func getUpdateInfo() -> String {
        guard let changelog = changelog else {
            return "I don't have update information available."
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        var info = "**Update Information:**\n\n"
        info += "**Current Version:** \(changelog.currentVersion)\n"
        
        if let lastUpdated = getLastUpdatedDate() {
            info += "**Last Updated:** \(dateFormatter.string(from: lastUpdated))\n"
        } else {
            info += "**Last Updated:** \(changelog.lastUpdated)\n"
        }
        
        info += "**Total Updates:** \(changelog.entries.count)\n\n"
        
        if let latest = getLatestUpdate() {
            info += "**Latest Update:**\n"
            info += "- **Feature:** \(latest.feature)\n"
            info += "- **Type:** \(latest.changeType.rawValue.capitalized)\n"
            info += "- **Description:** \(latest.description)\n"
            if let latestDate = latest.dateValue {
                info += "- **Date:** \(dateFormatter.string(from: latestDate))\n"
            }
            if let commitHash = latest.commitHash {
                info += "- **Commit:** \(commitHash.prefix(7))\n"
            }
        }
        
        return info
    }
}

