<!-- c01fa6ae-ed5d-4658-8727-d35842c8f7d2 c3df6612-f400-48d6-b802-d3c5f5ea6b78 -->
# Clean Up Aurora System Prompts

## Overview
Remove hardcoded feature lists from Aurora's system prompts and rely on AuroraChangelogService for feature/update information. Keep only essential personality, behavior, and response format instructions that define Aurora's core identity.

## Current State
- Two system prompts exist:
  1. `generateResponse()` (lines 467-501): Simple prompt with hardcoded feature list
  2. `buildSystemPrompt()` (lines 1160-1257): Comprehensive prompt with changelog integration but still contains long "CORE CAPABILITIES" list
- AuroraChangelogService is already integrated and adds recent changes (last 14 days) to prompts
- Changelog self-awareness instructions are already present

## Changes Required

### 1. Clean up `generateResponse()` system prompt
**File:** `FocusOS/Services/OllamaBridgeService.swift` (lines 467-501)

**Remove:**
- Hardcoded "Your Core Capabilities (All Fully Implemented)" list (lines 470-490)
- Detailed feature descriptions that duplicate changelog content

**Keep:**
- Core identity statement ("You are Aurora...")
- Response format instructions (CRITICAL and IMPORTANT sections)
- Data schema reference
- Context parameter

**Add:**
- Brief reference to changelog for feature information
- Note that capabilities are tracked in changelog

### 2. Clean up `buildSystemPrompt()` CORE CAPABILITIES section
**File:** `FocusOS/Services/OllamaBridgeService.swift` (lines 1163-1183)

**Remove:**
- Detailed feature descriptions that duplicate changelog (e.g., "Recall Layer: pull the most relevant...", "Airplane Mode Support: You can run...", etc.)
- Phase-specific implementation details
- Technical implementation details

**Keep:**
- Core personality traits and behavior guidelines
- Essential operational instructions (how to respond, format, etc.)
- Response format instructions
- Data schema reference

**Simplify to:**
- Brief statement that capabilities are tracked in changelog
- Reference to recent changes already being injected
- Keep only behavioral/personality instructions

### 3. Ensure changelog integration is optimal
**File:** `FocusOS/Services/OllamaBridgeService.swift` (lines 1225-1255)

**Verify:**
- Recent changes (14 days) are being added correctly
- Changelog self-awareness instructions are clear
- Update detection logic is working (if exists)

**Enhance:**
- Make changelog reference more prominent in simplified prompts
- Ensure Aurora knows to reference changelog for capability questions

## Implementation Details

### Simplified `generateResponse()` prompt structure:
```
You are Aurora, the AI assistant living inside FocusOS (the app). 
[Core identity and personality - keep as is]

Your capabilities and recent updates are tracked in your changelog, 
which is automatically included in your context. Reference it when 
users ask about features or updates.

[Response format instructions - keep as is]
[Data schema - keep as is]
```

### Simplified `buildSystemPrompt()` CORE CAPABILITIES section:
```
CORE IDENTITY & BEHAVIOR:
[Keep personality traits, behavior guidelines]
[Keep response format instructions]

CAPABILITIES & UPDATES:
Your capabilities and recent updates are tracked in your changelog 
and automatically included in your context. When users ask about 
features, capabilities, or updates, reference the changelog information 
provided in your context.

[Keep changelog self-awareness instructions that already exist]
```

## Files to Modify
- `FocusOS/Services/OllamaBridgeService.swift`
  - `generateResponse()` method (lines ~467-501)
  - `buildSystemPrompt()` method (lines ~1160-1257)

## Testing Considerations
- Verify Aurora still responds correctly to capability questions
- Ensure changelog information is being referenced properly
- Confirm personality and behavior remain consistent
- Check that response format instructions are still followed

### To-dos

- [ ] Clean up generateResponse() system prompt: Remove hardcoded feature list, keep core identity and response format instructions, add changelog reference
- [ ] Clean up buildSystemPrompt() CORE CAPABILITIES section: Remove detailed feature descriptions, keep only personality/behavior instructions, simplify to reference changelog
- [ ] Verify changelog integration is working correctly and Aurora references it appropriately