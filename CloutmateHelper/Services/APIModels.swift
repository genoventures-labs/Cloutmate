//
//  APIModels.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

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

