//
//  MetaAPIConfig.swift
//  FocusOSShared
//
//  Configuration for Meta API - allows framework to access credentials
//

import Foundation

public final class MetaAPIConfig {
    public static let shared = MetaAPIConfig()
    
    public var appID: String = ""
    public var appSecret: String = ""
    public var redirectURI: String = "https://localhost/oauth/callback"
    
    private init() {}
    
    /// Initialize from main app's Info.plist or environment
    public func configure(from bundle: Bundle) {
        // Try environment first
        if let envID = ProcessInfo.processInfo.environment["MetaAppID"], !envID.isEmpty {
            appID = envID
        } else if let id = bundle.object(forInfoDictionaryKey: "MetaAppID") as? String, !id.isEmpty {
            appID = id
        }
        
        if let envSecret = ProcessInfo.processInfo.environment["MetaAppSecret"], !envSecret.isEmpty {
            appSecret = envSecret
        } else if let secret = bundle.object(forInfoDictionaryKey: "MetaAppSecret") as? String, !secret.isEmpty {
            appSecret = secret
        }
        
        if let envURI = ProcessInfo.processInfo.environment["MetaRedirectURI"], !envURI.isEmpty {
            redirectURI = envURI
        } else if let uri = bundle.object(forInfoDictionaryKey: "MetaRedirectURI") as? String {
            redirectURI = uri
        }
    }
}

