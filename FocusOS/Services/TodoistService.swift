//
//  TodoistService.swift
//  FocusOS
//
//  Todoist OAuth 2.0 authentication and API client
//

import Foundation
import os.log

enum TodoistAPIError: Error {
    case authenticationFailed
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case tokenExpired
    case rateLimitExceeded
}

final class TodoistService {
    static let shared = TodoistService()
    
    private let baseURL = "https://api.todoist.com/rest/v2"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Configuration
    
    var oauthClientId: String {
        // Check environment first (for development)
        if let envID = ProcessInfo.processInfo.environment["TodoistOAuthClientId"], !envID.isEmpty {
            os_log("Using TodoistOAuthClientId from environment variable", log: .default, type: .info)
            return envID
        }
        
        // Load from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let id = plist["TodoistOAuthClientId"] as? String, !id.isEmpty {
            os_log("TodoistOAuthClientId loaded from Config.plist", log: .default, type: .info)
            return id
        }
        
        os_log("TodoistOAuthClientId not found in Config.plist or environment variable", log: .default, type: .error)
        return ""
    }
    
    var oauthClientSecret: String {
        // Check environment first (for development)
        if let envSecret = ProcessInfo.processInfo.environment["TodoistOAuthClientSecret"], !envSecret.isEmpty {
            os_log("Using TodoistOAuthClientSecret from environment variable", log: .default, type: .info)
            return envSecret
        }
        
        // Load from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let secret = plist["TodoistOAuthClientSecret"] as? String, !secret.isEmpty {
            os_log("TodoistOAuthClientSecret loaded from Config.plist", log: .default, type: .info)
            return secret
        }
        
        os_log("TodoistOAuthClientSecret not found in Config.plist or environment variable", log: .default, type: .error)
        return ""
    }
    
    var redirectURI: String {
        return "focusos://todoist-oauth"
    }
    
    // MARK: - OAuth Flow
    
    func getOAuthURL() -> URL? {
        guard !oauthClientId.isEmpty else {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "TodoistService").error("TodoistOAuthClientId is empty. Add TodoistOAuthClientId to Config.plist or set TodoistOAuthClientId environment variable.")
            return nil
        }
        
        guard !oauthClientSecret.isEmpty else {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "TodoistService").error("TodoistOAuthClientSecret is empty. Add TodoistOAuthClientSecret to Config.plist or set TodoistOAuthClientSecret environment variable.")
            return nil
        }
        
        let scopes = "data:read"
        let state = "focusos_todoist_\(UUID().uuidString.prefix(8))"
        
        // URL encode the redirect URI
        let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        
        let urlString = "https://todoist.com/oauth/authorize?" +
            "client_id=\(oauthClientId)&" +
            "scope=\(scopes)&" +
            "state=\(state)&" +
            "redirect_uri=\(encodedRedirectURI)"
        
        Logger(subsystem: "com.kosmicapps.FocusOS", category: "TodoistService").info("Todoist OAuth URL generated")
        
        return URL(string: urlString)
    }
    
    func exchangeCodeForToken(_ code: String) async throws -> TodoistTokenResponse {
        let urlString = "https://todoist.com/oauth/access_token"
        
        guard let url = URL(string: urlString) else {
            throw TodoistAPIError.invalidResponse
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
                throw TodoistAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    throw TodoistAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TodoistAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TodoistTokenResponse.self, from: data)
            
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "TodoistService").info("Token exchange successful")
            return tokenResponse
        } catch {
            if error is TodoistAPIError {
                throw error
            }
            throw TodoistAPIError.networkError(error)
        }
    }
    
    func refreshToken(_ refreshToken: String) async throws -> TodoistTokenResponse {
        let urlString = "https://todoist.com/oauth/access_token"
        
        guard let url = URL(string: urlString) else {
            throw TodoistAPIError.invalidResponse
        }
        
        let body: [String: Any] = [
            "client_id": oauthClientId,
            "client_secret": oauthClientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TodoistAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    throw TodoistAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TodoistAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TodoistTokenResponse.self, from: data)
            
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "TodoistService").info("Token refresh successful")
            return tokenResponse
        } catch {
            if error is TodoistAPIError {
                throw error
            }
            throw TodoistAPIError.networkError(error)
        }
    }
    
    // MARK: - API Client
    
    private func makeRequest(endpoint: String, method: String = "GET", accessToken: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw TodoistAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    func getProjects(accessToken: String) async throws -> [TodoistProject] {
        let request = try makeRequest(endpoint: "/projects", accessToken: accessToken)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TodoistAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw TodoistAPIError.tokenExpired
                }
                if httpResponse.statusCode == 429 {
                    throw TodoistAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TodoistAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let projects = try decoder.decode([TodoistProject].self, from: data)
            
            return projects
        } catch {
            if error is TodoistAPIError {
                throw error
            }
            throw TodoistAPIError.networkError(error)
        }
    }
    
    func getTasks(projectId: String? = nil, accessToken: String) async throws -> [TodoistTask] {
        var endpoint = "/tasks"
        if let projectId = projectId {
            endpoint += "?project_id=\(projectId)"
        }
        
        let request = try makeRequest(endpoint: endpoint, accessToken: accessToken)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TodoistAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw TodoistAPIError.tokenExpired
                }
                if httpResponse.statusCode == 429 {
                    throw TodoistAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TodoistAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let tasks = try decoder.decode([TodoistTask].self, from: data)
            
            return tasks
        } catch {
            if error is TodoistAPIError {
                throw error
            }
            throw TodoistAPIError.networkError(error)
        }
    }
    
    func getSections(projectId: String, accessToken: String) async throws -> [TodoistSection] {
        let endpoint = "/sections?project_id=\(projectId)"
        let request = try makeRequest(endpoint: endpoint, accessToken: accessToken)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TodoistAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw TodoistAPIError.tokenExpired
                }
                if httpResponse.statusCode == 429 {
                    throw TodoistAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TodoistAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let sections = try decoder.decode([TodoistSection].self, from: data)
            
            return sections
        } catch {
            if error is TodoistAPIError {
                throw error
            }
            throw TodoistAPIError.networkError(error)
        }
    }
    
    func getLabels(accessToken: String) async throws -> [TodoistLabel] {
        let request = try makeRequest(endpoint: "/labels", accessToken: accessToken)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TodoistAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw TodoistAPIError.tokenExpired
                }
                if httpResponse.statusCode == 429 {
                    throw TodoistAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TodoistAPIError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let labels = try decoder.decode([TodoistLabel].self, from: data)
            
            return labels
        } catch {
            if error is TodoistAPIError {
                throw error
            }
            throw TodoistAPIError.networkError(error)
        }
    }
}

