<!-- 440f2509-8729-493b-8c73-df75d5683bb8 633db2d9-bb2a-48b5-8d2e-9aaa890fe295 -->
# Prevent Duplicate Accounts & Smart Re-authentication

## Goals

1. Prevent users from connecting multiple instances of the same account
2. Cache OAuth tokens so "Change" doesn't require re-authentication
3. Hide already-connected pages from selection list

## Implementation

### 1. Check for Existing Connections

Before starting OAuth flow, check if platform is already connected:

```swift
private func authenticatePlatform(_ platform: Platform) {
    // Check if already connected
    let descriptor = FetchDescriptor<PlatformAccount>(
        predicate: #Predicate { $0.platform == platform.rawValue }
    )
    
    if let existingAccount = try? modelContext.fetch(descriptor).first {
        // For Facebook, show page selection immediately
        if platform == .facebook, let token = getUserAccessToken() {
            Task {
                let pages = try await MetaAPIService.shared.getFacebookPages(accessToken: token)
                // Filter out already connected pages
                let availablePages = pages.data.filter { page in
                    page.id != existingAccount.accountID
                }
                pendingFacebookPages = availablePages
            }
            return
        }
    }
    
    // Otherwise, proceed with OAuth
    isAuthenticating = true
    Task { await performOAuth(platform) }
}
```

### 2. Cache User Access Token

Store the user-level access token (not page token) in Keychain:

**In `authenticatePlatform` after token exchange:**

```swift
// Store user access token for future use
KeychainService.shared.store(
    key: "facebook_user_access_token",
    value: tokenResponse.accessToken
)
```

**Helper function:**

```swift
private func getUserAccessToken() -> String? {
    return KeychainService.shared.retrieve(key: "facebook_user_access_token")
}
```

### 3. Filter Connected Pages

When showing page selection, exclude already-connected pages:

```swift
// After fetching pages
let connectedPageIDs = getConnectedFacebookPageIDs()
let availablePages = pagesResponse.data.filter { page in
    !connectedPageIDs.contains(page.id)
}

if availablePages.isEmpty {
    // Show message: "All your pages are already connected"
    return
}

pendingFacebookPages = availablePages
```

**Helper function:**

```swift
private func getConnectedFacebookPageIDs() -> Set<String> {
    let descriptor = FetchDescriptor<PlatformAccount>(
        predicate: #Predicate { $0.platform == "facebook" }
    )
    let accounts = (try? modelContext.fetch(descriptor)) ?? []
    return Set(accounts.map { $0.accountID })
}
```

### 4. Handle "Change" Button

Update the Change button to use cached token:

```swift
Button("Change") {
    if let token = getUserAccessToken() {
        Task {
            let pages = try await MetaAPIService.shared.getFacebookPages(accessToken: token)
            let connectedIDs = getConnectedFacebookPageIDs()
            pendingFacebookPages = pages.data.filter { !connectedIDs.contains($0.id) }
        }
    } else {
        // Token expired, do OAuth
        authenticatePlatform(.facebook)
    }
}
```

### 5. Prevent Duplicate Page Connections

In `connectSelectedPage`, verify page isn't already connected:

```swift
private func connectSelectedPage(_ page: FacebookPagesResponse.FacebookPage) async {
    do {
        // Check if already connected
        let descriptor = FetchDescriptor<PlatformAccount>(
            predicate: #Predicate { $0.platform == "facebook" && $0.accountID == page.id }
        )
        
        if (try? modelContext.fetch(descriptor).first) != nil {
            Logger.accounts.info("Page already connected: \(page.name)")
            pendingFacebookPages = nil
            return
        }
        
        // Continue with connection...
    }
}
```

## UX Polish

### Inline "All Connected" Message
When all pages are connected, show subtle inline message:
```swift
if availablePages.isEmpty && !allPages.isEmpty {
    HStack(spacing: 8) {
        Image(systemName: "checkmark.circle")
            .foregroundColor(.secondary)
        Text("All pages already connected — nothing to add.")
            .foregroundColor(.secondary)
            .font(.body)
    }
    .padding()
    .transition(.opacity)
}
```

### Fade Transition for Page Switching
Add gentle fade when connected card updates:
```swift
// In connected card
.transition(.opacity)
.animation(.easeInOut(duration: 0.25), value: account.accountID)
```

### Token Caching with Timestamp
Store token with expiration tracking:
```swift
struct CachedToken: Codable {
    let token: String
    let timestamp: Date
    
    var isExpired: Bool {
        // Facebook tokens typically last 60 days
        Date().timeIntervalSince(timestamp) > (60 * 24 * 60 * 60)
    }
}

// Store
let cached = CachedToken(token: accessToken, timestamp: Date())
KeychainService.shared.store(
    key: "facebook_user_token_data",
    value: try? JSONEncoder().encode(cached)
)

// Retrieve
if let data = KeychainService.shared.retrieve(key: "facebook_user_token_data"),
   let cached = try? JSONDecoder().decode(CachedToken.self, from: data),
   !cached.isExpired {
    return cached.token
}
```

## Edge Cases

- **All pages connected**: Show subtle inline message (not alert)
- **Expired cached token**: Fall back to OAuth gracefully
- **Switching pages**: Fade transition for smooth visual update
- **First connection**: Normal OAuth flow with animations

## Key Files

- `Cloutmate/Views/Settings/AccountsSection.swift` - Main implementation
- `Cloutmate/Services/KeychainService.swift` - Token caching

## Benefits

- No duplicate connections
- Smoother UX when changing pages
- Clear visual feedback on what's available
- Respects user's previous authentication

### To-dos

- [ ] Store user-level access token in Keychain after OAuth
- [ ] Check for existing platform connections before OAuth
- [ ] Filter out already-connected pages from selection
- [ ] Update Change button to use cached token
- [ ] Add duplicate check in connectSelectedPage
- [ ] Show message when all pages are connected