# External Feeds Administration

This document describes the site admin interface for configuring external property feeds.

## Overview

External feeds allow website administrators to display property listings from third-party sources (like Resales Online) without storing them locally. Properties are fetched in real-time from the provider's API and cached for performance.

## Accessing the Settings

Navigate to `/site_admin/external_feed` to access the external feed configuration page.

## Configuration Options

### Enable/Disable

Toggle external feeds on or off for your website. When disabled, external listing pages will redirect users to the home page.

### Provider Selection

Select from available feed providers:

- **Resales Online** - Spanish property market (Costa del Sol and other regions)

### Provider-Specific Settings

Each provider requires specific configuration:

#### Resales Online

| Field | Required | Description |
|-------|----------|-------------|
| API Key | Yes | Your Resales Online API key |
| API ID (Sales) | Yes | API ID for sales listings |
| API ID (Rentals) | No | API ID for rental listings (uses Sales ID if not set) |
| P1 Constant | No | P1 constant for API calls (uses default if not set) |

## Actions

### Test Connection

Click "Test Connection" to verify your credentials are working. This performs a simple search query and reports:
- Success: Shows the total number of properties available
- Failure: Shows the error message from the provider

### Clear Cache

Click "Clear Cache" to invalidate all cached feed data. Use this when:
- You've updated provider credentials
- You want to fetch fresh data immediately
- You're troubleshooting display issues

### View External Listings

Opens the external listings page in a new tab to preview how properties appear on your website.

## Troubleshooting

### "Provider is not available"

This usually means:
- API credentials are incorrect
- The provider's API is temporarily down
- Network connectivity issues

Try testing the connection again or verify your credentials with the provider.

### Properties not updating

External feed data is cached to improve performance. Click "Clear Cache" to force a refresh.

### Missing properties

Check that:
- Your API IDs match the property types you want to display
- The provider has properties matching your region/settings

## Security Notes

- API keys are stored securely and displayed as masked values (••••••••••••)
- When updating settings, leave password fields unchanged to preserve existing values
- Only website administrators can access these settings

## Related Documentation

- [External Feed Integration](../architecture/external_feed_integration.md) - Technical architecture
- [Resales Online Provider](../architecture/resales_online_provider.md) - Provider-specific details
