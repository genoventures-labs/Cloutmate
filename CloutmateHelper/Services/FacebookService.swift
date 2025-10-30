//
//  FacebookService.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

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
}

