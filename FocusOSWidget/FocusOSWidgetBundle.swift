//
//  FocusOSWidgetBundle.swift
//  FocusOSWidget
//
//  Created by Mike Letts on 10/26/25.
//

import WidgetKit
import SwiftUI

@main
struct FocusOSWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusOSWidget()
        FocusOSWidgetControl()
    }
}
