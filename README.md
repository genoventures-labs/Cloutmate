# Cloutmate

**A cognitive workspace orchestration system for focus and creative execution.**

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

Cloutmate is a comprehensive cognitive workspace orchestration system that combines:

- **PARA Method Organization**: Projects, Areas, Resources, and Archives for structured knowledge management
- **AI-Powered Cognition**: Aurora, an advanced AI assistant with emotional memory, predictive capabilities, and adaptive intelligence
- **Artifact-Based Output**: Narrative artifacts (briefs, summaries, reflections, reports) for creative expression
- **Local-First Processing**: Powered by Ollama (local LLM) for privacy and reliability
- **Focus & Productivity Tools**: Deep work sessions, focus rituals, cognitive forecasting, and momentum tracking

---

## Core Philosophy

### Cognitive Workspace Philosophy

Cloutmate is a cognitive workspace that helps you:

1. **Capture** ideas instantly (Inbox, Quick Capture, Voice Memos)
2. **Organize** using PARA method (Projects, Areas, Resources, Archives)
3. **Express** through artifacts (Briefs, Summaries, Reflections, Reports, Release Notes, Lessons Learned)
4. **Reflect** with insights, analytics, and cognitive patterns

### The PARA Method

Cloutmate implements Tiago Forte's PARA method:

- **Projects**: Specific outcomes with deadlines (e.g., "Launch Q4 Campaign")
- **Areas**: Standards to maintain (e.g., "Health", "Content Creation")
- **Resources**: Reference materials (Notes, Articles, Videos, Links)
- **Archives**: Inactive projects, areas, and resources

---

## Features

### 🎯 Core Workspace

#### Capture Layer
- **Inbox**: Quick capture of ideas, tasks, and notes
- **Quick Capture Window**: Universal capture (text, links, images)
- **Voice Memos**: Voice-to-text transcription with waveform visualization
- **Journal**: Daily reflections and thoughts with:
  - Entry types: Personal Reflection, Content Idea, Project Tracker
  - Mood tracking: Excited, Grateful, Reflective, Motivated, Contemplative, Creative, Frustrated, Calm
  - AI-powered prompts and content generation
  - Timeline view and mood radar charts
  - ARTE reflection cards

#### Organize Layer (PARA)
- **Projects**: Manage active projects with goals, due dates, and linked tasks/notes
- **Areas**: Maintain standards and ongoing responsibilities with cadence settings
- **Resources**: Store reference materials (Notes with resource types: articles, videos, books, podcasts, links, ideas, references)
- **Archives**: Archive completed or inactive items with reflection capabilities

#### Express Layer
- **Artifacts**: Create narrative outputs with 6 output formats:
  - **Brief**: Quick, concise summary
  - **Summary**: Comprehensive overview
  - **Reflection**: Personal reflection and insights
  - **Report**: Detailed status report
  - **Release Note**: Release announcement format
  - **Lesson Learned**: Key learnings and takeaways
- **Artifact Composer**: Capture/Craft modes for creating artifacts
  - **Capture Mode**: Quick thought capture (idea state)
  - **Craft Mode**: Refine into finished artifact (draft/final state)
  - AI-powered content generation tools
  - Media attachment support (images, files)
  - Tag management and organization
- **Contextual Create Sheet**: Smart creation drawer that adapts to current tab
  - Context-aware action options based on current view
  - Smart defaults showing most-used actions
  - Recently created indicators
  - ARTE emotional tinting integration
  - Accessible via "+" button or Cmd+N (context-aware)
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
- **CloudKit**: Data sync across devices

---

## Aurora AI Assistant

Aurora is the AI assistant that orchestrates Cloutmate's cognitive operating system. She is **not** Cloutmate itself—she is the intelligent guide who helps you run everything.

### Who Is Aurora?

Aurora remembers not just **what** you worked on, but **how** it felt. She's proactive, emotionally aware, self-aware, anticipatory, and continuously learning. She executes actions directly (no confirmation prompts) and adapts her tone to match your communication style.

