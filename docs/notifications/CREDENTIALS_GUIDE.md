# Rails Credentials for Platform ntfy - Quick Guide

## TL;DR

**You have per-environment credentials set up correctly!** ✅

In development, Rails reads from:
- `config/credentials/development.yml.enc` (encrypted)
- Decrypted with `config/credentials/development.key`

The shared `config/credentials.yml.enc` is **ignored** in development when per-environment credentials exist.

## File Structure

```
config/
├── credentials.yml.enc          # Shared (used as fallback)
├── master.key                    # Key for shared credentials
└── credentials/
    ├── development.yml.enc       # Development-only ✅ (being used)
    ├── development.key           # Key for development
    ├── production.yml.enc        # Production-only (create when deploying)
    └── production.key            # Key for production
```

## Precedence Rules

Rails uses this order:

1. **First**: `config/credentials/{RAILS_ENV}.yml.enc` (if it exists)
2. **Fallback**: `config/credentials.yml.enc` (if environment-specific doesn't exist)

**Current state (development)**:
- ✅ `development.yml.enc` exists → **Uses this**
- ℹ️ `credentials.yml.enc` exists → **Ignored**

## Why This is Better

### Per-Environment Credentials (What You Have)

```yaml
# config/credentials/development.yml.enc
platform_ntfy:
  topic: pwb-dev-alerts

# config/credentials/production.yml.enc (to create)
platform_ntfy:
  topic: pwb-production-alerts
  access_token: tk_secret_production_token
```

**Advantages**:
- ✅ Different topics per environment
- ✅ Production secrets never on dev machines
- ✅ Easy to manage environment-specific config
- ✅ Can disable in test by not creating test credentials

### Shared Credentials (Alternative)

```yaml
# config/credentials.yml.enc (shared across all environments)
platform_ntfy:
  topic: pwb-platform-alerts  # Same everywhere!
```

**Disadvantages**:
- ❌ Can't have different topics per environment
- ❌ Production key needed on dev machines
- ❌ More security risk

## Editing Credentials

### Development (Current Environment)
```bash
# Opens config/credentials/development.yml.enc
rails credentials:edit --environment development

# Or with your preferred editor
EDITOR="code --wait" rails credentials:edit --environment development
```

### Production (When Deploying)
```bash
# Creates config/credentials/production.yml.enc and production.key
rails credentials:edit --environment production
```

Add:
```yaml
platform_ntfy:
  topic: pwb-production-alerts
  access_token: tk_your_production_token  # Optional
  server_url: https://ntfy.yourcompany.com  # Optional
```

### Shared (Not Recommended for platform_ntfy)
```bash
# Opens config/credentials.yml.enc
rails credentials:edit
```

## Viewing Current Configuration

```bash
# See what Rails sees right now
rails runner "puts Rails.application.credentials.dig(:platform_ntfy, :topic)"
# => pwb-dev-alerts

# Check if enabled
rails runner "puts PlatformNtfyService.enabled?"
# => true
```

## Deployment Strategy

### Development
- ✅ Already configured in `development.yml.enc`
- ✅ `development.key` is gitignored (safe)
- ✅ Topic: `pwb-dev-alerts`

### Staging (If Needed)
```bash
rails credentials:edit --environment staging
```

```yaml
platform_ntfy:
  topic: pwb-staging-alerts
```

### Production
```bash
rails credentials:edit --environment production
```

```yaml
platform_ntfy:
  topic: pwb-production-alerts
  access_token: tk_your_secret_token
```

**Important**: 
- Keep `config/credentials/production.key` secure!
- Add it to your deployment secrets manager
- Never commit it to git (already in .gitignore)

## Testing

### Test Environment
You have two options:

**Option 1: Disable in tests (Recommended)**
- Don't create `test.yml.enc`
- Tests run faster, no external dependencies
- Current specs mock the service anyway ✅

**Option 2: Enable with test credentials**
```bash
rails credentials:edit --environment test
```

```yaml
platform_ntfy:
  topic: pwb-test-alerts
```

## Security Notes

### Keys (.key files)
- ✅ Already in `.gitignore`
- ✅ Never commit to git
- ⚠️ Back them up securely (password manager, secrets manager)
- ⚠️ Share production keys only with authorized team members

### Encrypted Files (.yml.enc)
- ✅ Safe to commit to git (they're encrypted)
- ✅ Can be in version control
- ℹ️ Useless without the corresponding `.key` file

## Troubleshooting

### "Can't decrypt" errors
```bash
# Make sure the .key file exists
ls config/credentials/development.key

# Make sure it has the correct permissions
chmod 600 config/credentials/development.key
```

### Check which file is being used
```bash
rails runner "
if File.exist?('config/credentials/#{Rails.env}.yml.enc')
  puts 'Using: config/credentials/#{Rails.env}.yml.enc'
else
  puts 'Using: config/credentials.yml.enc (fallback)'
end
"
```

### Platform ntfy not working
```bash
# Check credentials are set
rails runner "
creds = Rails.application.credentials
puts 'Topic: ' + (creds.dig(:platform_ntfy, :topic) || 'NOT SET').to_s
puts 'Enabled: ' + PlatformNtfyService.enabled?.to_s
"
```

## Quick Reference

| File | Used When | Key File | Current State |
|------|-----------|----------|---------------|
| `credentials.yml.enc` | Fallback only | `master.key` | ✅ Exists (fallback) |
| `credentials/development.yml.enc` | Development | `credentials/development.key` | ✅ Exists & Active |
| `credentials/production.yml.enc` | Production | `credentials/production.key` | ❌ Create before deploy |
| `credentials/test.yml.enc` | Test | `credentials/test.key` | ❌ Optional (not created) |

---

**Current Status**: ✅ Development credentials configured and working!

Your platform ntfy setup is using per-environment credentials correctly. When you deploy to production, just create the production credentials file with the appropriate topic and access token.
