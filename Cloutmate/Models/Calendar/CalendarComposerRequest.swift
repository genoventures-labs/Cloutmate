//
//  CalendarComposerRequest.swift
//  Cloutmate
//
//  Shared payload for opening the calendar composer drawer.
//

import Foundation
import CloutmateShared

struct CalendarComposerRequest {
    let existingPost: CloutmateShared.Post?
    let prefilledDate: Date?
    
    init(existingPost: CloutmateShared.Post? = nil, prefilledDate: Date? = nil) {
        self.existingPost = existingPost
        self.prefilledDate = prefilledDate
    }
}
