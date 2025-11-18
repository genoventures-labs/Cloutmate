//
//  TodoistModels.swift
//  FocusOS
//
//  Todoist API v2 response models
//

import Foundation

struct TodoistProject: Codable {
    let id: String
    let name: String
    let color: String?
    let parentId: String?
    let order: Int
    let isArchived: Bool
    let isFavorite: Bool
}

struct TodoistTask: Codable {
    let id: String
    let projectId: String
    let sectionId: String?
    let content: String
    let description: String?
    let isCompleted: Bool
    let labels: [String]
    let priority: Int // 1-4, where 4 is highest
    let due: TodoistDueDate?
    let order: Int
    let createdAt: String
    let completedAt: String?
}

struct TodoistDueDate: Codable {
    let date: String
    let datetime: String?
    let string: String
    let timezone: String?
}

struct TodoistSection: Codable {
    let id: String
    let projectId: String
    let name: String
    let order: Int
}

struct TodoistLabel: Codable {
    let id: String
    let name: String
    let color: String?
    let order: Int
    let isFavorite: Bool
}

struct TodoistTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

