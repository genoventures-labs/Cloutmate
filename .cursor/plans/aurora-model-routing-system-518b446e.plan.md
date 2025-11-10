<!-- 518b446e-4c31-4c41-96ce-ff2f5ea9383c f9d02a85-c00e-4e82-bc7f-450e3ba1e3c8 -->
# Fix Model Rotation and Conversation Tags

## Issue 1: Model Rotation - Thinking Content When Not Requested

**Problem**: Logs show thinking content being returned and stored even when `useThinking: false` is set. For example:

- `Model: qwen3:1.7b, Thinking: false` but `Thinking length: 1959 chars`
- This causes thinking UI to appear when it shouldn't

**Root Cause**: In `OllamaBridgeService.makeOllamaRequest()`, we return `ollamaResponse.thinking` regardless of whether we requested it. Some models may return thinking content even when `thinking: false` is set in options.

**Fix**:

1. In `makeOllamaRequest()` (line ~1019), only return thinking content if `useThinking` was true:
   ```swift
   let thinkingContent = useThinking ? ollamaResponse.thinking : nil
   return (ollamaResponse.response, thinkingContent)
   ```

2. Update logging (line ~1012) to only log thinking length when thinking was requested:
   ```swift
   if useThinking, let thinking = ollamaResponse.thinking, !thinking.isEmpty {
       print("[OllamaBridgeService] Thinking length: \(thinking.count) chars")
   }
   ```

3. Ensure `generateResponseWithAppContext()` correctly passes `useThinking` flag through the call chain.

## Issue 2: Conversation Tags Too Literal

**Problem**: Tags are being extracted as literal quotes from the conversation (e.g., `"looking good!"`, `"creating a template for my content ideas."`) instead of natural tags like "Helping" or "Planning".

**Root Cause**: The tag generation prompt in `OllamaBridgeService.categorizeConversation()` (line ~1824) and `AIRecallService.generateTagsWithAI()` (line ~1478) may be producing quoted responses, or the parsing is capturing quoted text incorrectly.

**Fix**:

1. In `OllamaBridgeService.categorizeConversation()` (line ~1843-1858):

   - Improve prompt to explicitly forbid quotes and emphasize single words
   - Add example format: "Return tags like: Helping, Planning, Creating (no quotes, no periods, just words)"
   - Update parsing to strip quotes if present: `cleaned.replacingOccurrences(of: "\"", with: "")`

2. In `AIRecallService.generateTagsWithAI()` (line ~1499-1514):

   - Strip quotes from parsed tags: `trimmed.replacingOccurrences(of: "\"", with: "")`
   - Remove periods from tags: `trimmed.replacingOccurrences(of: ".", with: "")`
   - Filter out tags that are too long (>20 chars) or contain punctuation

3. Add validation to ensure tags are single words or short phrases (max 2 words, no punctuation except spaces).

## Files to Modify

1. `Cloutmate/Services/OllamaBridgeService.swift`

   - `makeOllamaRequest()` - Filter thinking content based on `useThinking` flag
   - `categorizeConversation()` - Improve prompt and parsing to prevent literal quotes

2. `Cloutmate/Services/AIRecallService.swift`

   - `generateTagsWithAI()` - Improve parsing to strip quotes and validate tags

## Testing

After fixes:

- Verify thinking UI only appears when `useThinking: true`
- Verify tags are natural words/phrases, not literal quotes from conversation
- Check debug logs show correct thinking flag behavior