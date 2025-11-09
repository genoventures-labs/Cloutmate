//
//  ArchiveReintegrationService.swift
//  Cloutmate
//
//  Archives V2 - Handle restoration of archived items
//

import Foundation
import SwiftData
import CloutmateShared
import os.log

@MainActor
final class ArchiveReintegrationService {
    static let shared = ArchiveReintegrationService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ArchiveReintegration")
    
    private init() {}
    
    // MARK: - Reintegration
    
    func reintegrate(
        item: ArchiveItem,
        modelContext: ModelContext
    ) async throws {
        logger.info("Reintegrating archived \(item.entityType) \(item.id)")
        
        switch item {
        case .project(let project):
            project.status = .active
            project.archivedAt = nil
            // Trigger FocusGravityService reintegration
            ProjectFocusGravityService.shared.reintegrate(project: project, modelContext: modelContext)
            
        case .area(let area):
            area.status = .active
            area.archivedAt = nil
            
        case .note(let note):
            note.isArchived = false
            note.archivedAt = nil
            
        case .artifact(let artifact):
            // Restore to draft state if was archived
            if artifact.artifactState == .archived {
                artifact.artifactState = .draft
            }
            artifact.archivedAt = nil
            
        case .draft(let draft):
            draft.isArchived = false
            draft.archivedAt = nil
        }
        
        // Update Memory Graph relationships if needed
        try? MemoryGraphService.shared.updateArchivedStatus(
            for: item.id,
            isArchived: false,
            modelContext: modelContext
        )
        
        try modelContext.save()
        logger.info("Reintegrated \(item.entityType) \(item.id)")
    }
}

