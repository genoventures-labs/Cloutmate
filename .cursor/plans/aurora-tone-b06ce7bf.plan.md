<!-- b06ce7bf-23a1-41a3-a92b-175c7ed6ec46 2a7269b8-6833-4847-9927-239c628c0480 -->
# Aurora Image Analysis Integration

## Overview

Enable Aurora to receive, analyze, and remember images from users. Images can be attached via button or pasted from clipboard. Analysis results are stored in the recall system and can be referenced in future conversations.

## Implementation Steps

### 1. Extend AIMessage Model for Images
**File**: `Cloutmate/Models/AIMessage.swift`

Add image support to AIMessage:
```swift
@Attribute var imageData: Data?           // Store actual image bytes
@Attribute var imageMimeType: String?     // image/png, image/jpeg, etc.
@Attribute var imageAnalysis: String?     // Aurora's analysis of the image
@Attribute var imageFileName: String?     // Original filename if available
```

Update initializer to accept optional image parameters.

### 2. Create Image Attachment Service
**File**: `Cloutmate/Services/ImageAttachmentService.swift` (NEW)

Create a service to handle image operations:
- Load images from file picker
- Handle clipboard paste (NSPasteboard)
- Validate image format (PNG, JPEG, WEBP, HEIC, HEIF per Gemini docs)
- Resize/compress if needed (keep under 20MB for inline data)
- Convert to Base64 for Gemini API

```swift
actor ImageAttachmentService {
    static let shared = ImageAttachmentService()
    
    struct ImageAttachment: Sendable {
        let data: Data
        let mimeType: String
        let fileName: String?
    }
    
    func loadFromFilePicker() async throws -> ImageAttachment
    func loadFromClipboard() -> ImageAttachment?
    func validateAndPrepare(_ image: NSImage) throws -> ImageAttachment
}
```

### 3. Update GeminiService for Image Analysis
**File**: `Cloutmate/Services/GeminiService.swift`

Add method to send images with text prompts:
```swift
func analyzeImage(
    imageData: Data,
    mimeType: String,
    userPrompt: String?,
    appContext: String,
    payloadContext: AIPayloadContext?,
    conversationMessages: [ModelContent]?
) async throws -> String
```

Implementation:
- Convert image data to Base64
- Build multimodal request using `Part.from_bytes()` pattern from docs
- Include Aurora's personality context + image analysis instructions
- Send to `gemini-2.5-flash` (supports enhanced object detection/segmentation)
- Return analysis text

Update system prompt when images are present:
- Add instruction: "When analyzing images, be descriptive but conversational. Extract key information that might be useful later (objects, text, context). Store insights naturally."
- Maintain Aurora's intimate friend personality while being analytical

### 4. Store Image Analysis in Recall System
**File**: `Cloutmate/Services/AIRecallService.swift`

Extend recall to handle image messages:
- When an image message is processed, create RecallIndexEntry
- Title: "Image: [brief description]"
- Detail: Full analysis from Gemini
- Keywords: Extract objects/concepts from analysis
- Emotional context: User's accompanying message emotion

### 5. Update AIAssistantViewModel for Image Messages
**File**: `Cloutmate/ViewModels/AIAssistantViewModel.swift`

Add image handling:
```swift
@Published var pendingImage: ImageAttachment?

func attachImage(_ image: ImageAttachment) async {
    pendingImage = image
}

func sendMessage(_ text: String, modelContext: ModelContext, image: ImageAttachment? = nil) async {
    // ... existing code ...
    
    if let image = image {
        // Create user message with image
        let userMessage = AIMessage(
            role: "user",
            content: text,
            imageData: image.data,
            imageMimeType: image.mimeType,
            imageFileName: image.fileName
        )
        
        // Send to Gemini for analysis
        let analysis = try await geminiService.analyzeImage(
            imageData: image.data,
            mimeType: image.mimeType,
            userPrompt: text.isEmpty ? nil : text,
            appContext: appContext,
            payloadContext: payloadContext,
            conversationMessages: conversationMessages
        )
        
        // Store analysis in message
        userMessage.imageAnalysis = analysis
        
        // Create recall entry for image
        AIRecallService.shared.indexImageAnalysis(
            userMessage: userMessage,
            analysis: analysis,
            modelContext: modelContext
        )
        
        // Send Aurora's response
        let assistantMessage = AIMessage(
            role: "assistant",
            content: analysis
        )
        
        // ... save messages ...
    }
}
```

### 6. Update UI - Add Attach Button
**File**: `Cloutmate/Views/AIAssistant/AIAssistantView.swift`

In `inputArea`, add image attachment button before send button:

```swift
HStack(spacing: 12) {
    // Image attachment button
    Button(action: {
        Task {
            await attachImageFromPicker()
        }
    }) {
        Image(systemName: pendingImagePreview != nil ? "photo.fill" : "photo")
            .foregroundColor(.kosmicBlue)
    }
    .buttonStyle(.plain)
    .help("Attach image")
    .disabled(isRecording)
    
    // Existing text editor...
    ZStack(alignment: .topLeading) {
        ChatTextEditor(...)
        ...
    }
    
    // Send button
    Button(action: { sendCurrentMessage(...) }) {
        ...
    }
}

// Add image preview above input if image is attached
if let preview = pendingImagePreview {
    HStack {
        Image(nsImage: preview)
            .resizable()
            .scaledToFit()
            .frame(height: 80)
            .cornerRadius(8)
        
        Text(pendingImageFileName ?? "Image")
            .font(.caption)
        
        Spacer()
        
        Button(action: { clearPendingImage() }) {
            Image(systemName: "xmark.circle.fill")
        }
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
}
```

Add state variables:
```swift
@State private var pendingImagePreview: NSImage?
@State private var pendingImageFileName: String?
```