### Core Capabilities

#### Workspace Operations
- Create/read/update/delete Tasks, Notes, Projects, Artifacts, Inbox Items, Drafts, Reminders
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
- "Create an artifact for [project]"

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
- `qwen3:1.7b` model recommended (`ollama pull qwen3:1.7b`)
- `granite3.2:2b` model recommended as fallback (`ollama pull granite3.2:2b`)

**Adaptive Model Selection:**
- Aurora automatically switches between Ollama models based on task complexity
- Coding tasks → code-specific models (codellama)
- Complex analysis → larger models
- Vision tasks → vision-capable models (llama3.2-vision)
- Document analysis → optimized models for text processing

**Model Routing Engine:**
- **Default Model**: `qwen3:1.7b` (Qwen3) - Fast, efficient, supports thinking mode
- **Fallback Model**: `granite3.2:2b` (Granite3) - Reliable fallback for when Qwen3 unavailable
- **Model Stickiness**: Keeps using the same model for 3 consecutive turns to maintain conversation continuity
- **Casual Detection**: Automatically detects casual queries and uses faster response mode
- **Thinking Mode**: Enabled automatically for complex, analytical queries (>80 chars, non-casual)
  - Thinking mode allows models to show their reasoning process
  - Only enabled for models that support it (Qwen3 supports thinking, Granite3 does not)
  - Disabled for short, casual queries for faster responses

**Hybrid Bridge (Optional):**
- Can route to cloud models (via Ollama Cloud API) for faster responses
- Automatic fallback to local Ollama if cloud unavailable
- Network-aware routing with latency thresholds
- Configure in Settings → AI Assistant

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
- **AI Engine**: Ollama (local LLM) with Hybrid Bridge support for cloud models (optional)
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
- `OllamaBridgeService`: AI assistant communication with Ollama (local LLM)
- `HybridBridgeService`: Hybrid routing between Ollama and cloud models with intelligent fallback
- `ModelRoutingEngine`: Automatic model selection based on task complexity and requirements
- `CoreResponseService`: Abstraction layer for AI response generation
- `AIRecallService`: Recall layer with emotional memory
- `AIActionRouter`: Natural language to workspace actions
- `NarrativeEngine`: Concept tracking and theme discovery
- `MemoryGraphService`: Semantic clustering and theme extraction
- `AnalyticsEngine`: Comprehensive metrics aggregation
- `ReactiveThemeManager`: ARTE emotional state detection
- `FocusRitualManager`: Morning/evening ritual scheduling
- `SmartNudgeService`: Contextual micro-coaches
- `CognitionPredictor`: Predictive reflection engine
- `DriftMonitor`: Real-time focus drift detection during sessions
- `AdaptiveScheduler`: Reflows skipped focus blocks into high-energy windows
- `CalendarSyncService`: macOS Calendar integration
- `ContextSwitchGuard`: Intercepts abrupt tab switches with graduated prompts
- `MomentumTracker`: Computes flow velocity, streaks, and recovery time
- `AIFlowCompanion`: Flow state companion with structured nudges and insights
- `FlowCompanionEngine`: Central controller for floating reflection bubble
- `NotionService`: Notion OAuth and API integration
- `NotionSyncService`: Notion data import and conversion
- `CreateActionUsageTracker`: Tracks creation patterns for smart defaults
- `ArtifactAnalyticsService`: Analytics for artifact usage and patterns
- `ArtifactExportService`: Export artifacts to various formats
- `ArtifactMentionService`: Handle artifact mentions in workspace
- `ArtifactPredictiveBridge`: Bridge artifacts with predictive systems
- `DocumentAttachmentService`: Handles PDF, Markdown, text, and RTF file analysis
- `ImageAttachmentService`: Handles image analysis (PNG, JPEG, WEBP, HEIC, HEIF)
- `ConversationArchive`: Cross-conversation memory management
- `ConversationCompressionService`: Intelligent summarization of long conversations
- `ConfidenceScorer`: Self-aware confidence metrics
- `CognitiveHealthService`: Self-introspection metrics
- `StyleAdapter`: Dynamic tone matching based on user patterns
- `MentionService`: @ Mention linking system with autocomplete
- `JournalAIService`: AI-powered journal assistance
- `ReminderService`: Reminder creation and notification management

