//
//  SharedDataManager.swift
//  CloutmateShared
//
//  Shared Data Management for App Group
//

import Foundation
import SwiftData

public final class SharedDataManager {
    public static func createSharedModelContainer() -> ModelContainer {
        let schema = Schema([
            Post.self,
            Draft.self,
            Template.self,
            PlatformAccount.self,
            InsightSnapshot.self,
            AIMessage.self,
            AIConversation.self,
            PerformancePrediction.self,
            RecyclablePost.self,
            ContentTopic.self,
            ContentBalance.self,
            PostingTimeTest.self,
            OptimalPostingTime.self,
            CustomPostProperty.self,
            PostView.self,
            HashtagPerformance.self,
            HashtagSet.self
        ])
        
        let appGroupID = "group.kosmicapps.cloutmate"
        
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Unable to access app group container")
        }
        
        let storeURL = appGroupURL.appendingPathComponent("Cloutmate.sqlite")
        
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

