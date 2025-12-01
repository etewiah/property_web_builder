# Firebase Authentication Troubleshooting Guide

## The "Invalid token" Error

When you get `{"error": "Invalid token"}`, it means the Firebase token verification failed. Here's how to troubleshoot:

## Quick Checks

### 1. Check Environment Variables

```bash
# In your e2e environment
RAILS_ENV=e2e rails runner "puts ENV['FIREBASE_PROJECT_ID']; puts ENV['FIREBASE_API_KEY']&.length"
```

Expected output:
```
your-project-id
40  # (or similar - API keys are usually 39 chars)
```

### 2. Check Rails Logs

The service now has detailed logging. Check your e2e logs:

```bash
tail -f log/e2e.log | grep -i firebase
```

You should see:
```
FirebaseAuthService: Starting token verification
FirebaseAuthService: Token length: 1234
FirebaseAuthService: Token verified successfully
# OR
FirebaseAuthService: Verification failed - SomeError: detailed message
```

## Common Causes

### 1. **Expired Token**
Firebase ID tokens expire after **1 hour**.

**Solution:** Get a fresh token

### 2. **Wrong Project ID**
The token must be from the same Firebase project as `FIREBASE_PROJECT_ID`.

**How to check:**
1. Decode your token at https://jwt.io
2. Look at the `aud` field (audience)
3. It should match your `FIREBASE_PROJECT_ID`

### 3. **Malformed Token**
The token must be a valid JWT string.

**Valid token format:**
```
eyJhbGciOiJSUzI1NiIsImtpZCI6IjFmOD...  (very long string, ~1000+ chars)
```

### 4. **Missing or Invalid Certificates**
Firebase public keys need to be cached/fetched.

**Check in Rails console:**
```ruby
RAILS_ENV=e2e rails c
FirebaseIdToken::Certificates.request
```

If this fails, check your internet connection and firewall settings.

## Testing Flow

### Step 1: Get a Real Token

Visit the Firebase login page and sign in:
```
http://tenant-b.e2e.localhost:3001/firebase_login
```

Open browser DevTools → Network tab → Look for the POST to `/api_public/v1/auth/firebase`

Copy the `token` value from the request payload.

### Step 2: Test in Rails Console

```ruby
RAILS_ENV=e2e rails c

# Replace with your actual token
token = "eyJhbGciOiJ..."

# Test the service
service = Pwb::FirebaseAuthService.new(token)
result = service.call

# Check result
puts result.inspect
# Should show a User object if successful
# or nil if failed (check logs for details)
```

### Step 3: Test via cURL

```bash
TOKEN="your-token-here"

curl -X POST http://tenant-b.e2e.localhost:3001/api_public/v1/auth/firebase \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}"
```

## Debugging Checklist

- [ ] Environment variables are set (`FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`)
- [ ] E2E server is running with correct environment
- [ ] Token is from the correct Firebase project
- [ ] Token is not expired (< 1 hour old)
- [ ] Token is complete (no truncation)
- [ ] Internet connection is working (for certificate fetching)
- [ ] Redis is running (for certificate caching) - optional but recommended

## Getting the Exact Error

To see the exact error, check the Rails logs while making the request:

### Terminal 1: Watch Logs
```bash
tail -f log/e2e.log
```

### Terminal 2: Make Request
```bash
curl -X POST http://tenant-b.e2e.localhost:3001/api_public/v1/auth/firebase \
  -H "Content-Type: application/json" \
  -d '{"token": "YOUR_TOKEN_HERE"}'
```

The logs will show the detailed error message and stack trace.

## Example: Valid vs Invalid Token

### Valid Token Response
```json
{
  "user": {
    "id": 123,
    "email": "user@example.com",
    "firebase_uid": "abc123..."
  },
  "message": "Logged in successfully"
}
```

### Invalid Token Response
```json
{
  "error": "Invalid token"
}
```

Check logs to see WHY it's invalid.

## Still Having Issues?

If you're still stuck, provide:
1. The logs from `tail -f log/e2e.log` during the request
2. The first 50 characters of your token
3. Your `FIREBASE_PROJECT_ID`

This will help diagnose the specific issue.