#### Shared Services
- `SharedDataManager`: SwiftData container with app group
- `XPCService`: Communication between app and helper
- `KeychainService`: Secure token storage
- `Logger`: Logging utilities

### Data Models (SwiftData)

#### Core Models (Shared)
- `Project`: Projects with goals, status, due dates, linked tasks/notes
- `Task`: Tasks with priorities, due dates, project linking
- `Note`: Markdown-based notes with backlinks, highlights, and resource types
- `Area`: Areas with cadence settings and linked projects
- `InboxItem`: Quick capture items
- `Reminder`: Reminders with date/time and calendar integration
- `Artifact`: Narrative outputs (briefs, summaries, reflections, reports, release notes, lessons learned)
- `ArtifactMention`: Tracks artifact mentions in workspace
- `Template`: Reusable templates for projects, tasks, notes, and artifacts

#### Core Models (App-Local)
- `Draft`: Draft content with rich text editor (separate from Artifact)
- `Journal`: Journal entries with emotional valence, moods, and entry types
- `Campaign`: Campaign management (legacy)
- `DashboardCard`: Customizable dashboard cards
- `UserPreferences`: User preferences and settings
- `InsightSnapshot`: Cached insights for performance
- `NotionSyncConfig`: Notion integration configuration
- `PARATemplate`: PARA method templates

#### AI Models
- `AIMessage`: AI conversation messages with emotional tracking
- `AIConversation`: Conversation containers with metadata
- `ConversationDigest`: AI-generated conversation summaries
- `RecallIndexEntry`: Recall layer entries with emotional snapshots
- `PriorityScore`: CPS priority scores
- `FocusSession`: Focus mode sessions with objectives and timers
- `ConceptNode`: Narrative engine concepts
- `StoryToken`: Weekly narrative summaries
- `MemoryNode`: Memory graph nodes with vector embeddings
- `MemoryEdge`: Relationships between memories
- `ThemeNode`: Emergent themes from DBSCAN clustering
- `FocusForecast`: Predictive cognition forecasts
- `DriftEvent`: Focus drift detection events
- `FocusRitual`: Focus ritual state
- `RitualCompletion`: Ritual completion tracking
- `SmartNudge`: Smart nudge records
- `WeeklyReview`: Weekly review reflections
- `ARTEConfiguration`: ARTE emotional state configuration
- `StateTransitionHistory`: ARTE state transition tracking
- `WorkflowPattern`: Detected workflow patterns
- `AutomationRule`: Automation rules for workflows
- `WorkflowTemplate`: Workflow templates
- `EnergyWindow`: Energy window tracking
- `MomentumMetrics`: Flow velocity and streak tracking
- `FlowCompanionState`: Flow companion state tracking
- `ReflectionNote`: Reflection notes from flow companion
- `StoryArc`: Story arc tracking
- `StoryChapter`: Story chapter tracking
- `StoryScene`: Story scene tracking
- `MoodEntry`: Mood entry tracking
- `MemorySummary`: Memory summaries
- `AuroraSelfDiagnostic`: Aurora self-diagnostic data

### Background Architecture

#### Helper App (CloutmateHelper)
- Background services for notifications and system integration
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
   - Run `ollama pull qwen3:1.7b` to install the recommended model
   - Run `ollama pull granite3.2:2b` for fallback model

### System Requirements

**Minimum Requirements:**
- macOS 14.0+ (Sonoma)
- 8GB RAM (16GB recommended for optimal performance)
- 2GB free disk space for app and data
- Ollama with 4GB+ RAM available for models

