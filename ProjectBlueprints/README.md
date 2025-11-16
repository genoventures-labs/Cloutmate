# Cloutmate Project Blueprint

This folder is the canonical briefing for anyone who needs to understand or extend Cloutmate—an AI-first macOS workspace that fuses the PARA methodology, Aurora's cognitive systems, and multiple companion surfaces (menu bar, widget, helper).

## How to Read This Blueprint
- **Start here** for an end-to-end mental model of the application and repository layout.
- **Dive into `/Aurora`** for subsystem deep dives (architecture, model routing, ARTE, Memory Graph, predictive brain, flow companion, narrative engine, onboarding).
- **Use `/Cloutmate`** for workspace-specific specs (structure, dashboard, sidebar, intent clusters, command system).
- **Check `/Voice`** for tone guidance and `/Build` for release history + phase tracking.

---

## 1. Application Stack at a Glance

| Layer | What Lives Here | Key Paths |
| --- | --- | --- |
| **macOS App** | SwiftUI/SwiftData workspace implementing Capture → Organize (PARA) → Express → Tools. | `Cloutmate/` (Views, ViewModels, Services, Models, Utilities)
| **Shared Framework** | SwiftData models + shared services consumed by the app, widget, helper, and menu bar. | `CloutmateShared/CloutmateShared`
| **Companions** | Menu bar quick capture + upcoming posts, Widget timeline, Helper background publisher. | `CloutmateMenuBar/`, `CloutmateWidget/`, `CloudmateHelper/` & `CloutmateHelper/`
| **AI Subsystems** | Aurora runtime (phases 1-10), ARTE, Memory Graph, Predictive Cognition, Flow Companion. | `Cloutmate/Services`, `Cloutmate/Models`, docs prefixed with `AURORA_`, `PHASE*`
| **Automation & Scripts** | Release helpers and changelog tooling. | `scripts/generate_changelog.py`, `scripts/update_commit_hash.py`
| **Build Outputs** | Derived artifacts from Xcode builds (safe to clean). | `build/`

### Targets & Schemes
- `Cloutmate` (main app, SwiftUI) – entry: `Cloutmate/CloutmateApp.swift`.
- `CloutmateShared` (framework) – models like `CloutmateShared/CloutmateShared/Models/Post.swift`.
- `CloutmateMenuBar` – lightweight status item defined in `CloutmateMenuBar/MenuBarApp.swift`.
- `CloutmateWidget` – WidgetKit surface pulling from shared data.
- `CloutmateHelper` – background helper for scheduling/publishing (see `SETUP_GUIDE.md`).

All persistence is SwiftData backed by `SharedDataManager.createSharedModelContainer()` so the macOS app, menu bar utility, widget, and helper read/write the same Core Data store via the shared app group.

---

## 2. Workspace Surfaces & Tabs

Cloutmate's primary window (see `Cloutmate/Views/MainWindowView.swift`) organizes workflows via tabs mapped to the PARA method:

- **Capture:** Inbox, Notes, Journal, Quick Capture drawers, Voice Memo drawer.
- **Organize:** Projects, Tasks, Areas, Resources, Archives – all SwiftData-backed models in `CloutmateShared/…/Models`.
- **Express:** Drafts, Calendar, Artifacts (Posts) with the Artifact Composer and templates.
- **Tools:** AI Assistant, Focus Mode, Focus Gravity, Rituals, Insights, Settings.

Each tab has dedicated view folders (e.g., `Cloutmate/Views/Projects`, `Cloutmate/Views/Focus`). Context-aware creation (`ContextualCreateDrawer`), slash commands, and global search (⌘K `CommandPaletteView.swift`) keep navigation fluid across tabs.

---

## 3. Aurora Cognitive Operating System

Aurora runs entirely on-device via Ollama. The command pipeline in `Cloutmate/ViewModels/AIAssistantViewModel.swift` orchestrates:

1. **Intent detection** → distinguishes reflection vs execution (see `AIReflectionService.swift`, `AIActionRouter.swift`).
2. **Payload building** → `AnalyticsEngine`, `MemoryGraphService`, `ConversationArchive`, `PriorityEngine` feed `AIPayloadContext`.
3. **Model routing** → `ModelRoutingEngine` + `ModelTierMap` choose local models, with `ModelWarmupService`, `HybridBridgeService`, and `FallbackRoutingService` providing resilience.
4. **Response shaping** → `AuroraSystemPromptBuilder` assembles prompts with versioning; `AuroraToneKit`, `StyleAdapter`, `TypingSimulationService`, `ResponseTimingService` coordinate output personality.
5. **Post-processing** → actions executed, feedback logged (`AIFeedbackLogger`), CPS boosted, memories updated, Flow Companion notified.

Phases 1–10 are fully implemented (see `AURORA_README.md` + `AURORA_IMPLEMENTATION_AUDIT.md`):

1. Recall + Emotional Continuity (`AIRecallService`)
2. Action Router + Feedback Loop (`AIActionRouter`, `AIFeedbackLogger`)
3. Contextual Priority System (`PriorityEngine`, `PriorityScore`)
4. Focus Mode (`FocusSessionService`, deep work UI)
5. Narrative Engine + Cross-conversation memory (`NarrativeEngine`, `ConversationArchive`)
6. Memory Graph (`MemoryGraphService`, `ThemeExtractionPipeline`)
7. ARTE emotional theming (`ReactiveThemeManager`)
8. Focus Rituals & Smart Nudges (`FocusRitualManager`, `SmartNudgeService`)
9. Predictive Cognition + Temporal intelligence (`CognitionPredictor`, `PredictiveContextManager`, `AdaptiveScheduler`, `CalendarSyncService`)
10. Flow Companion bubble & clarity coach (`FlowCompanionEngine`, `AIFlowCompanion`).

