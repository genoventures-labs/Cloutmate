//
//  NotificationPreferencesSection.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI

struct NotificationPreferencesSection: View {
    @AppStorage("notifyPostPublished") private var notifyPostPublished = true
    @AppStorage("notifyPostFailed") private var notifyPostFailed = true
    @AppStorage("notifyInsightsUpdated") private var notifyInsightsUpdated = false
    @AppStorage("notificationSound") private var notificationSound = "default"
    @AppStorage("notificationBannerStyle") private var notificationBannerStyle = "banner"
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("quietHoursStart") private var quietHoursStart = Date()
    @AppStorage("quietHoursEnd") private var quietHoursEnd = Date()
    @AppStorage("notifyFacebookPostPublished") private var notifyFacebookPostPublished = true
    @AppStorage("notifyThreadsPostPublished") private var notifyThreadsPostPublished = true
    @AppStorage("notifyFacebookPostFailed") private var notifyFacebookPostFailed = true
    @AppStorage("notifyThreadsPostFailed") private var notifyThreadsPostFailed = true
    
    @State private var showQuietHours = false
    @State private var showPlatformSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // General Notifications
            VStack(alignment: .leading, spacing: 12) {
                Text("General Notifications")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Toggle(isOn: $notifyPostPublished) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.kosmicGreen)
                            .frame(width: 20)
                        Text("Post published")
                    }
                }
                
                Toggle(isOn: $notifyPostFailed) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        Text("Post failed")
                    }
                }
                
                Toggle(isOn: $notifyInsightsUpdated) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.kosmicBlue)
                            .frame(width: 20)
                        Text("Insights updated")
                    }
                }
            }
            
            Divider()
            
            // Notification Style
            VStack(alignment: .leading, spacing: 12) {
                Text("Notification Style")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.kosmicBlue)
                            .frame(width: 20)
                        Text("Sound")
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $notificationSound) {
                        Text("None").tag("none")
                        Text("Default").tag("default")
                        Text("Chime").tag("chime")
                        Text("Fanfare").tag("fanfare")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.kosmicPurple)
                            .frame(width: 20)
                        Text("Banner Style")
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $notificationBannerStyle) {
                        Text("Banner").tag("banner")
                        Text("Alert").tag("alert")
                        Text("None").tag("none")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            }
            
            Divider()
            
            // Quiet Hours
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $quietHoursEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.indigo)
                            .frame(width: 20)
                        Text("Quiet Hours")
                    }
                }
                
                if quietHoursEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Start")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                            DatePicker("", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 150)
                        }
                        
                        HStack {
                            Text("End")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                            DatePicker("", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 150)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: quietHoursEnabled)
            
            Divider()
            
            // Platform-Specific Notifications
            DisclosureGroup(
                isExpanded: $showPlatformSettings,
                content: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customize notifications for each platform")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Threads")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Toggle(isOn: $notifyThreadsPostPublished) {
                                    Text("Post published")
                                        .font(.caption)
                                }
                                
                                Toggle(isOn: $notifyThreadsPostFailed) {
                                    Text("Post failed")
                                        .font(.caption)
                                }
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Facebook")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Toggle(isOn: $notifyFacebookPostPublished) {
                                    Text("Post published")
                                        .font(.caption)
                                }
                                
                                Toggle(isOn: $notifyFacebookPostFailed) {
                                    Text("Post failed")
                                        .font(.caption)
                                }
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    HStack(spacing: 8) {
                        Image(systemName: "app.badge.fill")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text("Platform-Specific Settings")
                    }
                }
            )
        }
    }
}

#Preview {
    NotificationPreferencesSection()
        .padding()
}