**Recommended Requirements:**
- macOS 15.0+ (Sequoia)
- 16GB+ RAM for smooth operation with large workspaces
- 5GB+ free disk space
- Ollama with 8GB+ RAM for larger models and faster responses
- SSD storage for better database performance

**Ollama Requirements:**
- Ollama must be running locally (`ollama serve`)
- Default model `qwen3:1.7b` requires ~2GB RAM
- Fallback model `granite3.2:2b` requires ~1.5GB RAM
- For best performance, ensure Ollama has dedicated RAM allocation

### Configuration

#### 1. App Groups

Ensure all targets use the same App Group:
- App Group: `group.com.kosmicapps.Cloutmate`
- Update entitlements for main app, helper, widget, and menu bar

#### 2. Notion Integration (Optional)

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

1. **Start Ollama**: Ensure Ollama is running locally (`ollama serve`)
2. **Configure Aurora**: Go to Settings → AI Assistant
   - Select preferred Ollama model
   - Enable/disable features as needed
   - Enable Airplane Mode for offline operation
3. **Set Up PARA Structure**: 
   - Create your first Area (e.g., "Content Creation")
   - Create a Project to get started
   - Add Tasks and Notes as needed

### Quick Start Guide

**Your First 5 Minutes:**

1. **Capture Something** (30 seconds)
   - Press `Cmd+N` to open Quick Capture
   - Type a quick idea or task
   - Press Enter to save

2. **Talk to Aurora** (2 minutes)
   - Press `Cmd+Shift+A` for Aurora Spotlight
   - Say "Create a project called [Your Project Name]"
   - Ask "What should I work on?" to see priorities

3. **Organize** (1 minute)
   - Open Projects tab (`Cmd+3`)
   - Link tasks to your project
   - Create an Area for ongoing responsibilities

4. **Start a Focus Session** (1 minute)
   - Press `Cmd+Shift+F`
   - Set an objective
   - Begin deep work

5. **Check Insights** (30 seconds)
   - Open Insights tab (`Cmd+0`)
   - See your cognitive patterns
   - Explore the Memory Graph

**Essential First Steps:**
- Create your first Area (e.g., "Work", "Personal", "Learning")
- Create a Project with a clear goal
- Add 3-5 Tasks to get started
- Have your first conversation with Aurora
- Start a Focus Session to experience deep work mode

---

## Common Workflows & Use Cases

### Daily Workflow

**Morning Routine:**
1. Open Cloutmate and check Inbox (`Cmd+2`)
2. Process inbox items: convert to tasks, notes, or artifacts
3. Ask Aurora: "What should I focus on today?"
4. Review Focus Gravity for top priorities
5. Start morning ritual (if enabled)

**Throughout the Day:**
- Quick capture ideas with `Cmd+N`
- Use Aurora Spotlight (`Cmd+Shift+A`) for quick questions
- Start Focus Sessions for deep work (`Cmd+Shift+F`)
- Create artifacts as you complete work
- Link related items using @ mentions

**Evening Routine:**
1. Complete evening ritual (if enabled)
2. Review completed tasks and artifacts
3. Ask Aurora: "What did I accomplish today?"
4. Archive completed items
5. Plan tomorrow's priorities

### Weekly Review Process

1. **Open Insights** (`Cmd+0`)
   - Review Overview tab for cognitive state
   - Check Focus Analytics for productivity patterns
   - Explore Emotional Heatmap for mood trends

2. **Review Memory Graph**
   - See recurring themes and connections
   - Identify patterns across projects

3. **Archive Completed Work**
   - Move completed projects to Archives
   - Archive old tasks and notes
   - Create reflection artifacts

4. **Plan Next Week**
   - Create new projects for upcoming work
   - Set priorities with Aurora's help
   - Schedule focus sessions

### Project Planning with Aurora

