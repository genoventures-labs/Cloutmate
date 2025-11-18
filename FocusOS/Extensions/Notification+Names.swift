//
//  Notification+Names.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation

extension Notification.Name {
    static let openComposer = Notification.Name("openComposer")
    static let switchTab = Notification.Name("switchTab")
    static let focusSessionStatusChanged = Notification.Name("focusSessionStatusChanged")
    static let openContextualCreate = Notification.Name("openContextualCreate")
    static let currentTabUpdated = Notification.Name("CurrentTabUpdated")
    static let showCreateNote = Notification.Name("showCreateNote")
    static let showCreateTask = Notification.Name("showCreateTask")
    static let showCreateProject = Notification.Name("showCreateProject")
    static let showQuickCapture = Notification.Name("showQuickCapture")
    static let showVoiceMemo = Notification.Name("showVoiceMemo")
    static let showArtifactComposer = Notification.Name("showArtifactComposer")
    static let openNoteDetail = Notification.Name("openNoteDetail")
    static let openJournalEntry = Notification.Name("openJournalEntry")
    static let openDraftEditor = Notification.Name("openDraftEditor")
    static let draftPublished = Notification.Name("draftPublished")
    static let openInboxCapture = Notification.Name("openInboxCapture")
    static let openResourceDetail = Notification.Name("openResourceDetail")
    static let showResourceImport = Notification.Name("showResourceImport")
    static let openAIAssistantThread = Notification.Name("openAIAssistantThread")
    static let openEntity = Notification.Name("openEntity")
    static let openAreaDetail = Notification.Name("openAreaDetail")
    static let startPendingFocusSession = Notification.Name("startPendingFocusSession")
    static let focusSessionStarted = Notification.Name("focusSessionStarted")
    static let focusSessionEnded = Notification.Name("focusSessionEnded")
}

// MARK: - Focus Session Parameters

struct PendingFocusSessionParams {
    let objective: String
    let plannedDuration: TimeInterval
    let targetObjectId: UUID?
    let targetObjectType: String?
    let shouldAutoStart: Bool
    
    init(
        objective: String,
        plannedDuration: TimeInterval,
        targetObjectId: UUID? = nil,
        targetObjectType: String? = nil,
        shouldAutoStart: Bool = false
    ) {
        self.objective = objective
        self.plannedDuration = plannedDuration
        self.targetObjectId = targetObjectId
        self.targetObjectType = targetObjectType
        self.shouldAutoStart = shouldAutoStart
    }
}

