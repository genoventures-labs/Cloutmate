//
//  CalendarComposerRequest.swift
//  FocusOS
//
//  Request payload for opening the calendar composer drawer
//

import Foundation
import FocusOSShared

struct CalendarComposerRequest {
    var existingPost: FocusOSShared.Post?
    var prefilledDate: Date?
    
    init(existingPost: FocusOSShared.Post? = nil, prefilledDate: Date? = nil) {
        self.existingPost = existingPost
        self.prefilledDate = prefilledDate
    }
}