---

## 4. Data & Intelligence Infrastructure

- **SwiftData Models:** Located in `Cloutmate/Models` and `CloutmateShared/…/Models`. Highlights: `FocusSession`, `StoryToken`, `MemoryNode`, `PriorityScore`, `FlowCompanionState`, `IntentCluster`.
- **Analytics Layer:** `AnalyticsEngine` aggregates productivity, emotional, focus, and learning metrics that drive Insights tabs and AI reflections.
- **Memory Graph:** `MemoryGraphService` + `ThemeExtractionPipeline` maintain embeddings, DBSCAN clusters, and predictive hooks.
- **Predictive Systems:** `CognitionPredictor`, `DriftMonitor`, `MomentumMetrics`, `PredictiveContextManager`, `ToneForecastService` anticipate energy windows and drift risk.
- **ARTE + Tone:** `ReactiveThemeManager`, `EmotionalStateDetector`, `ThemeInterpolator`, `AuroraToneKit`, `SidebarToneSyncService` keep the UI emotionally coherent with user state.

---

## 5. Supporting Surfaces

- **Menu Bar (`CloutmateMenuBar/`)** – `MenuBarApp.swift` renders `MenuBarPopoverView` with quick capture, upcoming posts, tasks, reminders, and uses `NotificationService` for updates.
- **Widget (`CloutmateWidget/`)** – SwiftUI widget timeline summarizing scheduled artifacts/tasks via shared models.
- **Helper Apps (`CloudmateHelper/`, `CloutmateHelper/`)** – background daemons controlling publishing, scheduling, and login item registration (see `BUILD_AND_SIGN_MENUBAR.md`, `SIGN_MENUBAR_APP.sh`).

All companions rely on `CloutmateShared` and must share the app group + entitlements (see `SETUP_GUIDE.md`).

---

## 6. Tooling, Scripts, and Configuration

- **Config:** `Cloutmate/Config/AIConfig.plist` (feature flags), `Config.plist` (API keys), `ReflectionPrompts.plist` (Flow Companion prompts) feed runtime services.
- **Scripts:**
  - `scripts/update_commit_hash.py` – keeps prompt metadata aware of git revisions.
  - `scripts/generate_changelog.py` – compiles deployment changelogs.
- **Setup references:** `SETUP_GUIDE.md`, `SETUP_OAUTH.md`, `XCODE_SETUP_STEPS.md`, `HOW_TO_ADD_FILES_TO_TARGET.md` capture environment prep, OAuth secrets, target membership, and signing requirements.

---

## 7. Developer Workflow Checklist

1. **Prereqs:** Xcode 16+, Swift 5.10 toolchain, Ollama installed with `qwen3:1.7b`, `granite3.2:2b`, `gemma3:4b`, `gwen2.5-coder:1.5b`, `deepseek-r1:1.5b`, and `qwen3-vl:2b` pulled.
2. **Config:** Populate `Config/Config.plist` with API keys (Notion, Google Vision, etc.), set Info.plist Meta keys, optional Ollama Cloud key via env var.
3. **Targets:** Ensure `CloutmateShared` is added to app/menu bar/widget/helper. Confirm entitlements share `group.com.kosmicapps.Cloutmate`.
4. **Datastore:** Run once to initialize SwiftData/Flow Companion records (FlowCompanionState, ARTEConfiguration). Use `MigrationRunner` if schema changes appear in build logs.
5. **Aurora Smoke Test:**
   - Run `Cmd+Shift+A` (Aurora Spotlight) and issue: "Create a task called test" (execution), "What patterns do you see?" (reflection), `/research future of PARA` (research mode), and attach a PDF/image to confirm `DocumentAttachmentService` + `ImageAttachmentService` + `ModelRoutingEngine`.
6. **Flow Systems:** Start a focus session, end it to trigger `FlowTriggersService` and Flow Companion bubble, then check Insights → Overview for ARTE state transitions.

---

## 8. Reference Map

Use the remaining files in this folder for deep dives:

- `Aurora/Architecture.md` – service map & request lifecycle.
- `Aurora/ModelRouting.md` – tiered model selection & fallbacks.
- `Aurora/ARTE.md` – emotional theming internals.
- `Aurora/MemoryGraph.md` – embeddings, clustering, predictive hooks.
- `Aurora/PredictiveBrain.md` – cognition forecasting + proactive posture.
- `Aurora/FlowEngine.md` – Flow Companion bubble + triggers.
- `Aurora/NarrativeEngine.md` – story token pipeline.
- `Aurora/Onboarding.md` – enabling Aurora on fresh machines.
- `Cloutmate/Structure.md` – repo anatomy + feature inventory.
- `Cloutmate/DashboardSpec.md` & `SidebarSpec.md` – UI surface breakdowns.
- `Cloutmate/IntentClusters.md` – predictive conversation clustering.
- `Cloutmate/CommandSystem.md` – search, commands, contextual create.
- `Voice/ToneGuidelines.md` – copy + assistant voice direction.
- `Build/UpgradeHistory.md` & `Build/PhaseLog.md` – timeline + phase tracking.

Treat this folder as the source of truth when onboarding humans or AI collaborators.