**Initial Setup:**
- "Create a project called [Project Name]"
- "Add 5 tasks to @projectname: [list tasks]"
- "Create a note for @projectname about [topic]"

**During Execution:**
- "What's the status of @projectname?"
- "Add a task to @projectname: [task description]"
- "Mark @taskname as done"
- Create artifacts to document progress

**Completion:**
- "Update @projectname status to completed"
- Create a reflection artifact about lessons learned
- Archive the project

### Journaling Routine

**Daily Reflection:**
1. Open Journal tab
2. Create Personal Reflection entry
3. Select mood (Excited, Grateful, Reflective, etc.)
4. Link to related projects or areas
5. Use AI prompts for guided reflection

**Content Ideas:**
- Capture ideas as Content Idea entries
- Link to relevant projects
- Use AI to expand on ideas

**Project Tracking:**
- Create Project Tracker entries
- Document progress and insights
- Review timeline view for patterns

### Research & Learning Workflow

1. **Capture Resources**
   - Create Notes with resource types (Article, Video, Book, Podcast)
   - Add source URLs
   - Tag with relevant topics

2. **Organize by Area**
   - Create a "Learning" Area
   - Link resources to learning projects
   - Use backlinks to connect related notes

3. **Create Artifacts**
   - Write Summaries of key learnings
   - Create Reflections on insights
   - Generate Reports on research findings

4. **Review & Connect**
   - Use Memory Graph to see connections
   - Ask Aurora: "What themes am I exploring?"
   - Link related concepts across notes

---

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
- `Cmd+N`: Context-Aware Create Sheet (adapts to current tab)
- `Cmd+Shift+A`: Aurora Spotlight (quick AI access)
- `Cmd+K`: Global Search (conversations, drafts, artifacts)
- `Cmd+,`: Settings
- `Cmd+Shift+N`: New Note
- `Cmd+Shift+T`: New Task
- `Cmd+Shift+P`: New Project
- `+` key (in Aurora): Open Contextual Create Sheet inline

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

### CloudKit Sync

- Automatic data sync across devices
- SwiftData with CloudKit integration
- Conflict resolution
- Offline support

---

## Performance Optimization

### Optimizing Response Speed

**Reduce Context Size:**
- Archive old conversations (>30 days)
- Compress long conversations (Aurora does this automatically after 40 messages)
- Clear stale recall entries periodically
- Use shorter, more focused queries

**Model Selection:**
- Use default `qwen3:1.7b` for fastest responses
- Enable thinking mode only for complex queries (automatic)
- Disable Hybrid Bridge if you prefer local-only processing
- Use Airplane Mode to eliminate network latency

**Large Workspace Management:**
- Archive completed projects regularly
- Use Areas to organize rather than creating many projects
- Limit active projects to 5-10 at a time
- Clean up old drafts and artifacts periodically

### Optimizing ARTE Performance

**Settings:**
- Reduce ARTE intensity if UI feels sluggish
- Disable adaptive timing if you prefer manual control
- Turn off learning mode if you don't need calibration
- Use Manual mode for consistent performance

**Polling Intervals:**
- ARTE automatically adapts polling (10-60s based on activity)
- High activity: Every 10 seconds
- Moderate activity: Every 30 seconds
- Idle: Every 60 seconds
- App inactive: Paused

**Memory Management:**
- ARTE uses ~5-8MB memory
- State transitions are debounced (2-minute minimum)
- Analytics snapshots cached for 15 seconds
- No performance impact when disabled

### Database Performance

**SwiftData Optimization:**
- Large workspaces (>10,000 items) may slow queries
- Archive old data regularly
- Use filters to limit query results
- Index frequently searched fields

**CloudKit Sync:**
- Initial sync may take time for large datasets
- Sync happens in background
- Disable CloudKit if not needed (Settings → iCloud)

### Ollama Performance

**Model Loading:**
- First request after starting Ollama takes 60-240 seconds
- Pre-warming happens automatically on app launch
- Keep Ollama running to avoid reload delays

