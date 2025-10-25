//
//  MainWindowView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData

enum TabIdentifier: String, CaseIterable {
    case dashboard = "Dashboard"
    case calendar = "Calendar"
    case list = "List"
    case drafts = "Drafts"
    case insights = "Insights"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .calendar: return "calendar"
        case .list: return "list.bullet"
        case .drafts: return "doc.text.fill"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainWindowView: View {
    @State private var selectedTab: TabIdentifier = .dashboard
    @State private var composerViewModel = ComposerViewModel()
    
    var body: some View {
        NavigationSplitView {
            Sidebar(selectedTab: $selectedTab, composerViewModel: composerViewModel)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        } detail: {
            contentView
        }
        .sheet(isPresented: $composerViewModel.isPresented) {
            ComposerWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { _ in
            composerViewModel.present()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
            if let tab = notification.object as? TabIdentifier {
                selectedTab = tab
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .calendar:
            CalendarView()
        case .list:
            ListTableView()
        case .drafts:
            DraftsView()
        case .insights:
            InsightsView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    MainWindowView()
        .modelContainer(for: [Post.self, Draft.self, Template.self])
}

