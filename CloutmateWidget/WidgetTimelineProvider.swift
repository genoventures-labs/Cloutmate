//
//  WidgetTimelineProvider.swift
//  CloutmateWidget
//

import WidgetKit
import SwiftData
import CloutmateShared

// Import Post model from shared framework
// Post type is defined in CloutmateShared framework

struct WidgetEntry: TimelineEntry {
    let date: Date
    let scheduledCount: Int
    let nextPostDate: Date?
    let nextPostCaption: String?
}

struct CloutmateTimelineProvider: TimelineProvider {
    typealias Entry = WidgetEntry
    
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), scheduledCount: 3, nextPostDate: Date().addingTimeInterval(3600), nextPostCaption: "Example scheduled post")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date(), scheduledCount: 0, nextPostDate: nil, nextPostCaption: nil)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Access shared SwiftData container via app group
        _Concurrency.Task { @MainActor in
            var scheduledCount = 0
            var nextPostDate: Date? = nil
            var nextPostCaption: String? = nil
            
            do {
                let container = SharedDataManager.createSharedModelContainer()
                let modelContext = container.mainContext
                
                // Fetch scheduled posts
                let descriptor = FetchDescriptor<Post>(
                    predicate: #Predicate<Post> { post in
                        post.status == "scheduled"
                    },
                    sortBy: [SortDescriptor<Post>(\.scheduledDate)]
                )
                
                let posts = try modelContext.fetch(descriptor)
                scheduledCount = posts.count
                
                if let firstPost = posts.first {
                    nextPostDate = firstPost.scheduledDate
                    nextPostCaption = firstPost.caption
                }
            } catch {
                // If data fetch fails, use defaults
                scheduledCount = 0
                nextPostDate = nil
                nextPostCaption = nil
            }
            
            let entry = WidgetEntry(
                date: currentDate,
                scheduledCount: scheduledCount,
                nextPostDate: nextPostDate,
                nextPostCaption: nextPostCaption
            )
            
            // Next refresh in 15 minutes
            let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}
