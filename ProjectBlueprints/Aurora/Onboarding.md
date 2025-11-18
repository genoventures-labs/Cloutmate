# Aurora Onboarding Checklist

Use this runbook whenever you provision FocusOS or bring Aurora online on a new development machine.

---

## 1. Prerequisites

1. **macOS + Xcode** – macOS 15, Xcode 16+, command-line tools installed.
2. **Ollama** – `brew install ollama` and pull required models:
   ```bash
   ollama pull qwen3:1.7b qwen3-vl:2b gemma3:1b gemma3:4b granite3.2:2b granite3.2-vision gwen2.5-coder:1.5b deepseek-r1:1.5b
   ```
3. **API Keys** – Populate `FocusOS/Config/Config.plist` with Notion, Google Vision, Threads/Meta tokens as needed. Optionally set `OllamaCloudAPIKey` for Hybrid Bridge (Info.plist or env var).
4. **Shared App Group** – Ensure all targets share `group.com.kosmicapps.FocusOS` and that `FocusOSShared.framework` is embedded everywhere (see `SETUP_GUIDE.md`).

---

## 2. First Run Sequence

1. **Open `FocusOS.xcodeproj`** and select the `FocusOS` scheme.
2. **Build** (⌘B) to let SwiftData synthesize model schemas.
3. **Launch** (⌘R). On first launch:
   - `SharedDataManager` creates the shared container.
   - `ModelWarmupService` warms each target model (watch logs for "Warming up" messages).
   - `ReactiveThemeManager`, `FocusRitualManager`, `SmartNudgeService`, `CognitionPredictor`, and `FlowCompanionEngine` start via `FocusOSApp.onAppear`.
   - Reflection prompts load from `FocusOS/Config/ReflectionPrompts.plist`.
4. **Authenticate** any integrations you need (Notion, Meta/Threads, Google Vision) via Settings.
5. **Seed Data** (optional) – Create a project, task, focus session, and journal entry so analytics/ARTE have data to work with.

---

## 3. Feature Flags

`FocusOS/Config/AIConfig.plist` controls subsystem enablement:

- Ensure these keys are `true` in production/dev builds:
  - `AIRecallEnabled`
  - `AIActionRouterEnabled`
  - `AICPSEnabled`
  - `AINarrativeEnabled`
  - `AIMemoryGraphEnabled`
  - `AIFeedbackLoggingEnabled`
  - `AuroraReactiveThemeEnabled`
  - `AuroraPredictiveEnabled`
- Toggle additional experiments (Hybrid Bridge, Research Mode) via their respective flags and surface status to Aurora through `AuroraSystemPromptBuilder`.

---

## 4. Smoke Tests

After first launch, validate the pillars:

| Test | Steps | Expected |
| --- | --- | --- |
| **Execution** | Cmd+Shift+A → "Create a task called 'Verify onboarding'" | Task appears in Tasks tab, Aurora confirms without asking for confirmation. |
| **Reflection** | "What patterns do you see?" | Response references Insights tabs, Memory Graph themes, CPS priorities. |
| **Doc analysis** | Attach a PDF in Aurora chat → "Analyze this document" | Response summarizes doc, extracts actions, indexes for recall. |
| **Image analysis** | Paste an image → use "/analyze image" toolbar action | Response uses `qwen3-vl:2b`, mentions vision model. |
| **Research mode** | `/research benefits of PARA` | Aurora reports multi-step research with source citations. |
| **Predictive cognition** | Start/end a focus session, run "When will I be most focused today?" | Mentions latest forecast, next window time. |
| **Flow Companion** | Stay idle > idle timeout or trigger manual reflection | Bubble appears with ARTE-tinted prompt, saves reflection note. |

---

## 5. Knowledge Synchronization

- `AuroraSystemPromptBuilder` writes versions to `~/Library/Containers/.../Documents/aurora_prompt_versions.json`. Verify a version exists after first conversation.
- Run `scripts/update_commit_hash.py` if you update prompts/system docs so Aurora references the correct git commit.
- Check `AURORA_README.md`, `AURORA_KNOWLEDGE_BASE_UPDATED.md`, and `/ProjectBlueprints/Aurora/*.md` for consistency whenever you ship major changes.

---

## 6. Troubleshooting

| Symptom | Fix |
| --- | --- |
| Aurora says a subsystem is disabled | Confirm `AIConfig.plist` flag + service initialization order (e.g., Memory Graph must load before reflections). |
| No local models found | Run `ollama list`, ensure names match `ModelTierMap`. Update `ModelRoutingEngine` fallback if using alternative names. |
| Hybrid Bridge errors | Provide `OllamaCloudAPIKey` and call Settings → AI Assistant → "Test Connection". |
| Flow Companion silent | Open Settings → Flow Companion, ensure triggers enabled and `FlowTriggersService.start()` is called (app must emit `.UserActivity`). |
| Reflection prompts missing | Check `ReflectionPrompts.plist`, ensure it’s bundled in the main target.

---

Completing this checklist ensures Aurora has the data, models, and documentation she needs to perform every phase reliably.
