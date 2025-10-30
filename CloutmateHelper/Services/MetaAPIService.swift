//
//  MetaAPIService.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import os.log

// Import Platform from CloutmateShared
// Note: Platform should be accessible via import CloutmateShared

enum MetaAPIError: Error {
    case authenticationFailed
    case invalidResponse
    case networkError(Error)
    case apiError(MetaAPIError.ErrorDetail)
    
    struct ErrorDetail {
        let message: String
        let code: Int
    }
}

final class MetaAPIService {
    static let shared = MetaAPIService()
    
    private let baseURL = "https://graph.facebook.com/v21.0"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Configuration
    var appID: String {
        if let envID = ProcessInfo.processInfo.environment["MetaAppID"], !envID.isEmpty {
            return envID
        }
        if let id = Bundle.main.object(forInfoDictionaryKey: "MetaAppID") as? String, !id.isEmpty {
            return id
        }
        os_log("MetaAppID not found", log: .default, type: .error)
        return ""
    }
    
    // MARK: - Generic API Request
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        accessToken: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        var urlString = "\(baseURL)/\(endpoint)"
        
        let separator = endpoint.contains("?") ? "&" : "?"
        urlString += "\(separator)access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            throw MetaAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if method == "POST", let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MetaAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let decoder = JSONDecoder()
            if let apiError = try? decoder.decode(MetaAPIErrorResponse.self, from: data) {
                os_log("API Error: %{public}@ (code: %d)", log: .default, type: .error, apiError.error.message, apiError.error.code)
                throw MetaAPIError.apiError(.init(message: apiError.error.message, code: apiError.error.code))
            }
            throw MetaAPIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Publishing
    
    func publishPost(
        caption: String,
        mediaURLs: [String]?,
        platform: Platform,
        accessToken: String,
        pageID: String? = nil
    ) async throws -> PublishPostResponse {
        var endpoint = ""
        var body: [String: Any] = [:]
        
        if platform == .threads {
            endpoint = "\(appID)/threads"
            body["media_type"] = mediaURLs != nil ? "IMAGE" : "TEXT"
            body["text"] = caption
            if let mediaURLs = mediaURLs, !mediaURLs.isEmpty {
                body["media_urls"] = mediaURLs
            }
        } else {
            guard let pageID = pageID else {
                throw MetaAPIError.invalidResponse
            }
            endpoint = "\(pageID)/feed"
            body["message"] = caption
            body["privacy"] = ["value": "EVERYONE"]
            
            if let mediaURLs = mediaURLs, !mediaURLs.isEmpty {
                // Upload photos first, then use media_fbid
                let uploadedMediaIDs = try await uploadPhotos(mediaURLs: mediaURLs, pageID: pageID, accessToken: accessToken)
                body["attached_media"] = uploadedMediaIDs.map { ["media_fbid": $0] }
            }
        }
        
        return try await request(endpoint: endpoint, method: "POST", accessToken: accessToken, body: body)
    }
    
    // MARK: - Photo Upload
    
    func uploadPhoto(imageURL: String, pageID: String, accessToken: String) async throws -> String {
        let endpoint = "\(pageID)/photos"
        
        // Handle both file:// URLs and regular file paths
        let url: URL
        if imageURL.hasPrefix("file://") {
            url = URL(string: imageURL)!
        } else if imageURL.hasPrefix("/") {
            url = URL(fileURLWithPath: imageURL)
        } else {
            // Try as file path
            url = URL(fileURLWithPath: imageURL)
        }
        
        guard FileManager.default.fileExists(atPath: url.path),
              let imageData = try? Data(contentsOf: url) else {
            os_log("Failed to load image data from: %{public}@", log: .default, type: .error, imageURL)
            throw MetaAPIError.invalidResponse
        }
        
        // Create multipart form request
        var request = URLRequest(url: URL(string: "\(baseURL)/\(endpoint)?access_token=\(accessToken)")!)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                os_log("Photo upload failed: %{public}@", log: .default, type: .error, errorString)
            }
            throw MetaAPIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responseObj = try decoder.decode(PublishPostResponse.self, from: data)
        return responseObj.id
    }
    
    private func uploadPhotos(mediaURLs: [String], pageID: String, accessToken: String) async throws -> [String] {
        var uploadedIDs: [String] = []
        
        for mediaURL in mediaURLs {
            let mediaID = try await uploadPhoto(imageURL: mediaURL, pageID: pageID, accessToken: accessToken)
            uploadedIDs.append(mediaID)
        }
        
        return uploadedIDs
    }
    
    // MARK: - Insights
    
    func getPostInsights(postID: String, accessToken: String, platform: Platform = .threads) async throws -> PostInsightsResponse {
        let endpoint: String
        if platform == .facebook {
            endpoint = "\(postID)/insights?metric=post_impressions,post_engaged_users,post_reactions_by_type_total"
        } else {
            endpoint = "\(postID)/insights?metric=likes,comments,shares,reactions,impressions,reach"
        }
        return try await request(endpoint: endpoint, accessToken: accessToken)
    }
}

