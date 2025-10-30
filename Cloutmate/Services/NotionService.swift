//
//  NotionService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import AuthenticationServices
import os.log

enum NotionAPIError: Error {
    case authenticationFailed
    case invalidResponse
    case networkError(Error)
    case apiError(NotionAPIError.ErrorDetail)
    case tokenExpired
    case databaseNotFound
    
    struct ErrorDetail {
        let message: String
        let code: String?
    }
}

final class NotionService {
    static let shared = NotionService()
    
    private let baseURL = "https://api.notion.com/v1"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Configuration
    
    var oauthClientId: String {
        // Check environment first (for development)
        if let envID = ProcessInfo.processInfo.environment["NotionOAuthClientId"], !envID.isEmpty {
            os_log("Using NotionOAuthClientId from environment variable", log: .default, type: .info)
            return envID
        }
        
        // Load from Config.plist (same way as GeminiService does it)
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let id = plist["NotionOAuthClientId"] as? String, !id.isEmpty {
            os_log("NotionOAuthClientId loaded from Config.plist: %{public}@", log: .default, type: .info, String(id.prefix(5)))
            return id
        }
        
        os_log("NotionOAuthClientId not found in Config.plist or environment variable NotionOAuthClientId", log: .default, type: .error)
        return ""
    }
    
    var oauthClientSecret: String {
        // Check environment first (for development)
        if let envSecret = ProcessInfo.processInfo.environment["NotionOAuthClientSecret"], !envSecret.isEmpty {
            os_log("Using NotionOAuthClientSecret from environment variable", log: .default, type: .info)
            return envSecret
        }
        
        // Load from Config.plist (same way as GeminiService does it)
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let secret = plist["NotionOAuthClientSecret"] as? String, !secret.isEmpty {
            os_log("NotionOAuthClientSecret loaded from Config.plist", log: .default, type: .info)
            return secret
        }
        
        os_log("NotionOAuthClientSecret not found in Config.plist or environment variable NotionOAuthClientSecret", log: .default, type: .error)
        return ""
    }
    
    var redirectURI: String {
        // Use the same callback URI as Facebook/Meta
        // This will be handled by your OAuth server which routes based on the platform parameter
        return "https://oauth.kosmicapps.com/auth/callback"
    }
    
    var callbackURLScheme: String {
        // Use cloutmate scheme - your server will handle routing
        return "cloutmate"
    }
    
    // MARK: - OAuth Flow
    
    func getOAuthURL() -> URL? {
        // Check if credentials are configured
        guard !oauthClientId.isEmpty else {
            Logger.notion.error("NotionOAuthClientId is empty. Configure credentials in Xcode target Info tab or environment variables.")
            return nil
        }
        
        guard !oauthClientSecret.isEmpty else {
            Logger.notion.error("NotionOAuthClientSecret is empty. Configure credentials in Xcode target Info tab or environment variables.")
            return nil
        }
        
        let scopes = "read"
        let state = "cloutmate_notion_\(UUID().uuidString.prefix(8))"
        
        // URL encode the redirect URI
        let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        
        // Include platform in state for server routing
        // State format: "notion:cloutmate_notion_abc123"
        let fullState = "notion:\(state)"
        
        let urlString = "https://api.notion.com/v1/oauth/authorize?" +
            "client_id=\(oauthClientId)&" +
            "redirect_uri=\(encodedRedirectURI)&" +
            "response_type=code&" +
            "owner=user&" +
            "state=\(fullState)"
        
        Logger.notion.info("Notion OAuth URL generated")
        Logger.notion.info("Redirect URI: \(self.redirectURI)")
        Logger.notion.info("Scopes: \(scopes)")
        Logger.notion.info("OAuth Client ID: \(self.oauthClientId)")
        Logger.notion.info("State: \(fullState)")
        
        return URL(string: urlString)
    }
    
    func exchangeCodeForToken(_ code: String) async throws -> NotionTokenResponse {
        let urlString = "https://api.notion.com/v1/oauth/token"
        
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidResponse
        }
        
