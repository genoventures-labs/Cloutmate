<!-- a1065412-7307-4c18-9513-12bae8b6bd03 81252935-2f41-4eaf-a16f-cd13fb582329 -->
# Make AI Completely Intelligent About Conversation Context

## Problems Identified

1. `GeminiService.conversationHistory` is global - shared across ALL conversations
2. Messages are stored as `AIMessage[]` but Gemini needs `ModelContent[]` format
3. No conversion between formats when loading conversation messages
4. AI can't reference previous messages because it's using global history instead of conversation-specific messages

## Solution

### 1. Create Message Conversion Helper in GeminiService

- Add function to convert `[AIMessage]` → `[ModelContent]` for Gemini API
- Format: `ModelContent(role: "user"/"model", parts: [.text(content)])`
- Handle role conversion: "assistant" → "model"

### 2. Update generateResponseWithAppContext Signature

- Change from using global `conversationHistory.suffix(10)`
- Add parameter: `conversationMessages: [ModelContent]?` 
- Use passed messages instead of global history
- Increase context to last 20-30 messages for better conversation awareness

### 3. Update AIAssistantViewModel to Pass Conversation Messages

- In `processMessage()`: Convert `messages: [AIMessage]` to `[ModelContent]`
- Pass the converted messages to `generateResponseWithAppContext`
- Include full conversation context, not just global singleton

### 4. Enhance System Prompt for Conversation Awareness

- Add explicit instruction: "You can reference any previous message in this conversation"
- Add: "Answer questions about what was discussed earlier using the conversation history"
- Add: "Be aware of context from previous exchanges"
- Add: "If the user asks about something mentioned earlier, reference it specifically"

### 5. Remove Global History Dependencies

- Don't update global `conversationHistory` in `generateResponseWithAppContext`
- Let each conversation maintain its own isolated history
- Keep global history only for tools that need it

## Additional Considerations

- **Memory**: Increase from 10 to 30 messages for better context
- **Format Conversion**: Handle `role` field ("assistant" vs "model")
- **Persistent History**: Messages are stored in database, so history persists across app restarts
- **Thread Safety**: Current `actor` design ensures thread safety

## Files to Modify

1. `FocusOS/Services/GeminiService.swift` - Add conversion helper, update signature
2. `FocusOS/ViewModels/AIAssistantViewModel.swift` - Convert and pass messages

### To-dos

- [ ] Create helper function to convert AIMessage[] to ModelContent[] in GeminiService
- [ ] Update generateResponseWithAppContext to accept conversationMessages parameter instead of using global history
- [ ] Update AIAssistantViewModel to convert and pass current conversation messages to GeminiService
- [ ] Increase conversation context from 10 to 30 messages for better awareness
- [ ] Enhance system prompt to explicitly instruct AI to reference conversation history when answering questions