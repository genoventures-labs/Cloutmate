//
//  MondayService.swift
//  FocusOS
//
//  Monday.com OAuth 2.0 authentication and GraphQL API client
//

import Foundation
import os.log

enum MondayAPIError: Error {
    case authenticationFailed
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case graphQLError([MondayGraphQLError])
    case rateLimitExceeded
}

final class MondayService {
    static let shared = MondayService()
    
    private let baseURL = "https://api.monday.com/v2"
    private let oauthBaseURL = "https://auth.monday.com/oauth2"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Configuration
    
    var oauthClientId: String {
        // Check environment first (for development)
        if let envID = ProcessInfo.processInfo.environment["MondayOAuthClientId"], !envID.isEmpty {
            os_log("Using MondayOAuthClientId from environment variable", log: .default, type: .info)
            return envID
        }
        
        // Load from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let id = plist["MondayOAuthClientId"] as? String, !id.isEmpty {
            os_log("MondayOAuthClientId loaded from Config.plist", log: .default, type: .info)
            return id
        }
        
        os_log("MondayOAuthClientId not found in Config.plist or environment variable", log: .default, type: .error)
        return ""
    }
    
    var oauthClientSecret: String {
        // Check environment first (for development)
        if let envSecret = ProcessInfo.processInfo.environment["MondayOAuthClientSecret"], !envSecret.isEmpty {
            os_log("Using MondayOAuthClientSecret from environment variable", log: .default, type: .info)
            return envSecret
        }
        
        // Load from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let secret = plist["MondayOAuthClientSecret"] as? String, !secret.isEmpty {
            os_log("MondayOAuthClientSecret loaded from Config.plist", log: .default, type: .info)
            return secret
        }
        
        os_log("MondayOAuthClientSecret not found in Config.plist or environment variable", log: .default, type: .error)
        return ""
    }
    
    var redirectURI: String {
        return "https://oauth.kosmicapps.com/auth/callback"
    }
    
    // MARK: - OAuth Flow
    
    func getOAuthURL() -> URL? {
        guard !oauthClientId.isEmpty else {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "MondayService").error("MondayOAuthClientId is empty. Add MondayOAuthClientId to Config.plist or set MondayOAuthClientId environment variable.")
            return nil
        }
        
        let scopes = "boards:read boards:write"
        let state = "monday:focusos_monday_\(UUID().uuidString.prefix(8))"
        
        // URL encode the redirect URI
        let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        
        let urlString = "\(oauthBaseURL)/authorize?" +
            "client_id=\(oauthClientId)&" +
            "redirect_uri=\(encodedRedirectURI)&" +
            "scope=\(scopes)&" +
            "state=\(state)"
        
        Logger(subsystem: "com.kosmicapps.FocusOS", category: "MondayService").info("Monday.com OAuth URL generated")
        
        return URL(string: urlString)
    }
    
    func exchangeCodeForToken(_ code: String) async throws -> MondayTokenResponse {
        let urlString = "\(oauthBaseURL)/token"
        
        guard let url = URL(string: urlString) else {
            throw MondayAPIError.invalidResponse
        }
        
        // URL encode the redirect URI
        let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        
        let body: [String: Any] = [
            "client_id": oauthClientId,
            "client_secret": oauthClientSecret,
            "code": code,
            "redirect_uri": encodedRedirectURI
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MondayAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    throw MondayAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw MondayAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(MondayTokenResponse.self, from: data)
            
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "MondayService").info("Token exchange successful")
            return tokenResponse
        } catch {
            if error is MondayAPIError {
                throw error
            }
            throw MondayAPIError.networkError(error)
        }
    }
    
    // MARK: - GraphQL API
    
    func executeGraphQL<T: Codable>(_ query: String, variables: [String: Any]? = nil, accessToken: String) async throws -> T {
        guard let url = URL(string: baseURL) else {
            throw MondayAPIError.invalidResponse
        }
        
        var requestBody: [String: Any] = ["query": query]
        if let variables = variables {
            requestBody["variables"] = variables
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MondayAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    throw MondayAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw MondayAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let graphQLResponse = try decoder.decode(MondayGraphQLResponse<T>.self, from: data)
            
            // Check for GraphQL errors
            if let errors = graphQLResponse.errors, !errors.isEmpty {
                throw MondayAPIError.graphQLError(errors)
            }
            
            guard let data = graphQLResponse.data else {
                throw MondayAPIError.invalidResponse
            }
            
            return data
        } catch {
            if error is MondayAPIError {
                throw error
            }
            throw MondayAPIError.networkError(error)
        }
    }
    
    func getBoards(accessToken: String) async throws -> [MondayBoard] {
        let query = """
        query {
          boards {
            id
            name
            description
            items_count
            board_kind
            state
          }
        }
        """
        
        let response: MondayBoardsResponse = try await executeGraphQL(query, accessToken: accessToken)
        return response.boards
    }
    
    func getBoardItems(boardId: String, accessToken: String) async throws -> [MondayItem] {
        let query = """
        query($boardId: [ID!]) {
          boards(ids: $boardId) {
            id
            items {
              id
              name
              board {
                id
                name
              }
              column_values {
                id
                text
                value
                type
                additional_info
              }
              creator {
                id
                name
                email
              }
              created_at
              updated_at
              state
            }
          }
        }
        """
        
        let variables: [String: Any] = ["boardId": [boardId]]
        let response: MondayItemsResponse = try await executeGraphQL(query, variables: variables, accessToken: accessToken)
        
        // Extract items from the first board (we only query one board)
        guard let board = response.boards.first else {
            return []
        }
        
        return board.items
    }
    
    func getUser(accessToken: String) async throws -> MondayUser {
        let query = """
        query {
          users(limit: 1) {
            id
            name
            email
            title
            photo_url
          }
        }
        """
        
        let response: MondayUserResponse = try await executeGraphQL(query, accessToken: accessToken)
        guard let user = response.users.first else {
            throw MondayAPIError.invalidResponse
        }
        return user
    }
}

