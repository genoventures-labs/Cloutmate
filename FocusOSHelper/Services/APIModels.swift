//
//  APIModels.swift
//  FocusOSHelper
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
struct PostInsightsResponse: Decodable {
    let data: [InsightData]
    
    struct InsightData: Decodable {
        let name: String
        let values: [InsightValue]
        
        struct InsightValue: Decodable {
            let numericValue: Double?
            let breakdown: [String: Double]?
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let doubleValue = try? container.decode(Double.self) {
                    numericValue = doubleValue
                    breakdown = nil
                } else if let stringValue = try? container.decode(String.self), let doubleValue = Double(stringValue) {
                    numericValue = doubleValue
                    breakdown = nil
                } else if let dictValue = try? container.decode([String: Double].self) {
                    numericValue = nil
                    breakdown = dictValue
                } else {
                    numericValue = nil
                    breakdown = nil
                }
            }
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