**Large Prompts:**
- Prompts >15,000 chars can take 5-10 minutes
- Aurora automatically compresses conversations
- Consider breaking very large requests into smaller ones

**System Resources:**
- Ensure Ollama has 4GB+ RAM available
- Close other memory-intensive apps
- Use SSD storage for better model loading speed
- Monitor CPU usage (target: <50% for smooth operation)

---

## Privacy & Security

### Data Storage

**Local-First Architecture:**
- All data stored locally on your Mac using SwiftData
- Database location: `~/Library/Group Containers/group.kosmicapps.cloutmate/`
- No data sent to external servers by default
- CloudKit sync is optional and encrypted

**What Stays Local:**
- All workspace data (projects, tasks, notes, artifacts)
- All conversations with Aurora
- All AI processing (when using local Ollama)
- All insights and analytics
- All journal entries and reflections

**What Can Be Synced (Optional):**
- CloudKit sync: Encrypted sync across your Apple devices
- Notion integration: Only data you explicitly choose to sync
- Ollama Cloud API: Only if Hybrid Bridge enabled (API key required)

### AI Processing Privacy

**Local Processing:**
- Aurora runs entirely on your Mac using Ollama
- No data sent to external AI services by default
- All thinking and reasoning happens locally
- Model responses never leave your device

**Hybrid Bridge (Optional):**
- Cloud routing via Ollama Cloud API requires API key
- Only enabled if you explicitly configure it
- Automatic fallback to local Ollama if cloud unavailable
- You control when cloud routing is used

**Airplane Mode:**
- Complete network isolation
- All features work identically offline
- Zero external API calls
- Maximum privacy guarantee

### Encryption & Security

**Data Encryption:**
- SwiftData uses macOS encryption at rest
- CloudKit sync uses end-to-end encryption
- API keys stored in macOS Keychain (encrypted)
- No plaintext credentials stored

**Access Control:**
- App requires macOS permissions for:
  - Calendar access (for sync)
  - File access (for document analysis)
  - Network access (only if Hybrid Bridge enabled)
- All permissions are optional and user-controlled

### What We Don't Collect

- No telemetry or analytics sent externally
- No user behavior tracking
- No conversation content sent to third parties
- No personal data shared with external services
- No advertising or marketing data collection

**Exception:** If you enable Hybrid Bridge with Ollama Cloud API, your prompts and responses are sent to Ollama's cloud service (subject to their privacy policy).

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
- Projects V2 Redesign (see `.cursor/plans/projects-v2-redesign-7e538134.plan.md`)

**Recently Completed:**
- ✅ Context-Aware Create Sheet with smart defaults
- ✅ Artifact system with 6 output formats (Brief, Summary, Reflection, Report, Release Note, Lesson Learned)
- ✅ CreateActionUsageTracker for predictive action suggestions
- ✅ @ Mention linking system with autocomplete

### Planned Features

**Phase 2:**
- ✅ Artifact Templates management UI
- Menu Bar Quick Actions
- Spotlight integration for artifact creation
- Enhanced predictive scheduling

**Phase 3:**
- Smart Draft Suggestions based on artifact patterns
- AI-powered insights summaries
- Advanced analytics and pattern recognition

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

## Troubleshooting

### Aurora Not Responding

**Ollama Connection Issues:**
- **Symptom**: "Ollama is not running or not accessible"
- **Solution**: 
  1. Open Terminal
  2. Run `ollama serve`
  3. Wait for "Server started" message
  4. Try again in Cloutmate
- **Prevention**: Keep Ollama running in background or set to start on login

**Model Not Found:**
- **Symptom**: "The requested model is not installed"
- **Solution**:
  1. Open Terminal
  2. Run `ollama pull qwen3:1.7b`
  3. Wait for download to complete
  4. Try again in Cloutmate

