//
//  CloutmateWidgetBundle.swift
//  CloutmateWidget
//
//  Created by Mike Letts on 10/26/25.
//

import WidgetKit
import SwiftUI

@main
struct CloutmateWidgetBundle: WidgetBundle {
    var body: some Widget {
        CloutmateWidget()
        CloutmateWidgetControl()
    }
}
