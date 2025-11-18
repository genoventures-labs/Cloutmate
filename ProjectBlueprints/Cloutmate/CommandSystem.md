# Command & Creation System

FocusOS provides multiple layers of command surfaces so users (or automation) can act from anywhere: global search, contextual create, slash commands, voice, and Aurora toolbar actions. This document catalogs each layer so you can extend them consistently.

---

## 1. Global Command Palette (`Views/Components/CommandPaletteView.swift`)

- **Shortcut:** ⌘K or notifications (`Notification.Name("OpenCommandPalette")`).
- **Data sources:** SwiftData queries for Conversations, Drafts, Posts, Projects, Tasks, Notes, Inbox items.
- **Features:**
  - Category filters (`SearchCategory` enum) + icons.
  - Date range filter toggle.
  - Inline fuzzy search across titles, summaries, tags, mention-resolved Markdown.
  - Arrow-key navigation + enter to open the entity’s tab.
- **Extension points:** Add new `SearchCategory` cases, update `filteredResults`, and ensure `SearchResult` links to the correct entity view.

---

## 2. Contextual Create Drawer (`Views/Components/ContextualCreateSheet.swift`)

- **Shortcut:** Cmd+N or the "+" UI button; can be triggered by posting `.openContextualCreate` with a `TabIdentifier` payload.
- **Behavior:**
  - Adapts action grid to the active tab (Inbox, Notes, Tasks, Drafts, Projects, Posts, Resources, Calendar, Journal, default fallback).
  - Highlights "most used" actions via `CreateActionUsageTracker` and shows "recently created" state.
  - ARTE tinting: temporarily tweaks `GlassColorSystem` accent to match previous emotional state, then restores.
- **Extensibility:** Update `actionsForTab`, add new `CreateAction` types with icons/colors, implement handlers that call dedicated services (e.g., `FocusSessionService.startFocusSession`).

---

## 3. Slash Commands & Mentions

- **Slash Command Autocomplete** (`SlashCommandAutocompleteView.swift`) exposes actions like `/task`, `/note`, `/ritual`. Extend by adding new command definitions.
- **Mentioning** (`MentionParser`, `MentionService`, `MentionAutocompleteView`, `MentionTextEditor`) lets users link objects with `@Project`, `@Task`, etc. Mention support powers Aurora’s `@` referencing, so keep the parser updated when new models appear.

---

## 4. Aurora Toolbar Actions

- Defined in `FocusOSApp.commands` (⌘⇧1–6) to instantly fire AI actions:
  1. Create Task
  2. Create Project
  3. Create Note
  4. Create Reminder
  5. Analyze Document
  6. Analyze Image
- Implementation: commands post `NSNotification.Name("AuroraToolbarAction")` with a `ToolbarAction` enum; `AIAssistantViewModel` listens and injects the action into the chat pipeline.

---

## 5. Voice & Quick Capture

- **Voice Memo Drawer** (`VoiceMemoDrawer`, `VoiceInputButton`, `VoiceTranscriptionService`) records and transcribes audio into Inbox items or Notes.
- **Quick Capture Drawer** (`QuickCaptureDrawer`, `InboxQuickCaptureDrawer`) attaches to the global overlay stack for trapdoor capture from any tab.
- Both drawers respect Flow Companion’s idle detection by posting `.UserActivity` notifications.

---

## 6. Notifications & Hooks

- `Notification.Name.switchTab` – Navigation triggered by Aurora, dashboard cards, or menu actions.
- `Notification.Name.openComposer` – Launch Artifact Composer (used by commands + AI responses).
- `Notification.Name.showQuickCapture`, `.showVoiceMemo`, `.openContextualCreate` – unify overlays triggered by keyboard shortcuts, toolbar buttons, or AI instructions.

---

## 7. Extending the Command System

1. **Add a command** – Decide whether it belongs in the palette, slash commands, contextual drawer, or toolbar. Implement once, then broadcast notifications so all surfaces stay in sync.
2. **Update metrics** – Record usage via `CreateActionUsageTracker` or `ToolbarUsageTracker` so AI + analytics understand popularity.
3. **AI integration** – Document new commands in `AuroraSystemPromptBuilder` so the assistant knows they exist.
4. **Testing** – Validate keyboard shortcuts, overlay stacking (only one overlay visible at a time), and Flow Companion idle resets.

These layers make FocusOS feel like a responsive command console; treat new actions as first-class citizens across all entry points.
