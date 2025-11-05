//
//  MomentumSettings.swift
//  Cloutmate
//
//  Shared settings for momentum-driven adaptations.
//

import Foundation
import Combine

@MainActor
final class MomentumSettings: ObservableObject {
    static let shared = MomentumSettings()

    private struct Keys {
        static let adjustmentsEnabled = "momentum.adjustmentsEnabled"
    }

    @Published var adjustmentsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(adjustmentsEnabled, forKey: Keys.adjustmentsEnabled)
        }
    }
    
    private init() {
        self.adjustmentsEnabled = UserDefaults.standard.object(forKey: Keys.adjustmentsEnabled) as? Bool ?? true
    }
}


