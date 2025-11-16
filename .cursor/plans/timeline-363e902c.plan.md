<!-- 363e902c-0f97-4d0b-bc6d-5a4350ebbb72 5322f911-af8c-4ce5-b18f-64d9eff375ce -->
# Aurora Nudge Overlay Refresh

1. Audit Current Overlay

- Review `NudgeOverlayView.swift` to map existing state (service bindings, buttons, dismissal) and note dependencies to preserve.

2. Build Aurora Orb & Speech Bubble UI

- Extract a reusable mini-orb view matching sidebar styling.
- Replace the boxed layout with an orb + glass speech bubble stack, styled per V2 (gradients, blur, subtle shadows, typography).
- Rework buttons to glass pill styles and add a pin icon button.

3. Implement Animation & Interaction Logic

- Position overlay near bottom-right with offset/opacity animation (slide-up + fade).
- Add auto-dismiss timer (~7s), hover detection to pause countdown, and pin state to keep it visible until unpinned/dismissed.
- Ensure existing nudge actions still call `handleResponse` and that pinned state clears on dismiss.

4. Tidy & Verify Behavior

- Double-check light/dark contrast, transition smoothness, accessibility (escape to dismiss, VoiceOver labels).
- Manually exercise accept/snooze/dismiss flows, hover, timer, and pin persistence to confirm no regressions.

### To-dos

- [ ] Skim NudgeOverlayView.swift and related styles to understand current state management and UI pieces.
- [ ] Implement orb avatar, speech bubble layout, V2 styling, and pin control in NudgeOverlayView.
- [ ] Add slide/fade animations, hover pause, pin persistence, and timed auto-dismiss behavior.
- [ ] Test overlay interactions (accept, snooze, dismiss, pin, hover) across themes.