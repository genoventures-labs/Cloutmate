//
//  CalendarComposerRequest.swift
//  Cloutmate
//
//  Request payload for opening the calendar composer drawer
//

import Foundation
import CloutmateShared

struct CalendarComposerRequest {
    var existingPost: CloutmateShared.Post?
    var prefilledDate: Date?
    
    init(existingPost: CloutmateShared.Post? = nil, prefilledDate: Date? = nil) {
        self.existingPost = existingPost
        self.prefilledDate = prefilledDate
    }
}

