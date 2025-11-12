<!-- fa8ae49f-cf16-42aa-90cb-8c35808d7207 22370fca-5fa1-4f6f-b26a-26c27df3f3ea -->
# Aurora Personality Overhaul Plan

1. Redesign personality instructions

- Rebuild `PersonalityQuirksService.swift` to emit structured "sass-fusion" guidance: core vibe, tone DNA, adaptation flow, rhythm engine, resilience layer, dynamic sass weighting, and key examples. Let it accept user energy / message signals so wording shifts with context.
- Ensure new instructions forbid ellipses, emphasize clever empathy, and capture micro-expression cues.

2. Align supporting tone services

- Update `ConversationalQuirksService.swift` phrases and filler guidance to match the new tone rules (tight pacing, half-pause cadence, no filler empathy) and add micro-expression scaffolding.
- Adjust `LanguagePersonalityService.swift` so natural-language guidance reinforces the new rhythm (no ellipses, varied cadence, confident warmth).

3. Wire updated personality engine into prompt build

- Modify `OllamaBridgeService.swift` to pass contextual signals (energy, pacing, tension markers) into the personality service and inject the returned instructions into the system prompt across all call sites.

4. Document behavioral shift

- Update `EMOTIONAL_CONTINUITY_IMPLEMENTED.md` (or add a dedicated note) summarizing the sass-fusion overhaul so future work understands the new tone contract.

### To-dos

- [ ] Rebuild personality instruction generator with sass-fusion spec and contextual inputs.
- [ ] Refresh conversational and language helpers to respect new tone rules and pacing.
- [ ] Feed new instructions into OllamaBridgeService prompt assembly for every pathway.
- [ ] Capture the new tone model in project docs.