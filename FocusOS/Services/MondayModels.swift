//
//  MondayModels.swift
//  FocusOS
//
//  Monday.com GraphQL API response models
//

import Foundation

// MARK: - GraphQL Response Wrapper

struct MondayGraphQLResponse<T: Codable>: Codable {
    let data: T?
    let errors: [MondayGraphQLError]?
    let accountId: Int?
    
    enum CodingKeys: String, CodingKey {
        case data
        case errors
        case accountId = "account_id"
    }
}

struct MondayGraphQLError: Codable {
    let message: String
    let locations: [MondayErrorLocation]?
    let path: [String]?
}

struct MondayErrorLocation: Codable {
    let line: Int
    let column: Int
}

// MARK: - OAuth Token Response

struct MondayTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Board Models

struct MondayBoardsResponse: Codable {
    let boards: [MondayBoard]
}

struct MondayBoard: Codable {
    let id: String
    let name: String
    let description: String?
    let itemsCount: Int?
    let boardKind: String?
    let state: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case itemsCount = "items_count"
        case boardKind = "board_kind"
        case state
    }
}

// MARK: - Item Models

struct MondayItemsResponse: Codable {
    let boards: [MondayBoardWithItems]
}

struct MondayBoardWithItems: Codable {
    let id: String
    let items: [MondayItem]
}

struct MondayItem: Codable {
    let id: String
    let name: String
    let board: MondayBoardReference?
    let columnValues: [MondayColumnValue]
    let creator: MondayUser?
    let createdAt: String?
    let updatedAt: String?
    let state: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case board
        case columnValues = "column_values"
        case creator
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case state
    }
}

struct MondayBoardReference: Codable {
    let id: String
    let name: String?
}

// MARK: - Column Value Models

struct MondayColumnValue: Codable {
    let id: String
    let text: String?
    let value: String?
    let type: String?
    let additionalInfo: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case value
        case type
        case additionalInfo = "additional_info"
    }
}

// MARK: - User Models

struct MondayUser: Codable {
    let id: String
    let name: String?
    let email: String?
    let title: String?
    let photoUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case title
        case photoUrl = "photo_url"
    }
}

// MARK: - User Response

struct MondayUserResponse: Codable {
    let users: [MondayUser]
}

