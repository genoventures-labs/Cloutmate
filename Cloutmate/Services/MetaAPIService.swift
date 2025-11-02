//
//  MetaAPIService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import AuthenticationServices
import os.log
import CloutmateShared

enum MetaAPIError: Error {
    case authenticationFailed
    case invalidResponse
    case networkError(Error)
    case apiError(MetaAPIError.ErrorDetail)
    case metricsUnavailable(String)
    
    struct ErrorDetail {
        let message: String
        let code: Int
    }
}

extension MetaAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication with Meta failed. Please reconnect your account."
        case .invalidResponse:
            return "Meta returned an unexpected response."
        case .networkError(let error):
            return error.localizedDescription
        case .apiError(let detail):
            return detail.message
        case .metricsUnavailable(let message):
            return message
        }
    }
}

final class MetaAPIService {
    static let shared = MetaAPIService()
    
    private let baseURL = "https://graph.facebook.com/v21.0"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Configuration
    // Loads from Info.plist or environment variables (environment takes precedence)
    var appID: String {
        // Check environment first (for development)
        if let envID = ProcessInfo.processInfo.environment["MetaAppID"], !envID.isEmpty {
            Logger.metaAPI.info("Using MetaAppID from environment variable")
            return envID
        }
        
        // Fall back to Info.plist
        if let id = Bundle.main.object(forInfoDictionaryKey: "MetaAppID") as? String, !id.isEmpty {
            Logger.metaAPI.info("MetaAppID loaded from Info.plist: \(id.prefix(5))...")
            return id
        }
        
        Logger.metaAPI.error("MetaAppID not found. Set in Info.plist or environment variable MetaAppID")
        return ""
    }
    
    var appSecret: String {
        // Check environment first (for development)
        if let envSecret = ProcessInfo.processInfo.environment["MetaAppSecret"], !envSecret.isEmpty {
            Logger.metaAPI.info("Using MetaAppSecret from environment variable")
            return envSecret
        }
        
        // Fall back to Info.plist
        if let secret = Bundle.main.object(forInfoDictionaryKey: "MetaAppSecret") as? String, !secret.isEmpty {
            Logger.metaAPI.info("MetaAppSecret loaded from Info.plist")
            return secret
        }
        
        Logger.metaAPI.error("MetaAppSecret not found. Set in Info.plist or environment variable MetaAppSecret")
        return ""
    }
    
    var redirectURI: String {
        // Check environment first
        if let envURI = ProcessInfo.processInfo.environment["MetaRedirectURI"], !envURI.isEmpty {
            return envURI
        }
        
        // Fall back to Info.plist or default
        return Bundle.main.object(forInfoDictionaryKey: "MetaRedirectURI") as? String ?? "https://localhost/oauth/callback"
    }
    
    func getRedirectURI(for platform: Platform) -> String {
        let baseURI = redirectURI
        return "\(baseURI)?platform=\(platform.rawValue)"
    }
    
    var callbackURLScheme: String {
        // Extract the scheme from redirectURI for ASWebAuthenticationSession
        if let url = URL(string: redirectURI), let scheme = url.scheme {
            return scheme
        }
        return "cloutmate" // Fallback
    }
    
    // MARK: - OAuth Flow
    
    func getOAuthURL(platform: Platform) -> URL? {
        // Check if credentials are configured
        guard !appID.isEmpty else {
            Logger.metaAPI.error("MetaAppID is empty. Configure credentials in Xcode target Info tab or environment variables.")
            return nil
        }
        
        guard !appSecret.isEmpty else {
            Logger.metaAPI.error("MetaAppSecret is empty. Configure credentials in Xcode target Info tab or environment variables.")
            return nil
        }
        
        let scopes = platform == .threads 
            ? "threads_basic,threads_content_publish"
            : "pages_show_list,pages_manage_posts,pages_read_engagement,read_insights"
        
        // Generate a unique state parameter for debugging
        let state = "cloutmate_\(platform.rawValue)_\(UUID().uuidString.prefix(8))"
        
        let platformRedirectURI = getRedirectURI(for: platform)
        
        let urlString = "https://www.facebook.com/v21.0/dialog/oauth?" +
            "client_id=\(appID)&" +
            "redirect_uri=\(platformRedirectURI)&" +
            "scope=\(scopes)&" +
            "response_type=code&" +
            "state=\(state)"
        
        Logger.metaAPI.info("OAuth URL generated for \(platform.rawValue)")
        Logger.metaAPI.info("Base Redirect URI: \(self.redirectURI)")
        Logger.metaAPI.info("Platform Redirect URI: \(platformRedirectURI)")
        Logger.metaAPI.info("Scopes: \(scopes)")
        Logger.metaAPI.info("App ID: \(self.appID)")
        Logger.metaAPI.info("State: \(state)")
        print("🔍 DEBUG: Complete OAuth URL: \(urlString)")
        print("🔍 DEBUG: Please verify this URL in Meta App Dashboard:")
        print("  - App ID matches: \(self.appID)")
        print("  - Platform Redirect URI matches: \(platformRedirectURI)")
        print("  - Scopes are approved: \(scopes)")
        return URL(string: urlString)
    }
    