        // URL encode the redirect URI
        let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        
        let body: [String: Any] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": encodedRedirectURI
        ]
        
        let auth = "\(oauthClientId):\(oauthClientSecret)"
        let authData = auth.data(using: .utf8)!
        let authString = "Basic \(authData.base64EncodedString())"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authString, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Exchanging code for token with URL: \(urlString)")
        
        let (data, response) = try await session.data(for: request)
        
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
            return try decoder.decode(NotionTokenResponse.self, from: data)
        } catch {
            Logger.notion.error("Token decoding failed: \(error)")
            
            // Try to get at least the access token even if decoding fails
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                Logger.notion.info("Extracted access token from raw JSON")
                // Return a minimal response with just the token
                return NotionTokenResponse(
                    accessToken: accessToken,
                    tokenType: json["token_type"] as? String ?? "bearer",
                    botId: json["bot_id"] as? String ?? "",
                    workspaceId: json["workspace_id"] as? String,
                    workspaceName: json["workspace_name"] as? String,
                    workspaceIcon: json["workspace_icon"] as? String,
                    refreshToken: json["refresh_token"] as? String,
                    owner: nil,
                    duplicatedTemplateId: json["duplicated_template_id"] as? String
                )
            }
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = jsonObject["error"] as? String {
                Logger.notion.error("OAuth error: \(errorMessage)")
                throw NotionAPIError.apiError(.init(message: errorMessage, code: nil))
            }
            throw NotionAPIError.networkError(error)
        }
    }
    
    // MARK: - Generic API Request
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        accessToken: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        let urlString = "\(baseURL)/\(endpoint)"
        
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionAPIError.invalidResponse
        }
        
        // Log the response for debugging
        Logger.notion.info("API Response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            Logger.notion.debug("API Response body: \(responseString)")
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            if httpResponse.statusCode == 401 {
                throw NotionAPIError.tokenExpired
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let apiError = try? decoder.decode(NotionAPIErrorResponse.self, from: data) {
                throw NotionAPIError.apiError(.init(message: apiError.message, code: apiError.code))
            }
            throw NotionAPIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError {
            Logger.notion.error("Decoding error: \(decodingError)")
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.notion.error("Response data: \(responseString.prefix(500))")
            }
            throw decodingError
        }
    }
    
    // MARK: - Database Operations
    
    func searchDatabases(accessToken: String) async throws -> NotionDatabaseListResponse {
        let body: [String: Any] = [
            "filter": [
                "value": "database",
                "property": "object"
            ]
        ]
        
        return try await request(
            endpoint: "search",
            method: "POST",
            accessToken: accessToken,
            body: body
        )
    }
    
    func queryDatabase(databaseId: String, accessToken: String, filter: [String: Any]? = nil) async throws -> NotionPageListResponse {
        var body: [String: Any] = [:]
        if let filter = filter {
            body["filter"] = filter
        }
        
        return try await request(
            endpoint: "databases/\(databaseId)/query",
            method: "POST",
            accessToken: accessToken,
            body: body.isEmpty ? nil : body
        )
    }
    
    func getDatabase(databaseId: String, accessToken: String) async throws -> NotionDatabaseResponse {
        return try await request(
            endpoint: "databases/\(databaseId)",
            accessToken: accessToken
        )
    }
    
    // MARK: - Page Operations
    
    func getPage(pageId: String, accessToken: String) async throws -> NotionPage {
        return try await request(
            endpoint: "pages/\(pageId)",
            accessToken: accessToken
        )
    }
    
    // MARK: - Token Refresh (if needed in future)
    
    func refreshToken(refreshToken: String) async throws -> NotionTokenResponse {
        let urlString = "https://api.notion.com/v1/oauth/token"
        
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidResponse
        }
        
        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let auth = "\(oauthClientId):\(oauthClientSecret)"
        guard let authData = auth.data(using: .utf8) else {
            throw NotionAPIError.invalidResponse
        }
        let authString = "Basic \(authData.base64EncodedString())"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authString, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NotionAPIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(NotionTokenResponse.self, from: data)
    }
}

