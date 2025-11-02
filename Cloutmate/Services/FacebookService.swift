//
//  FacebookService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import CloutmateShared

final class FacebookService {
    static let shared = FacebookService()
    
    private let metaService = MetaAPIService.shared
    
    private init() {}
    
    func publishPost(
        caption: String,
        mediaURLs: [String]? = nil,
        pageID: String,
        accessToken: String
    ) async throws -> String {
        let response = try await metaService.publishPost(
            caption: caption,
            mediaURLs: mediaURLs,
            platform: .facebook,
            accessToken: accessToken,
            pageID: pageID
        )
        return response.id
    }
    
    func getAccountInfo(accessToken: String) async throws -> AccountInfoResponse {
        return try await metaService.getAccountInfo(accessToken: accessToken)
    }
    
    func getPages(accessToken: String) async throws -> [PageInfo] {
        struct PagesResponse: Codable {
            let data: [PageInfo]
        }
        
        let response: PagesResponse = try await metaService.request(
            endpoint: "me/accounts",
            accessToken: accessToken
        )
        return response.data
    }
}

struct PageInfo: Codable {
    let id: String
    let name: String
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case accessToken = "access_token"
    }
}

