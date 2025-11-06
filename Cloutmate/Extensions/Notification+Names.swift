//
//  Notification+Names.swift
//  Cloutmate
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
}

