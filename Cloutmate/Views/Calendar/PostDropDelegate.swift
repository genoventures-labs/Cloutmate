//
//  PostDropDelegate.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
import CloutmateShared

struct PostDropDelegate: DropDelegate {
    let targetDate: Date
    let posts: [CloutmateShared.Post]
    let modelContext: ModelContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }
        
        let targetDate = self.targetDate
        
        _ = itemProvider.loadTransferable(type: PostDragInfo.self) { result in
            guard case .success(let dragInfo) = result else {
                return
            }
            
		_Concurrency.Task { @MainActor in
                // Find the post by ID from the posts array
                guard let post = self.posts.first(where: { $0.id == dragInfo.postID }) else {
                    return
                }
                
                post.scheduledDate = targetDate
                post.updatedAt = Date()
            }
        }
        
        return true
    }
}

// PostDragInfo struct for dragging posts
struct PostDragInfo: Codable, Transferable {
    let postID: UUID
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

// Extension to make Post draggable
extension CloutmateShared.Post {
    var dragInfo: PostDragInfo {
        PostDragInfo(postID: self.id)
    }
}