**Timeout Errors:**
- **Symptom**: Request times out after several minutes
- **Causes**:
  - Model loading for first time (60-240 seconds)
  - Very large prompts (>15,000 chars)
  - System resources constrained
- **Solutions**:
  1. Wait and try again (first request always slowest)
  2. Check Ollama logs: Run `ollama serve` in Terminal
  3. Try shorter prompt first
  4. Restart Ollama: `pkill ollama && ollama serve`
  5. Ensure 8GB+ RAM available for Ollama
  6. Consider using smaller model for large contexts

### Slow Performance

**Slow Aurora Responses:**
- Reduce context size (archive old conversations)
- Disable Hybrid Bridge if network is slow
- Use Airplane Mode for consistent local performance
- Check Ollama CPU/memory usage
- Close other memory-intensive apps

**Slow UI/ARTE:**
- Reduce ARTE intensity in Settings
- Disable adaptive timing
- Turn off ARTE learning mode
- Use Manual ARTE mode for consistent performance
- Check system resources (Activity Monitor)

**Large Workspace Slowness:**
- Archive completed projects (>30 days old)
- Limit active projects to 5-10
- Clean up old drafts and artifacts
- Use filters to limit query results
- Consider disabling CloudKit sync if not needed

### Conversations Not Saving

**Symptom**: Conversations disappear after closing app
- **Cause**: SwiftData context not saving
- **Solution**: 
  1. Check Console.app for SwiftData errors
  2. Ensure app has write permissions
  3. Try creating new conversation
  4. Restart app if issue persists
- **Note**: Conversations auto-save after each message

### ARTE Not Detecting States

**Symptom**: ARTE state stuck or not changing
- **Solutions**:
  1. Check ARTE is enabled in Settings
  2. Ensure you have workspace activity (tasks, focus sessions)
  3. Try Manual mode to test states
  4. Reset ARTE learning data in Settings
  5. Check Insights → Overview for current state

**State Detection Requirements:**
- Focused: Requires active focus session + high CPS scores
- Reflective: Requires Memory Graph exploration
- Energized: Requires high completion rate + positive valence
- Fatigued: Requires low energy + late hours

### Focus Sessions Not Tracking

**Symptom**: Focus sessions don't appear in analytics
- **Solutions**:
  1. Ensure focus session completed (not cancelled)
  2. Check Focus Analytics tab in Insights
  3. Verify session has objective set
  4. Wait a few minutes for analytics to update

### Document/Image Analysis Failing

**Image Analysis Errors:**
- **Symptom**: "I need your Google API key"
- **Solution**: Add Google API key to Config.plist (GoogleAPIKey)
- **Note**: Image analysis requires cloud access (Gemini API)

**Document Analysis Timeout:**
- **Symptom**: Document analysis times out
- **Solutions**:
  1. Document might be too large (>80MB download, >25MB persist)
  2. Try smaller document first
  3. Check network connection (if using cloud routing)
  4. Use local Ollama for privacy (no size limits)

### Notion Sync Issues

**Connection Problems:**
- Re-authenticate in Settings → Integrations → Notion
- Check Notion API status
- Verify database permissions in Notion

**Sync Not Working:**
- Check sync schedule in Settings
- Manually trigger sync
- Verify property mappings are correct
- Check for duplicate entries

### General Issues

**App Crashes:**
- Check Console.app for crash logs
- Ensure macOS is up to date
- Verify SwiftData database integrity
- Try resetting app data (last resort)

**Build Errors:**
- Clean build folder (`Cmd+Shift+K`)
- Delete derived data
- Ensure all dependencies are installed
- Check Xcode version compatibility

**Still Having Issues?**
- Check Console.app for detailed error messages
- Review Ollama logs (`ollama serve` in Terminal)
- Open an issue on the repository with:
  - macOS version
  - Error messages from Console
  - Steps to reproduce
  - Ollama model versions

---

For questions, issues, or feature requests, please open an issue on the repository.

---

**Built with ❤️ by Kosmic Apps**
