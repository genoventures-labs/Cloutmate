//
//  APIModels.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

// MARK: - OAuth Token Response
struct OAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
}

// MARK: - Meta API Error Response
struct MetaAPIErrorResponse: Codable, Error {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String
        let code: Int
        let errorSubcode: Int?
        
        enum CodingKeys: String, CodingKey {
            case message, type, code
            case errorSubcode = "error_subcode"
        }
    }
}

// MARK: - Publish Post Response
struct PublishPostResponse: Codable {
    let id: String
    
    enum CodingKeys: String, CodingKey {
        case id
    }
}

// MARK: - Post Insights Response
struct PostInsightsResponse: Codable {
    let data: [InsightData]
    
    struct InsightData: Codable {
        let name: String
        let values: [InsightValue]
        
        struct InsightValue: Codable {
            let value: String
        }
    }
}

// MARK: - Account Information Response
struct AccountInfoResponse: Codable {
    let id: String
    let name: String?
    let username: String?
    let picture: PictureData?
    
    struct PictureData: Codable {
        let data: PictureURL
        
        struct PictureURL: Codable {
            let url: String
        }
    }
}

// MARK: - Facebook Pages Response
struct FacebookPagesResponse: Codable {
    let data: [FacebookPage]
    
    struct FacebookPage: Codable {
        let id: String
        let name: String
        let accessToken: String
        let category: String?
        let picture: PictureData?
        
        struct PictureData: Codable {
            let data: PictureURL
            
            struct PictureURL: Codable {
                let url: String
            }
        }
    }
}

