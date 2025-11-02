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
            // Shared models
            Post.self,
            Template.self,
            PlatformAccount.self,
            PerformancePrediction.self,
            RecyclablePost.self,
            ContentTopic.self,
            ContentBalance.self,
            PostingTimeTest.self,
            OptimalPostingTime.self,
            CustomPostProperty.self,
            PostView.self,
            HashtagPerformance.self,
            HashtagSet.self,
            // PARA models used by dashboard cards
            Note.self,
            Task.self,
            Project.self,
            InboxItem.self
        ])
        
        let appGroupID = "group.kosmicapps.cloutmate"
        
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Unable to access app group container")
        }
        
        // Use the v2 store filename to match the main app schema
        let storeURL = appGroupURL.appendingPathComponent("Cloutmate_v2.sqlite")
        
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