    func exchangeCodeForToken(_ code: String, platform: Platform) async throws -> OAuthTokenResponse {
        // Get platform-specific redirect URI
        let platformRedirectURI = getRedirectURI(for: platform)
        
        // URL encode the redirect URI
        let encodedRedirectURI = platformRedirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? platformRedirectURI
        
        let urlString = "\(baseURL)/oauth/access_token?" +
            "client_id=\(appID)&" +
            "client_secret=\(appSecret)&" +
            "redirect_uri=\(encodedRedirectURI)&" +
            "code=\(code)"
        
        guard let url = URL(string: urlString) else {
            throw MetaAPIError.invalidResponse
        }
        
        print("Exchanging code for token with URL: \(urlString)")
        
        let (data, response) = try await session.data(from: url)
        
        // Log the raw response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("Token exchange response status: \(httpResponse.statusCode)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Token exchange response: \(responseString)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(OAuthTokenResponse.self, from: data)
        } catch {
            if let apiError = try? decoder.decode(MetaAPIErrorResponse.self, from: data) {
                print("API Error: \(apiError.error.message) (code: \(apiError.error.code))")
                throw MetaAPIError.apiError(.init(message: apiError.error.message, code: apiError.error.code))
            }
            print("Decoding error: \(error)")
            throw MetaAPIError.networkError(error)
        }
    }
    
    // MARK: - Generic API Request
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        accessToken: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        var urlString = "\(baseURL)/\(endpoint)"
        
        // Always add access_token to URL as query parameter
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
        
        // Log the response for debugging
        print("API Response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("API Response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            let decoder = JSONDecoder()
            if let apiError = try? decoder.decode(MetaAPIErrorResponse.self, from: data) {
                print("API Error: \(apiError.error.message) (code: \(apiError.error.code))")
                throw MetaAPIError.apiError(.init(message: apiError.error.message, code: apiError.error.code))
            }
            throw MetaAPIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Account Information
    
    func getAccountInfo(accessToken: String) async throws -> AccountInfoResponse {
        print("Fetching account info with token: \(accessToken.prefix(20))...")
        let response: AccountInfoResponse = try await request(endpoint: "me?fields=id,name,username,picture", accessToken: accessToken)
        print("Account info received: \(response)")
        return response
    }
    
    func getFacebookPages(accessToken: String) async throws -> FacebookPagesResponse {
        print("Fetching Facebook Pages with token: \(accessToken.prefix(20))...")
        let response: FacebookPagesResponse = try await request(endpoint: "me/accounts?fields=id,name,access_token,category,picture", accessToken: accessToken)
        print("Facebook Pages received: \(response)")
        return response
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
            Logger.metaAPI.error("Failed to load image data from: \(imageURL)")
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
                Logger.metaAPI.error("Photo upload failed: \(errorString)")
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
            // Facebook Page post insights
            endpoint = "\(postID)/insights?metric=post_impressions,post_engaged_users,post_reactions_by_type_total"
        } else {
            // Threads insights
            endpoint = "\(postID)/insights?metric=likes,comments,shares,reactions,impressions,reach"
        }
        return try await request(endpoint: endpoint, accessToken: accessToken)
    }
    
    // MARK: - Page Insights
    
    func getPageInsights(
        pageID: String,
        accessToken: String,
        period: PageInsightsPeriod = .week,
        since: Int? = nil,
        until: Int? = nil
    ) async throws -> PageInsightsResponse {
        // Build metrics list with currently supported Facebook Page Insights metrics (Graph API v19+)
        // Note: Only request metrics that are universally available.
        // Many pages (especially creator/digital creator pages) don't have access to engagement metrics.
        // Different metrics support different periods:
        // - page_fans: lifetime only
        // - page_impressions: day/week/days_28 (universally available)
        var metrics: [String]
        if period == .lifetime {
            metrics = ["page_fans"]
        } else {
            // Only request page_impressions - it's the most reliable metric
            // page_engaged_users requires pages_read_engagement permission and is often unavailable
            metrics = ["page_impressions"]
        }
        
        guard !metrics.isEmpty else {
            Logger.metaAPI.error("No valid metrics available for period \(period.rawValue)")
            return PageInsightsResponse(data: [])
        }
        
        func buildEndpoint(for metrics: [String]) -> String {
            var endpoint = "\(pageID)/insights?metric=\(metrics.joined(separator: ","))"
            endpoint += "&period=\(period.rawValue)"
            if period != .lifetime {
                let untilDate = until ?? Int(Date().timeIntervalSince1970)
                let sinceDate: Int
                if let customSince = since {
                    sinceDate = customSince
                } else {
                    sinceDate = untilDate - period.secondsDuration
                }
                endpoint += "&since=\(sinceDate)&until=\(untilDate)"
            }
            return endpoint
        }
        
        do {
            let endpoint = buildEndpoint(for: metrics)
            return try await request(endpoint: endpoint, accessToken: accessToken)
        } catch MetaAPIError.apiError(let detail) where detail.code == 100 && detail.message.contains("valid insights metric") {
            Logger.metaAPI.error("Meta API rejected metrics \(metrics.joined(separator: ",")) for page \(pageID). Falling back to single-metric requests.")
            var aggregatedData: [PageInsightsResponse.PageInsightData] = []
            for metric in metrics {
                do {
                    let endpoint = buildEndpoint(for: [metric])
                    let response: PageInsightsResponse = try await request(endpoint: endpoint, accessToken: accessToken)
                    aggregatedData.append(contentsOf: response.data)
                } catch {
                    Logger.metaAPI.error("Failed to fetch metric \(metric) for page \(pageID): \(error.localizedDescription)")
                }
            }
            if !aggregatedData.isEmpty {
                return PageInsightsResponse(data: aggregatedData)
            }
            throw MetaAPIError.metricsUnavailable("Meta returned (#100) for every metric. This usually means the page does not have access to Insights data for these metrics or the required permissions are missing.")
        }
    }
}

