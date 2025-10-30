//
//  ThreadsService.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

final class ThreadsService {
    static let shared = ThreadsService()
    
    private let metaService = MetaAPIService.shared
    
    private init() {}
    
    func publishPost(
        caption: String,
        mediaURLs: [String]? = nil,
        accessToken: String
    ) async throws -> String {
        let response = try await metaService.publishPost(
            caption: caption,
            mediaURLs: mediaURLs,
            platform: .threads,
            accessToken: accessToken,
            pageID: nil
        )
        return response.id
    }
}