### 7. Add Clipboard Paste Support
**File**: `Cloutmate/Views/AIAssistant/AIAssistantView.swift`

Update ChatTextEditor coordinator to handle paste:
```swift
func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(NSStandardKeyBindingResponding.paste(_:)) {
        // Check if clipboard has image
        if let image = ImageAttachmentService.shared.loadFromClipboard() {
            Task {
                await parent.viewModel.attachImage(image)
            }
            return true
        }
    }
    return false
}
```

### 8. Display Images in Message Bubbles
**File**: `Cloutmate/Views/AIAssistant/Components/MessageBubble.swift` or inline in AIAssistantView

Update message display to show images:
```swift
VStack(alignment: message.role == "user" ? .trailing : .leading) {
    // Show image if present
    if let imageData = message.imageData,
       let nsImage = NSImage(data: imageData) {
        Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 300, maxHeight: 300)
            .cornerRadius(8)
            .padding(.bottom, 4)
    }
    
    // Show text content
    if let content = message.content, !content.isEmpty {
        Text(content)
    }
    
    // Show analysis for user messages with images
    if message.role == "user",
       let analysis = message.imageAnalysis,
       !analysis.isEmpty {
        Text("Aurora analyzed: \(analysis)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }
}
```

### 9. Update System Prompt for Image Context
**File**: `Cloutmate/Services/GeminiService.swift`

When images are present, enhance system prompt:
```swift
let imageInstructions = """

**Image Analysis:**
- When users share images, analyze them thoroughly but conversationally
- Extract key information: objects, text, people, setting, mood, colors, composition
- Be specific but natural ("I see a wooden desk with a laptop and coffee mug" not "detected: desk, laptop, mug")
- If the user asks a question about the image, answer directly
- If no specific question, provide helpful context about what you see
- Note any text in images (signs, documents, etc.) for recall
- The image analysis will be stored in your recall system for future reference
"""
```

## Files to Create
1. `Cloutmate/Services/ImageAttachmentService.swift` - New service for image handling

## Files to Modify
1. `Cloutmate/Models/AIMessage.swift` - Add image fields
2. `Cloutmate/Services/GeminiService.swift` - Add image analysis method
3. `Cloutmate/Services/AIRecallService.swift` - Index image analysis
4. `Cloutmate/ViewModels/AIAssistantViewModel.swift` - Handle image messages
5. `Cloutmate/Views/AIAssistant/AIAssistantView.swift` - Add UI for attach button, clipboard paste, image preview, display

## Technical Notes

**Gemini API Image Support** (from documentation):
- Inline data method for files < 20MB total request size
- Supports: PNG, JPEG, WEBP, HEIC, HEIF
- Token cost: 258 tokens if both dimensions <= 384px, larger images tiled at 768x768 per tile
- Use `gemini-2.5-flash` for enhanced object detection and segmentation
- Pass images as Base64 in `inlineData` with `mimeType`

**Aurora's Personality with Images**:
- Maintain casual, intimate friend tone
- React naturally to image content ("oh that's cool", "love the lighting here")
- Use energy mirror (if image is exciting, match that)
- Store useful details for later recall
- Be curious and ask follow-ups if appropriate

## Testing Checklist
- [ ] Attach PNG image via button → Aurora analyzes
- [ ] Attach JPEG image via button → Aurora analyzes
- [ ] Paste image from clipboard → Aurora analyzes
- [ ] Send image with text prompt → Aurora responds to both
- [ ] Send image without text → Aurora describes it
- [ ] View image in message history
- [ ] Recall system stores image analysis
- [ ] Aurora references image from earlier in conversation
- [ ] Handle invalid image format gracefully
- [ ] Handle oversized images (resize/compress)

## Example User Flow

1. User clicks photo button or pastes image
2. Image preview appears above input
3. User types "What's in this image?" (or leaves blank)
4. User clicks send
5. Aurora receives image + text
6. Gemini analyzes image
7. Aurora responds: "totally! so I'm seeing a cozy workspace setup here - looks like a wooden desk with a MacBook, one of those minimalist desk lamps, and what might be a succulent plant in the corner. the lighting is super warm and there's this kind of focused-but-relaxed vibe to it. are you setting up a new workspace or just sharing your current setup?"
8. Image + analysis stored in recall
9. Later, user asks "remember that desk photo?"
10. Aurora recalls: "yeah! that was the wooden desk setup with the MacBook and the warm lighting, right?"

### To-dos

- [x] Add intent cluster extraction method to ConversationArchive
- [x] Add intentClusters field to AIPayloadContext
- [x] Integrate intent clusters into payload building in AIAssistantViewModel
- [x] Format intent clusters in formatPayloadContext
- [x] Update Aurora's system prompt to use intent clusters for predictions
- [x] Create StyleAnalyzer service to extract typing style features from text
- [x] Add style profile fields to UserPreferences model
- [x] Integrate style analysis into AIAssistantViewModel.sendMessage
- [x] Create StyleAdapter to generate style instructions for system prompt
- [x] Modify GeminiService to accept and inject style instructions
- [x] Connect all components in processMessage to pass style data through
- [x] Create StyleAnalyzer service to extract typing style features from text
- [x] Add style profile fields to UserPreferences model
- [x] Integrate style analysis into AIAssistantViewModel.sendMessage
- [x] Create StyleAdapter to generate style instructions for system prompt
- [x] Modify GeminiService to accept and inject style instructions
- [x] Connect all components in processMessage to pass style data through
- [x] Add Energy Mirror Layer
- [x] Add Emotional State Breadcrumbs
- [x] Add Emotional Continuity Cool-Down
- [x] Add Re-Formalization Thresholds
- [x] Enhance Style Adapter Instructions