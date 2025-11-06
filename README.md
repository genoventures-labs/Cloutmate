# Cloutmate

**A cognitive workspace orchestration system for focus, publishing, and creative execution.**

Cloutmate is a macOS-native application that transforms content creation from a time-consuming chore into an organized, strategic, and efficient process. Built on the PARA method (Projects, Areas, Resources, Archives) and powered by Aurora—an advanced AI assistant with 9 development phases of cognitive capabilities.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Core Philosophy](#core-philosophy)
- [Features](#features)
- [Aurora AI Assistant](#aurora-ai-assistant)
- [Architecture](#architecture)
- [Installation & Setup](#installation--setup)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Integration Capabilities](#integration-capabilities)
- [Development](#development)
- [Roadmap](#roadmap)
- [License](#license)

---

## Overview

Cloutmate is evolving from a social media scheduling tool into a comprehensive cognitive workspace orchestration system. It combines:

- **PARA Method Organization**: Projects, Areas, Resources, and Archives for structured knowledge management
- **AI-Powered Cognition**: Aurora, an advanced AI assistant with emotional memory, predictive capabilities, and adaptive intelligence
- **Artifact-Based Output**: Narrative artifacts (briefs, summaries, reflections, reports) instead of traditional social media posts
- **Local-First Processing**: Powered by Ollama (local LLM) for privacy and reliability
- **Focus & Productivity Tools**: Deep work sessions, focus rituals, cognitive forecasting, and momentum tracking

---

## Core Philosophy

### From Social Media to Cognitive Workspace

Cloutmate is transitioning from a social media scheduling tool to a cognitive workspace that helps you:

1. **Capture** ideas instantly (Inbox, Quick Capture, Voice Memos)
2. **Organize** using PARA method (Projects, Areas, Resources, Archives)
3. **Express** through artifacts (Briefs, Summaries, Reflections, Reports, Release Notes, Lessons Learned)
4. **Reflect** with insights, analytics, and cognitive patterns

### The PARA Method

Cloutmate implements Tiago Forte's PARA method:

- **Projects**: Specific outcomes with deadlines (e.g., "Launch Q4 Campaign")
- **Areas**: Standards to maintain (e.g., "Health", "Social Publishing")
- **Resources**: Reference materials (Notes, Articles, Videos, Links)
- **Archives**: Inactive projects, areas, and resources

---

## Features

### 🎯 Core Workspace

#### Capture Layer
- **Inbox**: Quick capture of ideas, tasks, and notes
- **Quick Capture Window**: Universal capture (text, links, images)
- **Voice Memos**: Voice-to-text transcription
- **Journal**: Daily reflections and thoughts

#### Organize Layer (PARA)
- **Projects**: Manage active projects with goals, due dates, and linked tasks/notes
- **Areas**: Maintain standards and ongoing responsibilities
- **Resources**: Store reference materials (notes, articles, videos, books, podcasts)
- **Archives**: Archive completed or inactive items

#### Express Layer
- **Artifacts**: Create narrative outputs (Briefs, Summaries, Reflections, Reports, Release Notes, Lessons Learned)
- **Artifact Composer**: Capture/Craft modes for creating artifacts
- **Drafts**: Rich text editor for content creation
- **Templates**: Reusable structures for projects, tasks, notes, and artifacts
- **Calendar**: Unified calendar view for tasks, artifacts, and reminders

#### Tools Layer
- **Tasks**: Task management with priorities, due dates, and project linking
- **Notes**: Markdown-based notes with backlinks and highlights
- **Focus Mode**: Deep work sessions with objectives, timers, and progress tracking
- **Focus Gravity**: Visual priority system showing cognitive engagement
- **Insights**: Personal intelligence dashboard with analytics

### 🤖 Aurora AI Assistant

Aurora is Cloutmate's AI assistant—a cognitive operating system that lives inside the app. See [Aurora AI Assistant](#aurora-ai-assistant) section for complete details.

**Key Capabilities:**
- Natural language workspace operations (create tasks, projects, notes, reminders)
- Document and image analysis with context-aware responses
- Cross-conversation memory and pattern recognition
- Predictive cognition and focus forecasting
- Emotional state detection and UI adaptation (ARTE)
- Focus rituals and smart nudges
- Confidence scoring and cognitive health monitoring

### 📊 Insights Dashboard

Personal Intelligence Dashboard with 6 analytics tabs:

1. **Overview**: Cognitive state, emotional pulse, learning score, active themes
2. **Memory Graph**: Interactive visualization of concept relationships
3. **Focus Analytics**: Productivity patterns, completion rates, time-of-day performance
4. **Emotional Heatmap**: Emotional journey with valence trends
5. **Learning Loop**: AI growth metrics and feedback events
6. **Connections**: Recurring themes and concept salience

### 🎨 Design System

- **Glassmorphic UI**: Modern glassmorphic design with material tiers
- **ARTE (Aurora Reactive Theme Engine)**: Dynamic UI adaptation based on emotional-cognitive states
- **Accessibility**: Full accessibility support with reduced motion options
- **Dark Mode**: Native macOS dark mode support

### 🔔 Notifications & Reminders

- **In-App Notifications**: Focus session alerts and reminders
- **Reminders**: Natural language date/time parsing with calendar integration
- **Smart Nudges**: Contextual micro-coaches that adapt based on ARTE state

### 📅 Calendar Integration

- **Unified Calendar**: Monthly/weekly views with tasks, artifacts, and reminders
- **Calendar Sync**: Bi-directional sync with macOS Calendar
- **Adaptive Scheduling**: Reflows skipped focus blocks into high-energy windows

### 🔗 Integrations

- **Notion**: Import and sync databases (projects, tasks, notes, areas) with intelligent property mapping
- **Meta Graph API**: OAuth authentication for Threads and Facebook Pages (legacy, being phased out)
- **CloudKit**: Data sync across devices

---

## Aurora AI Assistant

Aurora is the AI assistant that orchestrates Cloutmate's cognitive operating system. She is **not** Cloutmate itself—she is the intelligent guide who helps you run everything.

### Who Is Aurora?

Aurora remembers not just **what** you worked on, but **how** it felt. She's proactive, emotionally aware, self-aware, anticipatory, and continuously learning. She executes actions directly (no confirmation prompts) and adapts her tone to match your communication style.

### Core Capabilities

#### Workspace Operations
- Create/read/update/delete Tasks, Notes, Projects, Artifacts, Inbox Items, Drafts, Reminders
- Schedule artifacts with automatic publishing (legacy)
- Convert inbox items to tasks/notes/drafts
- Create reminders with in-app notifications
- **@ Mention Linking**: Reference workspace objects directly using `@` syntax (e.g., `@projectname`, `@taskname`)

#### Intelligence Systems

**Phase 1: Recall & Emotional Continuity**
- Pulls most relevant items from workspace with emotional memory
- Remembers not just what you worked on, but how it felt

**Phase 2: Action Router & Feedback Loop**
- Converts natural language to workspace actions
- Tracks all actions and generates weekly "Learning Loop" summaries

**Phase 3: Contextual Priority System (CPS)**
- Dynamically ranks all workspace objects by relevance
- Weights: recency (30%), frequency (25%), connections (25%), AI mentions (15%), manual boost (5%)

**Phase 4: Focus Mode**
- Deep work sessions with objectives, timers, and progress tracking
- Completed sessions boost CPS scores

**Phase 5: Narrative Engine**
- Tracks abstract concepts and themes across workspace activity
- Concepts >30% relevance are "alive"
- Generates weekly narrative summaries

**Phase 5+: Cross-Conversation Memory**
- Recalls and references past conversations naturally
- Auto-generates summaries for conversations with 5+ messages

**Phase 5++: Intent Cluster Prediction**
- Analyzes conversation patterns to predict focus areas
- Identifies clusters: Empathy/Support, Orchestration/Planning, Creative/Brainstorming, Execution/Action, Reflection/Learning

**Phase 6: Memory Graph**
- Semantic clustering of memories with DBSCAN for emergent theme discovery
- Interactive visualization in Insights → Memory Graph tab

**Phase 6.1: Intelligence Dashboard & Smart Automation**
- Personal analytics showing cognitive patterns, emotional trends, focus effectiveness
- Pattern detection for recurring tasks and workflow suggestions

**Phase 7: ARTE (Aurora Reactive Theme Engine)**
- Adapts UI and tone based on emotional state detection
- Five core states: Focused, Reflective, Calm, Energized, Fatigued

**Phase 8: Focus Rituals & Smart Nudges**
- Morning/evening ritual prompts with contextual nudges
- Respects quiet hours, fatigue suppression, and global throttling

**Phase 9: Predictive Reflection Engine**
- Anticipates focus drift, fatigue risk, and energy trends before they occur
- Generates cognitive forecasts every 1-4 hours
- Detects real-time drift during focus sessions

**Phase 9 Extensions: Temporal Intelligence**
- Adaptive scheduling, calendar sync, context switching guard, momentum tracking

#### Document & Media Analysis
- **Document Analysis**: Analyze PDFs, Markdown, text files, and RTF documents
- **Image Analysis**: Analyze images (PNG, JPEG, WEBP, HEIC, HEIF) with vision capabilities
- Extracts text, provides summaries with action items
- Indexes analyses in recall system for future reference

#### Cognitive Load Management
- **Confidence Scoring**: Self-aware confidence metrics (low/medium/high)
- **Conversation Compression**: Automatically summarizes long conversations (>40 messages)
- **Cognitive Health**: Self-introspection metrics for memory density, stale entries, context pressure
- **Style Adaptation**: Dynamic tone matching based on typing patterns

### How to Use Aurora

#### Quick Access
- **Aurora Spotlight**: Press `Cmd+Shift+A` for quick access overlay
- **AI Assistant Tab**: Main workspace for detailed conversations
- **@ Mentions**: Type `@` in any message to reference workspace objects

#### Natural Language Commands

**Workspace Operations:**
- "Create a task called [name]"
- "Add a task to @projectname"
- "Mark @taskname as done"
- "Remind me to [action] tomorrow at 3pm"
- "Schedule an artifact for [date]"

**Focus & Priority:**
- "What should I work on?"
- "Start a focus session for [objective]"
- "Show my top priorities"

**Insights & Analytics:**
- "How's my productivity this week?"
- "What patterns do you see?"
- "Show my emotional trends"
- "What are you learning from me?"

**Document Analysis:**
- "Analyze this document"
- "What's in this image?"
- "Can you read this PDF?"

### Powered by Ollama

Aurora runs entirely on your computer using **Ollama** (local LLM) for privacy and reliability.

**Requirements:**
- Ollama must be running locally
- `llama3.1` model installed (`ollama pull llama3.1`)

**Adaptive Model Selection:**
- Aurora automatically switches between Ollama models based on task complexity
- Coding tasks → code-specific models (codellama)
- Complex analysis → larger models
- Vision tasks → vision-capable models (llama3.2-vision)

**Airplane Mode:**
- Enable in Settings → AI Assistant to disable all network access
- Complete offline operation with full cognition capabilities
- All features work identically whether online or offline

**For complete Aurora documentation, see:**
- `AURORA_README.md` - Complete technical documentation
- `AURORA_INTRO.md` - Conversational introduction
- `AURORA_KNOWLEDGE_BASE_UPDATED.md` - Complete knowledge synthesis

---

## Architecture

### Platform & Technology

- **Platform**: macOS 14.0+ (SwiftUI + AppKit)
- **Data Persistence**: SwiftData with CloudKit sync
- **AI Engine**: Ollama (local LLM) for privacy and reliability
- **Architecture**: Multi-target app (Main App, Helper, Widget, Menu Bar)

### Project Structure

```
Cloutmate/
├── Cloutmate/                    # Main application
│   ├── Models/                   # SwiftData models
│   ├── Services/                 # Core services
│   ├── ViewModels/               # View models
│   ├── Views/                    # SwiftUI views
│   └── Utilities/                # Utilities and helpers
├── CloutmateShared/              # Shared framework
│   ├── Models/                   # Shared models
│   ├── Services/                 # Shared services
│   └── UI/                       # Shared UI components
├── CloutmateHelper/              # Background helper app
├── CloutmateWidget/              # WidgetKit extension
└── CloutmateMenuBar/             # Menu bar application
```

### Core Services

#### Main App Services
- `OllamaBridgeService`: AI assistant communication with Ollama
- `AIRecallService`: Recall layer with emotional memory
- `AIActionRouter`: Natural language to workspace actions
- `NarrativeEngine`: Concept tracking and theme discovery
- `MemoryGraphService`: Semantic clustering and theme extraction
- `AnalyticsEngine`: Comprehensive metrics aggregation
- `ReactiveThemeManager`: ARTE emotional state detection
- `FocusRitualManager`: Morning/evening ritual scheduling
- `SmartNudgeService`: Contextual micro-coaches
- `CognitionPredictor`: Predictive reflection engine
- `CalendarSyncService`: macOS Calendar integration
- `NotionService`: Notion OAuth and API integration
- `NotionSyncService`: Notion data import and conversion

#### Shared Services
- `SharedDataManager`: SwiftData container with app group
- `XPCService`: Communication between app and helper
- `KeychainService`: Secure token storage
- `Logger`: Logging utilities

### Data Models (SwiftData)

#### Core Models
- `Project`: Projects with goals, status, due dates, linked tasks/notes
- `Task`: Tasks with priorities, due dates, project linking
- `Note`: Markdown-based notes with backlinks and highlights
- `Area`: Areas with cadence settings and linked projects
- `InboxItem`: Quick capture items
- `Journal`: Journal entries with emotional valence
- `Artifact`: Narrative outputs (briefs, summaries, reflections, etc.)
- `Draft`: Draft content with rich text editor
- `Reminder`: Reminders with date/time and calendar integration

#### AI Models
- `AIMessage`: AI conversation messages
- `RecallIndexEntry`: Recall layer entries with emotional snapshots
- `PriorityScore`: CPS priority scores
- `FocusSession`: Focus mode sessions
- `ConceptNode`: Narrative engine concepts
- `MemoryNode`: Memory graph nodes
- `ThemeNode`: Emergent themes from clustering
- `FocusForecast`: Predictive cognition forecasts
- `FocusRitual`: Focus ritual state
- `SmartNudge`: Smart nudge records

### Background Architecture

#### Helper App (CloutmateHelper)
- Background scheduler for publishing artifacts at scheduled times (legacy)
- Insights polling service for periodic engagement updates (legacy)
- Notification manager for publish confirmations and errors
- XPC listener for communication with main app

#### XPC Communication
- Secure inter-process communication between main app and helper
- Protocol defined in `XPCProtocol.swift`
- Services communicate via `XPCService`

---

## Installation & Setup

### Prerequisites

1. **macOS 14.0+** (Sonoma or later)
2. **Xcode 15.0+** (for development)
3. **Ollama** (for AI Assistant)
   - Install from [ollama.ai](https://ollama.ai)
   - Run `ollama pull llama3.1` to install the required model

### Configuration

#### 1. Meta API Credentials (Legacy - Being Phased Out)

If using legacy social media features:

1. In Xcode, select Cloutmate target → Info tab
2. Add `MetaAppID` and `MetaAppSecret` to Custom macOS Application Target Properties
3. See `SETUP_GUIDE.md` for detailed instructions

#### 2. App Groups

Ensure all targets use the same App Group:
- App Group: `group.com.kosmicapps.Cloutmate`
- Update entitlements for main app, helper, widget, and menu bar

#### 3. Notion Integration (Optional)

1. Go to Settings → Integrations → Notion
2. Click "Connect Notion Account"
3. Authorize Cloutmate in Notion
4. Select databases to import
5. Configure property mappings

### Build and Run

1. Open `Cloutmate.xcodeproj` in Xcode
2. Select the Cloutmate scheme
3. Build and run (`Cmd+R`)

**Note**: The helper app will be embedded automatically when properly configured.

### First Launch

1. **Start Ollama**: Ensure Ollama is running locally
2. **Configure Aurora**: Go to Settings → AI Assistant
   - Select preferred Ollama model
   - Enable/disable features as needed
   - Enable Airplane Mode for offline operation
3. **Set Up PARA Structure**: 
   - Create your first Area (e.g., "Social Publishing")
   - Create a Project to get started
   - Add Tasks and Notes as needed

---

## Keyboard Shortcuts

### Navigation
- `Cmd+1`: Home
- `Cmd+2`: Inbox
- `Cmd+3`: Projects
- `Cmd+4`: Tasks
- `Cmd+5`: Areas
- `Cmd+6`: Resources (Notes)
- `Cmd+7`: Archives
- `Cmd+8`: Calendar
- `Cmd+9`: AI Assistant
- `Cmd+0`: Insights

### Actions
- `Cmd+N`: New Post/Artifact
- `Cmd+Shift+A`: Aurora Spotlight (quick AI access)
- `Cmd+K`: Global Search (conversations, drafts, artifacts)
- `Cmd+,`: Settings
- `Cmd+Shift+N`: New Note
- `Cmd+Shift+T`: New Task
- `Cmd+Shift+P`: New Project

### Focus Mode
- `Cmd+Shift+F`: Start Focus Session
- `Esc`: Exit Focus Mode

---

## Integration Capabilities

### Notion Integration

Import and sync your Notion databases with intelligent property mapping:

**Supported Objects:**
- Projects
- Tasks
- Notes
- Areas

**Features:**
- OAuth 2.0 authentication
- Automatic property mapping
- Relationship preservation
- Scheduled sync (hourly/daily)
- Manual sync on demand

**Setup:**
1. Go to Settings → Integrations → Notion
2. Click "Connect Notion Account"
3. Authorize Cloutmate
4. Select databases to import
5. Configure property mappings
6. Enable sync schedule

### Meta Graph API (Legacy - Being Phased Out)

**Note**: Social media publishing features are being phased out in favor of artifact-based output. See `social-media-removal-and-artifact-migration.plan.md` for migration details.

**Current Support:**
- Threads OAuth authentication
- Facebook Pages OAuth authentication
- Scheduled posting (via background helper)
- Insights polling (engagement metrics)

### CloudKit Sync

- Automatic data sync across devices
- SwiftData with CloudKit integration
- Conflict resolution
- Offline support

---

## Development

### Project Structure

See [Architecture](#architecture) section for detailed structure.

### Key Files

#### Models
- `CloutmateShared/Models/`: Shared data models
- `Cloutmate/Models/`: App-specific models

#### Services
- `Cloutmate/Services/`: Core application services
- `CloutmateShared/Services/`: Shared services

#### Views
- `Cloutmate/Views/`: SwiftUI views organized by feature
- `CloutmateShared/UI/`: Shared UI components

### Building

```bash
# Build main app
xcodebuild -scheme Cloutmate -configuration Debug

# Build all targets
xcodebuild -workspace Cloutmate.xcworkspace -scheme Cloutmate -configuration Debug
```

### Testing

```bash
# Run tests
xcodebuild test -scheme Cloutmate -destination 'platform=macOS'
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI for UI components
- Prefer value types (structs) over reference types (classes) where possible
- Use `@MainActor` for UI-related code
- Document public APIs with doc comments

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

---

## Roadmap

### Current Status

**Phase 9 Complete**: Predictive Reflection Engine with Temporal Intelligence

**In Progress:**
- Social Media Removal & Artifact Migration (see `social-media-removal-and-artifact-migration.plan.md`)
- Projects V2 Redesign (see `.cursor/plans/projects-v2-redesign-7e538134.plan.md`)

### Planned Features

**Phase 2:**
- ✅ Post Templates management UI
- Menu Bar Quick Actions
- Spotlight integration for artifact creation
- Enhanced predictive scheduling

**Phase 3:**
- Smart Draft Suggestions based on engagement data
- Rhythm Tracker for posting patterns
- AI-powered insights summaries
- Advanced cross-platform analytics

**Future Enhancements:**
- Weekly Reflection PDF Export (UI ready, generation coming soon)
- Compare Weeks feature (placeholder ready)
- Advanced graph visualization (3D, VR/AR)
- Multi-user collaboration and shared insights
- Extended narrative summaries (monthly/quarterly)

---

## License

Copyright © 2025 Kosmic Apps

All rights reserved.

---

## Documentation

### Aurora Documentation
- `AURORA_README.md` - Complete technical documentation
- `AURORA_INTRO.md` - Conversational introduction
- `AURORA_KNOWLEDGE_BASE_UPDATED.md` - Complete knowledge synthesis

### Setup Guides
- `SETUP_GUIDE.md` - Initial setup instructions
- `NOTION_INTEGRATION_IMPLEMENTATION.md` - Notion integration details
- `WIDGET_INTEGRATION_GUIDE.md` - Widget and menu bar setup

### Phase Documentation
- `PHASE3_CPS_COMPLETE.md` - Contextual Priority System
- `PHASE4_FOCUS_MODE_COMPLETE.md` - Focus Mode implementation
- `PHASE5_NARRATIVE_ENGINE_COMPLETE.md` - Narrative Engine
- `PHASE6_MEMORY_GRAPH_COMPLETE.md` - Memory Graph
- `PHASE7_ARTE_COMPLETE.md` - ARTE implementation
- `PHASE8_RITUALS_COMPLETE.md` - Focus Rituals & Smart Nudges
- `PHASE9_COGNITION_COMPLETE.md` - Predictive Reflection Engine

---

## Support

For questions, issues, or feature requests, please open an issue on the repository.

---

**Built with ❤️ by Kosmic Apps**
