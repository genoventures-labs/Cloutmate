# Production OAuth Callback Server

## Architecture

```
User → Facebook OAuth → https://oauth.cloutmate.app/auth/callback → cloutmate://oauth/callback → Your App
```

## Implementation Required

You need to set up a web server at `https://oauth.cloutmate.app` that:

1. Receives OAuth callbacks from Meta at `/auth/callback`
2. Extracts the `code` parameter from the query string
3. Redirects to your app's custom URL scheme: `cloutmate://oauth/callback?code=XXX`

## Simple Node.js Implementation

```javascript
// server.js
const express = require('express');
const app = express();

app.get('/auth/callback', (req, res) => {
  const code = req.query.code;
  const error = req.query.error;
  
  if (error) {
    // Redirect with error
    res.redirect(`cloutmate://oauth/callback?error=${encodeURIComponent(error)}`);
  } else if (code) {
    // Redirect with code
    res.redirect(`cloutmate://oauth/callback?code=${code}`);
  } else {
    res.status(400).send('Missing code parameter');
  }
});

app.listen(3000, () => {
  console.log('OAuth callback server running on port 3000');
});
```

## Deployment

1. Register domain: `oauth.cloutmate.app`
2. Get SSL certificate (Let's Encrypt)
3. Deploy Node.js server
4. Configure DNS

## Alternative: Use a Service

Services like:
- Auth0
- Cloudflare Workers
- AWS Lambda + API Gateway
- Netlify Functions

Can handle this redirect in a few lines of code.

## Meta App Dashboard Configuration

Add to "Valid OAuth Redirect URIs":
- `https://oauth.cloutmate.app/auth/callback`

Enable:
- Client OAuth login: ON
- Web OAuth login: ON
- Enforce HTTPS: ON
- Use Strict Mode: ON

