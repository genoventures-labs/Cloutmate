# Cloutmate

A macOS-native content planning, publishing, and insights tool for creators using Threads and Facebook Pages.

## Features

### MVP (Implemented)

- **Dashboard**: Centralized overview with today's posts and 7-day performance summary
- **Calendar View**: Monthly/weekly views with color-coded posts by platform
- **List View**: Filterable table with search, sorting, and export capabilities
- **Drafts & Templates**: Rich text editor for capturing ideas and reusable templates
- **Insights**: Real-time engagement metrics, performance charts, and platform comparison
- **Settings**: OAuth authentication for Threads and Facebook, background posting toggle, and appearance customization

### Technical Architecture

- **Platform**: macOS 26.0+ (SwiftUI + AppKit)
- **Data Persistence**: SwiftData with CloudKit sync
- **API Integration**: Meta Graph API (Threads + Facebook Pages)
- **Background Agent**: Login Item Helper with XPC for reliable scheduled posting
- **Security**: Keychain token storage, sandboxed access

### Architecture Highlights

#### Core Services
- `MetaAPIService`: OAuth flow and API client for Meta Graph API
- `ThreadsService` & `FacebookService`: Platform-specific publishing and insights
- `PublishingService`: Orchestrates immediate and scheduled post workflows
- `KeychainService`: Secure token storage
- `XPCService`: Communication between main app and helper
- `LoginItemService`: Background agent registration

#### Data Models (SwiftData)
- `Post`: Content with scheduling, platform selection, and engagement metrics
- `Draft`: Unpublished content with notes and tags
- `Template`: Reusable post structures
- `PlatformAccount`: Connected account information
- `InsightSnapshot`: Cached engagement data

#### Helper App (CloutmateHelper)
- Background scheduler for publishing posts at scheduled times
- Insights polling service for periodic engagement updates
- Notification manager for publish confirmations and errors
- XPC listener for communication with main app

### Setup Instructions

1. **Configure Meta API Credentials**
   - In Xcode, select Cloutmate target → Info tab
   - Add `MetaAppID` and `MetaAppSecret` to Custom macOS Application Target Properties
   - See SETUP_GUIDE.md for detailed instructions

2. **Configure App Groups**
   - Ensure both main app and helper use the same App Group: `group.com.kosmicapps.Cloutmate`
   - Update entitlements for both targets

3. **Add Helper Target to Xcode Project**
   - Follow SETUP_GUIDE.md for step-by-step instructions
   - Target must be configured as background-only app

4. **Build and Run**
   - Build the main app target
   - The helper app will be embedded automatically when properly configured

### Keyboard Shortcuts

- `Cmd+N`: New Post
- `Cmd+1`: Dashboard
- `Cmd+2`: Calendar
- `Cmd+3`: List
- `Cmd+4`: Drafts
- `Cmd+5`: Insights
- `Cmd+,`: Settings

### Roadmap

**Phase 2**
- Post Templates management UI ✅
- Menu Bar Quick Actions
- Spotlight integration for post creation
- Enhanced predictive scheduling

**Phase 3**
- Smart Draft Suggestions based on engagement data
- Rhythm Tracker for posting patterns
- AI-powered insights summaries
- Advanced cross-platform analytics

### License

Copyright © 2025 Kosmic Apps
