//
//  ProjectAttachmentDrawer.swift
//  FocusOS
//
//  AI Assistant V2 - Project Attachment Drawer
//  V2 drawer for selecting an active project to attach to the message
//

import SwiftUI
import SwiftData
import FocusOSShared

struct ProjectAttachmentDrawer: View {
    @Binding var isPresented: Bool
    let onSelectProject: (Project) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }, sort: \Project.updatedAt, order: .reverse) 
    private var activeProjects: [Project]
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Backdrop
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer slides up from bottom
                        VStack(spacing: 0) {
                            V2DrawerScaffold(
                                accentGradient: accentGradient,
                                showsSidebar: false,
                                header: { headerContent },
                                content: { drawerContent },
                                sidebar: { EmptyView() }
                            )
                        }
                        .frame(maxHeight: geometry.size.height * 0.6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Attach Project")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Select an active project to attach to your message")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface
            ) {
                closeDrawer()
            }
            .accessibilityLabel("Close")
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        if activeProjects.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Text("No Active Projects")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Create a project to attach it to your messages")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(activeProjects) { project in
                        Button {
                            onSelectProject(project)
                            closeDrawer()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.title)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    
                                    if let goal = project.goal, !goal.isEmpty {
                                        Text(goal)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(glassColorSystem.textSecondary())
                                            .lineLimit(2)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(glassColorSystem.glassTint(for: .surface).opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    ProjectAttachmentDrawer(
        isPresented: $isPresented,
        onSelectProject: { _ in }
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Project.self])
}

