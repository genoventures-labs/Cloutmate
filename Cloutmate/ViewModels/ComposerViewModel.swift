//
//  ComposerViewModel.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ComposerViewModel {
    var isPresented: Bool = false
    
    func present() {
        isPresented = true
    }
    
    func dismiss() {
        isPresented = false
    }
}

