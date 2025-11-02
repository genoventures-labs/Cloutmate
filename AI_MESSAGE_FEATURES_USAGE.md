# AI Message Features - User Guide

## Feature 1: Edit User Messages

### How to Edit a Message

1. **Hover over your message** (user messages are on the right with blue/purple gradient)
2. **Click the pencil icon** that appears on the left side of your message
3. **Edit your message** in the text editor that appears
4. **Click "Submit"** to send the edited message and regenerate AI response
   - OR click **"Cancel"** to discard changes

### What Happens When You Edit?

- Your message content is updated
- All AI responses after that message are deleted
- The AI generates a new response based on your edited message
- The conversation continues from that edited point

### Example Use Case

```
You: "Help me write a caption for Instagram about coffee"
AI: "Here's a caption about coffee..."

[You realize you wanted Facebook, not Instagram]

You: [Edit] "Help me write a caption for Facebook about coffee"
AI: [NEW RESPONSE] "Here's a caption optimized for Facebook..."
```

---

## Feature 2: Copy AI Messages

### How to Copy an AI Response

1. **Hover over the AI message** (AI messages are on the left with glass material)
2. **Click the document icon** (copy button) that appears on the right side
3. **See the "Copied!" toast** notification confirming the copy
4. **Paste anywhere** - the message is now on your clipboard!

### Quick Tips

- ✅ All AI message text is also **manually selectable** if you prefer
- ✅ The copy button copies the **entire message content**
- ✅ The "Copied!" toast auto-dismisses after 2 seconds
- ✅ Works with messages of any length

### Example Use Case

```
AI: "Here's your optimized caption:

☕ Morning vibes hit different when you've got the perfect brew...
#CoffeeLover #MorningRoutine"

[Click copy button]
[Toast: "Copied!"]
[Paste into your social media composer]
```

---

## Visual Guide

### User Message (Hover State)
```
┌─────────────────────────────────┐
│ [✏️]  Your message here...       │ ← Edit button appears on hover
│       [Blue/Purple Gradient]     │   (left side for user messages)
│       12:34 PM                   │
└─────────────────────────────────┘
```

### User Message (Edit Mode)
```
┌─────────────────────────────────┐
│ ╔═══════════════════════════╗  │
│ ║ Edit your message here... ║  │ ← TextEditor with blue border
│ ║                           ║  │
│ ╚═══════════════════════════╝  │
│              [Cancel] [Submit]  │
└─────────────────────────────────┘
```

### AI Message (Hover State)
```
┌─────────────────────────────────┐
│ AI response text here...    📋  │ ← Copy button appears on hover
│ [Glass Material Background]     │   (right side for AI messages)
│ 12:34 PM                        │
└─────────────────────────────────┘
```

### Copy Confirmation
```
     ┌──────────────┐
     │ ✓ Copied!    │ ← Toast notification
     └──────────────┘
     (Auto-dismisses)
```

---

## Keyboard Shortcuts

While editing a message:
- **Enter**: New line in editor
- **Cmd + Enter**: Could be added for quick submit (not currently implemented)
- **Escape**: Could be added to cancel (not currently implemented)

---

## Technical Notes

### Message Selection
- All messages support text selection for manual copying
- User messages: White text on gradient
- AI messages: Primary color text on glass material

### Message Icons
- ✏️ **Pencil icon**: Edit user message
- 📋 **Document icon**: Copy AI message
- ✓ **Checkmark**: Copy confirmed

### Hover Behavior
- Buttons appear on hover only (clean interface)
- System messages don't show action buttons
- Edit mode disables hover buttons temporarily

---

## Troubleshooting

### Edit button not appearing?
- Make sure you're hovering over a **user message** (not AI message)
- System messages cannot be edited

### Copy button not appearing?
- Make sure you're hovering over an **AI message** (not user message)
- System messages cannot be copied

### Edit not regenerating AI response?
- Check that AI features are enabled in Settings
- Verify your API key is configured
- Check internet connection

### Copy not working?
- The text is copied to your macOS clipboard
- Try pasting in a text editor to verify
- Check clipboard permissions if needed

