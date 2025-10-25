//
//  MetaAPIService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import AuthenticationServices
import os.log

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
        
        if method == "GET" {
            // Check if endpoint already has query parameters
            let separator = endpoint.contains("?") ? "&" : "?"
            urlString += "\(separator)access_token=\(accessToken)"
        }
        
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
            if let mediaURLs = mediaURLs, !mediaURLs.isEmpty {
                body["attached_media"] = mediaURLs.map { ["media_fbid": $0] }
            }
        }
        
        return try await request(endpoint: endpoint, method: "POST", accessToken: accessToken, body: body)
    }
    
    // MARK: - Insights
    
    func getPostInsights(postID: String, accessToken: String) async throws -> PostInsightsResponse {
        let endpoint = "\(postID)/insights?metric=likes,comments,shares,reactions,impressions,reach"
        return try await request(endpoint: endpoint, accessToken: accessToken)
    }
}

