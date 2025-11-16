//
//  TaskAttachmentDrawer.swift
//  Cloutmate
//
//  AI Assistant V2 - Task Attachment Drawer
//  V2 drawer for selecting an in-progress or todo task to attach to the message
//

import SwiftUI
import SwiftData
import CloutmateShared

struct TaskAttachmentDrawer: View {
    @Binding var isPresented: Bool
    let onSelectTask: (Task) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(sort: \Task.updatedAt, order: .reverse) 
    private var allTasks: [Task]
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    private var availableTasks: [Task] {
        allTasks.filter { task in
            task.status == .inProgress || task.status == .todo
        }
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
                Text("Attach Task")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Select a task to attach to your message")
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
        if availableTasks.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                Text("No Tasks Available")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Create a task to attach it to your messages")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(availableTasks) { task in
                        Button {
                            onSelectTask(task)
                            closeDrawer()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: task.status == .inProgress ? "arrow.triangle.2.circlepath" : "circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                    
                                    HStack(spacing: 8) {
                                        Text(task.status.displayName)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(glassColorSystem.textSecondary())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(glassColorSystem.glassTint(for: .surface).opacity(0.3))
                                            )
                                        
                                        if let dueDate = task.dueDate {
                                            Text(formatDate(dueDate))
                                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                                .foregroundStyle(glassColorSystem.textSecondary())
                                        }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    TaskAttachmentDrawer(
        isPresented: $isPresented,
        onSelectTask: { _ in }
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [Task.self])
}

