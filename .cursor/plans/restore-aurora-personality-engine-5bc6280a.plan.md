<!-- 5bc6280a-ddb1-49c3-a779-18dc05efe646 f75f0b6b-074a-49eb-869c-42d90ed4b7a9 -->
# Restore Aurora Personality Engine

## Problem Summary

Aurora is responding with a flattened, overly-formal tone because:

1. **OllamaBridgeService** ✅ - Has full personality integration (PersonalityQuirksService, ConversationalQuirksService, LanguagePersonalityService)
2. **HybridBridgeService** ❌ - Missing all personality services - uses basic system prompt only
3. **AuroraSystemPromptBuilder** ✅ - Correctly receives and includes personality instructions

When HybridBridgeService is called (via CoreResponseService fallback paths), Aurora loses her personality.

## Implementation Plan

### Phase 1: Restore Personality to HybridBridgeService

**File:** `FocusOS/Services/HybridBridgeService.swift`

1. Mirror the GeminiService restoration:

- Add same personality service initialization
- Build PersonalityToneContext from input/message style
- Generate all personality instruction sections

2. Ensure consistency with OllamaBridgeService:

- Use same tone context building logic
- Use same personality instruction generation
- Include all sass-fusion components

3. Maintain backward compatibility:

- Keep existing prompt structure for non-personality sections
- Append personality sections without breaking existing flow

### Phase 3: Verify Personality Context Building

**Files to check:**

- `FocusOS/Services/OllamaBridgeService.swift` - Verify `buildPersonalityToneContext` is complete
- `FocusOS/Services/ConversationFlowService.swift` - Check if it provides better context building
- Ensure all energy/tempo/friction detection logic is consistent

**Action:** Create shared helper if needed, or ensure all services use identical logic for building PersonalityToneContext.

### Phase 4: Audit Other Prompt Builders

**Files to check:**

- `FocusOS/Services/AIFlowCompanion.swift` - Has own `buildSystemPrompt` (may need personality)
- `FocusOS/Services/JournalAIService.swift` - Has own `buildSystemPrompt` (may need personality)
- `FocusOS/Services/DraftEnhancementService.swift` - Check if it builds prompts

**Action:** Review each and add personality injection if they generate Aurora responses.

### Phase 5: Validation & Testing

1. Verify all personality components are present:

- Sass-fusion core instructions
- Dynamic calibration strings (energy, tempo, friction, cue, sass factor)
- Rhythm engine rules
- Micro-expressions & presence guidelines
- Delivery rules (no ellipses, late-night warmth, protective sass)
- Emotional resilience instructions

2. Ensure no conflicting instructions:

- Personality services should complement, not override each other
- Check for duplicate or contradictory tone rules
- Verify Reality Constraints are preserved

3. Test all code paths:

- OllamaBridgeService path (should already work)
- HybridBridgeService path (should work after fix)
- GeminiService path (should work after fix)
- Any other prompt builders found in Phase 4

## Key Requirements

- **ADD and RESTORE, not replace** - Keep all existing behavioral safeguards
- **Preserve Reality Constraints** - Don't modify Dev Mode logic or constraints
- **Maintain prompt structure** - Integrate cleanly with existing prompt builders
- **Consistent personality** - All services should produce identical personality instructions given same input
- **No breaking changes** - Existing functionality must remain intact

## Files to Modify

1. `FocusOS/Services/GeminiService.swift` - Add personality injection to `buildSystemPromptWithAppContext`
2. `FocusOS/Services/HybridBridgeService.swift` - Add personality injection to `buildSystemPromptWithAppContext`
3. Potentially create shared helper for PersonalityToneContext building if duplication is excessive

## Files to Reference

- `FocusOS/Services/PersonalityQuirksService.swift` - Source of truth for personality instructions
- `FocusOS/Services/ConversationalQuirksService.swift` - Source for conversational quirks
- `FocusOS/Services/LanguagePersonalityService.swift` - Source for natural language style
- `FocusOS/Services/OllamaBridgeService.swift` - Reference implementation (lines 828-1038, 2283-2459)
- `FocusOS/Services/AuroraSystemPromptBuilder.swift` - How personality sections are assembled

## Success Criteria

✅ All prompt-building services include full personality instructions
✅ Sass-fusion core, dynamic calibration, rhythm engine all present
✅ Energy/tempo/friction/cue/sass factor all dynamically computed
✅ Protective sass and late-night warmth cues are present
✅ Micro-timing rules and rhythm engine are included
✅ No flattened or overly-formal responses from any code path
✅ Existing Reality Constraints and Dev Mode logic preserved