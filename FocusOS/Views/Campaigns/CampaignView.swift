//
//  CampaignView.swift
//  FocusOS
//
//  Campaign management and tracking
//

import SwiftUI
import SwiftData
import FocusOSShared

struct CampaignView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]
    @Query private var allPosts: [FocusOSShared.Post]
    @Query private var projects: [FocusOSShared.Project]
    
    @State private var isCreateDrawerVisible = false
    @State private var selectedCampaign: Campaign?
    
    var activeCampaigns: [Campaign] {
        campaigns.filter { $0.status == .active || $0.status == .scheduled }
    }
    
    var body: some View {
        ZStack {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Campaigns")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                        GlassButton("New Campaign", icon: "plus.circle", tintColor: .kosmicBlue, action: presentCreateDrawer)
                }
                .padding()
                
                // Active campaigns
                if !activeCampaigns.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("Active Campaigns")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        ForEach(activeCampaigns) { campaign in
                            CampaignCard(campaign: campaign, posts: allPosts, projects: projects)
                                .onTapGesture {
                                    selectedCampaign = campaign
                                }
                                .padding(.horizontal)
                        }
                    }
                }
                
                // All campaigns
                if !campaigns.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(Color.kosmicBlue)
                            Text("All Campaigns")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        ForEach(campaigns) { campaign in
                            CampaignCard(campaign: campaign, posts: allPosts, projects: projects)
                                .onTapGesture {
                                    selectedCampaign = campaign
                                }
                                .padding(.horizontal)
                        }
                    }
                }
                
                // Empty state
                if campaigns.isEmpty {
                    ContentUnavailableView(
                        "No Campaigns",
                        systemImage: "megaphone.fill",
                        description: Text("Create a campaign to organize multiple posts")
                    )
                    .frame(height: 200)
                    .padding()
                }
            }
        }
        .background(Color.clear)
            .opacity(isCreateDrawerVisible ? 0 : 1)
            
            if isCreateDrawerVisible {
                CreateCampaignDrawer(isPresented: $isCreateDrawerVisible)
                    .transition(.move(edge: .trailing))
            }
        }
        .navigationTitle("Campaigns")
        .sheet(item: $selectedCampaign) { campaign in
            CampaignDetailSheet(campaign: campaign, posts: allPosts, projects: projects)
        }
    }
    
    private func presentCreateDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isCreateDrawerVisible = true
        }
    }
}

struct CampaignCard: View {
    let campaign: Campaign
    let posts: [FocusOSShared.Post]
    let projects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(Color.kosmicBlue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.title)
                        .font(.headline)
                    
                    if let goal = campaign.goal {
                        Text(goal)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                CampaignStatusBadge(status: campaign.status)
            }
            
            // Stats
            HStack(spacing: 16) {
                Label("\(campaign.postIds.count) posts", systemImage: "square.and.pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let project = projects.first(where: { $0.id == campaign.projectId }) {
                    Label(project.title, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Progress bar
            let progress = calculateProgress()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.kosmicBlue, .kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
    
    private func calculateProgress() -> Double {
        let campaignPosts = posts.filter { campaign.postIds.contains($0.id) }
        let publishedCount = campaignPosts.filter { $0.postStatus == .published }.count
        let totalCount = campaignPosts.count
        
        guard totalCount > 0 else { return 0.0 }
        return Double(publishedCount) / Double(totalCount)
    }
}

struct CampaignDetailSheet: View {
    let campaign: Campaign
    let posts: [FocusOSShared.Post]
    let projects: [Project]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var campaignPosts: [FocusOSShared.Post] {
        posts.filter { campaign.postIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    CampaignHeaderSection(campaign: campaign, posts: campaignPosts)
                    
                    // Goal
                    if let goal = campaign.goal {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal")
                                .font(.headline)
                            Text(goal)
                                .font(.body)
                        }
                        .padding()
                        .glassPanel(tier: .contentCard, cornerRadius: 12)
                    }
                    
                    // Posts
                    CampaignPostsSection(posts: campaignPosts, campaign: campaign)
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle(campaign.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CampaignHeaderSection: View {
    let campaign: Campaign
    let posts: [FocusOSShared.Post]
    
    var progress: Double {
        let publishedCount = posts.filter { $0.postStatus == .published }.count
        let totalCount = posts.count
        guard totalCount > 0 else { return 0.0 }
        return Double(publishedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(Color.kosmicBlue)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    CampaignStatusBadge(status: campaign.status)
                }
                Spacer()
            }
            
            // Stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(posts.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Total Posts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(posts.filter { $0.postStatus == .published }.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.kosmicGreen)
                    Text("Published")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassPanel(tier: .overlay, cornerRadius: 12)
    }
}

struct CampaignPostsSection: View {
    let posts: [FocusOSShared.Post]
    let campaign: Campaign
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Posts")
                .font(.headline)
                .padding(.horizontal)
            
            if posts.isEmpty {
                Text("No posts added to campaign")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(posts) { post in
                    PostPreviewRow(post: post)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct CreateCampaignDrawer: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var projects: [Project]
    
    @State private var title = ""
    @State private var goal = ""
    @State private var selectedProject: Project?
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var tags: [String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Campaign Title", text: $title)
                    TextField("Goal (Optional)", text: $goal, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Project") {
                    Picker("Link to Project", selection: $selectedProject) {
                        Text("None").tag(nil as Project?)
                        ForEach(projects) { project in
                            Text(project.title).tag(project as Project?)
                        }
                    }
                }
                
                Section("Timeline") {
                    DatePicker("Start Date", selection: Binding(
                        get: { startDate ?? Date() },
                        set: { startDate = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("End Date", selection: Binding(
                        get: { endDate ?? Date() },
                        set: { endDate = $0 }
                    ), displayedComponents: .date)
                }
            }
            .padding()
            .navigationTitle("New Campaign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { closeDrawer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createCampaign()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 460)
        .frame(idealWidth: 720, idealHeight: 540)
    }
    
    private func createCampaign() {
        let campaign = Campaign(
            title: title,
            goal: goal.isEmpty ? nil : goal,
            projectId: selectedProject?.id,
            startDate: startDate,
            endDate: endDate
        )
        modelContext.insert(campaign)
        try? modelContext.save()
        closeDrawer()
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

struct CampaignStatusBadge: View {
    let status: CampaignStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(6)
    }
}

#Preview {
    CampaignView()
        .modelContainer(for: [Campaign.self, FocusOSShared.Post.self, FocusOSShared.Project.self])
}
