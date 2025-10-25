//
//  InsightsPoller.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

final class InsightsPoller {
    static let shared = InsightsPoller()
    
    private var timer: Timer?
    
    private init() {}
    
    func start() {
        Logger.insights.info("Starting insights poller")
        timer = Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { [weak self] _ in
            self?.pollAllPosts()
        }
    }
    
    func fetchInsights(for postID: String) {
        Logger.insights.info("Fetching insights for post: \(postID)")
        Task {
            await fetchInsightsForPost(postID)
        }
    }
    
    private func pollAllPosts() {
        Logger.insights.info("Polling insights for all published posts")
        Task {
            await fetchInsightsForAllPosts()
        }
    }
    
    private func fetchInsightsForAllPosts() async {
        // Note: This would require access to SwiftData container
        // For now, log that polling is happening
        Logger.insights.info("Insights polling cycle completed")
    }
    
    private func fetchInsightsForPost(_ postID: String) async {
        do {
            // Get access token from Keychain
            let accessToken = try KeychainService.shared.getToken(forAccount: "threads_access_token")
            
            // Fetch insights from Meta API
            let insights = try await MetaAPIService.shared.getPostInsights(
                postID: postID,
                accessToken: accessToken
            )
            
            Logger.insights.info("Fetched insights for post: \(postID) - \(insights.data.count) metrics")
        } catch {
            Logger.insights.error("Failed to fetch insights for post \(postID): \(error.localizedDescription)")
        }
    }
}

