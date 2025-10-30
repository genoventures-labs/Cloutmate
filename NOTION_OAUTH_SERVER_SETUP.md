# Notion OAuth Server Setup

## Server Updates Required

Your server needs to extract the platform from the `state` parameter for Notion OAuth callbacks.

### Current Server Code
```javascript
export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get("code");
  const state = searchParams.get("state");
  const platform = searchParams.get("platform"); // This won't exist for Notion

  let redirect;
  switch (platform) {
    case "notion":
      redirect = `cloutmate://oauth/notion?code=${code || ""}&state=${state || ""}`;
      break;
    // ...
  }
  return new Response(null, { status: 302, headers: { Location: redirect } });
}
```

### Updated Server Code
```javascript
export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get("code");
  const state = searchParams.get("state");
  let platform = searchParams.get("platform");

  // Extract platform from state if not provided directly
  // Format: "platform:cloutmate_platform_abc123"
  if (!platform && state) {
    const stateMatch = state.match(/^([^:]+):/);
    if (stateMatch) {
      platform = stateMatch[1];
    }
  }

  let redirect;
  switch (platform) {
    case "notion":
      redirect = `cloutmate://oauth/notion?code=${code || ""}&state=${state || ""}`;
      break;
    case "threads":
      redirect = `cloutmate://oauth/threads?code=${code || ""}&state=${state || ""}`;
      break;
    case "facebook":
    default:
      redirect = `cloutmate://oauth/facebook?code=${code || ""}&state=${state || ""}`;
      break;
  }

  return new Response(null, { status: 302, headers: { Location: redirect } });
}
```

## Flow

1. App initiates Notion OAuth with state: `notion:cloutmate_notion_abc123`
2. User authorizes on Notion
3. Notion redirects to: `https://oauth.kosmicapps.com/auth/callback?code=abc&state=notion:cloutmate_notion_abc123`
4. Your server extracts `platform = "notion"` from state prefix
5. Your server redirects to: `cloutmate://oauth/notion?code=abc&state=notion:cloutmate_notion_abc123`
6. App receives callback and processes

## State Parameter Format

- Notion: `notion:cloutmate_notion_abc123`
- Threads: `threads:cloutmate_threads_abc123`  
- Facebook: `facebook:cloutmate_facebook_abc123`

The first part before the colon (`:`) is the platform identifier.

