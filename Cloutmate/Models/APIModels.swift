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

// MARK: - Page Insights Period
enum PageInsightsPeriod: String, Codable {
    case day
    case week
    case days28 = "days_28"
    case month
    case lifetime
    
    var secondsDuration: Int {
        switch self {
        case .day:
            return 86400 // 1 day
        case .week:
            return 604800 // 7 days
        case .days28:
            return 2419200 // 28 days
        case .month:
            return 2592000 // ~30 days
        case .lifetime:
            return 0 // No duration for lifetime
        }
    }
}

// MARK: - Page Insights Response
struct PageInsightsResponse: Codable {
    let data: [PageInsightData]
    
    struct PageInsightData: Codable {
        let name: String
        let period: String
        let values: [PageInsightValue]
        let title: String?
        let description: String?
        let id: String?
        
        struct PageInsightValue: Codable {
            let value: String
            let endTime: String?
            
            enum CodingKeys: String, CodingKey {
                case value
                case endTime = "end_time"
            }
        }
    }
}

