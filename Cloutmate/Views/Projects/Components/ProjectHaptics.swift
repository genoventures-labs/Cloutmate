//
//  ProjectHaptics.swift
//  Cloutmate
//
//  Haptic feedback utilities for Projects view interactions
//

import AppKit

enum ProjectHaptics {
    static func playSelection() {
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.generic, performanceTime: .default)
    }
    
    static func playDrag() {
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.generic, performanceTime: .default)
    }
    
    static func playSuccess() {
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.alignment, performanceTime: .default)
    }
}

