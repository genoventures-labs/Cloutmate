//
//  GitCommit.swift
//  Cloutmate
//
//  Git commit model for Aurora's commit history access
//

import Foundation

struct GitCommit: Codable, Identifiable, Sendable {
    let id: String // Commit hash
    let hash: String // Full commit hash
    let date: Date
    let message: String
    let author: String
    let files: [String] // Changed files
    let changelogEntryId: UUID? // Link to changelog entry if exists
    
    init(hash: String, date: Date, message: String, author: String, files: [String], changelogEntryId: UUID? = nil) {
        self.id = hash
        self.hash = hash
        self.date = date
        self.message = message
        self.author = author
        self.files = files
        self.changelogEntryId = changelogEntryId
    }
}

