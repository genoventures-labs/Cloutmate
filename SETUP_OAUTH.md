# OAuth Setup Instructions

## Current Issue
Meta requires HTTPS URLs for OAuth redirects, but localhost doesn't work.

## Option 1: Use ngrok (Recommended for Development)

1. Install ngrok:
   ```bash
   brew install ngrok
   ```

2. Get a free ngrok account at https://ngrok.com

3. Start ngrok tunnel:
   ```bash
   ngrok http 8080
   ```

4. You'll get a URL like: `https://abc123.ngrok.io`

5. Update Info.plist redirect URI to: `https://abc123.ngrok.io/oauth/callback`

6. Add `https://abc123.ngrok.io/oauth/callback` to Meta App Dashboard

## Option 2: Use Meta's Device Flow

This is a different OAuth flow designed for devices that can't display a browser.

## Temporary Solution

I've set the redirect URI to `https://oauth.cloutmate.app/callback`. You need to:

1. Add this URL to Meta App Dashboard
2. Set up a web server at that domain that redirects to your app

This is the most complex but proper solution for production.

