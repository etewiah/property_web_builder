# Client Rendering Implementation Status

**Last Updated**: 2026-01-15
**Status**: Core Implementation Complete

---

## Overview

PropertyWebBuilder now supports two mutually exclusive rendering modes:

| Mode | Description | Themes |
|------|-------------|--------|
| `rails` | Server-side rendering with Liquid templates | Barcelona, Bologna, Brisbane, Brussels, Biarritz |
| `client` | Client-side rendering with Astro JavaScript app | Amsterdam, Athens, Austin |

A website chooses ONE mode at deployment time. This decision becomes permanent after content is created.

---

## Implementation Checklist

### Phase 1: Database Schema ✅ Complete

| File | Description |
|------|-------------|
| `db/migrate/20260115140000_add_rendering_mode_to_websites.rb` | Adds `rendering_mode`, `client_theme_name`, `client_theme_config` to websites |
| `db/migrate/20260115140001_create_pwb_client_themes.rb` | Creates `pwb_client_themes` table |

**Schema columns added to `pwb_websites`:**
- `rendering_mode` (string, default: 'rails', not null)
- `client_theme_name` (string)
- `client_theme_config` (jsonb, default: {})

**New table `pwb_client_themes`:**
- `name` (string, unique, not null)
- `friendly_name` (string, not null)
- `version` (string, default: '1.0.0')
- `description` (text)
- `preview_image_url` (string)
- `default_config` (jsonb)
- `color_schema` (jsonb)
- `font_schema` (jsonb)
- `layout_options` (jsonb)
- `enabled` (boolean, default: true)

---

### Phase 2: Models ✅ Complete

| File | Description |
|------|-------------|
| `app/models/pwb/client_theme.rb` | ClientTheme model with validation, scopes, API serialization |
| `app/models/concerns/pwb/website_rendering_mode.rb` | Concern for rendering mode logic |

**Key methods in WebsiteRenderingMode:**
- `rails_rendering?` / `client_rendering?` - Check current mode
- `client_theme` - Get associated ClientTheme object
- `effective_client_theme_config` - Merged config (defaults + overrides)
- `client_theme_css_variables` - Generate CSS variables string
- `rendering_mode_locked?` - Check if mode can still be changed
- `rendering_mode_changeable?` - Inverse of locked

**Validations:**
- `rendering_mode` must be 'rails' or 'client'
- `client_theme_name` required when `rendering_mode == 'client'`
- Client theme must exist and be enabled
- `rendering_mode` immutable after website has content

---

### Phase 3: Reverse Proxy Controller ✅ Complete

| File | Description |
|------|-------------|
| `app/controllers/pwb/client_proxy_controller.rb` | Proxies requests to Astro client |
| `app/views/pwb/errors/proxy_unavailable.html.erb` | Error page when Astro unavailable |

**Features:**
- Proxies public pages via `public_proxy` action
- Proxies admin pages via `admin_proxy` action (requires authentication)
- Generates JWT tokens for Astro to verify authenticity
- Forwards relevant headers (website ID, slug, theme, user info)
- Handles errors gracefully with styled error page

**Headers sent to Astro:**
- `X-Forwarded-Host`, `X-Forwarded-Proto`, `X-Forwarded-For`
- `X-Website-Slug`, `X-Website-Id`
- `X-Rendering-Mode`, `X-Client-Theme`
- `X-User-Id`, `X-User-Email`, `X-User-Role` (admin routes only)
- `X-Auth-Token` (JWT, admin routes only)

---

### Phase 4: Routing Configuration ✅ Complete

| File | Description |
|------|-------------|
| `app/constraints/client_rendering_constraint.rb` | Determines if request should go to Astro |
| `config/routes.rb` | Routes with constraint for client proxy |

**Routing logic:**
1. Request comes in
2. `ClientRenderingConstraint` checks if website uses client rendering
3. If yes and path not excluded → proxy to Astro
4. If no → normal Rails handling

**Excluded paths (always go to Rails):**
- `/site_admin`, `/tenant_admin`
- `/api`, `/api_public`
- `/users`, `/auth`
- `/rails`, `/assets`, `/packs`
- `/active_storage`, `/cable`
- `/health`, `/setup`, `/signup`
- `/.well-known`

---

### Phase 5: API Endpoints ✅ Complete

| File | Endpoint | Description |
|------|----------|-------------|
| `app/controllers/api_public/v1/client_themes_controller.rb` | `GET /api_public/v1/client-themes` | List all enabled client themes |
| | `GET /api_public/v1/client-themes/:name` | Get specific theme details |
| `app/controllers/api_public/v1/website_client_config_controller.rb` | `GET /api_public/v1/client-config` | Get website's client rendering config |

**Response format for `/api_public/v1/client-config`:**
```json
{
  "data": {
    "rendering_mode": "client",
    "theme": {
      "name": "amsterdam",
      "friendly_name": "Amsterdam Modern",
      "version": "1.0.0",
      "color_schema": {...},
      "font_schema": {...},
      "layout_options": {...}
    },
    "config": {
      "primary_color": "#FF6B35",
      "secondary_color": "#004E89",
      ...
    },
    "css_variables": ":root { --primary-color: #FF6B35; ... }",
    "website": {
      "id": 123,
      "subdomain": "mysite",
      "company_display_name": "My Company",
      "default_locale": "en",
      "supported_locales": ["en", "es"]
    }
  }
}
```

---

### Phase 6: Tenant Admin UI ⚠️ Partial

Rendering mode can be updated via the existing websites controller:

```
PATCH /tenant_admin/websites/:id
```

**What exists:**
- Website model accepts `rendering_mode` and `client_theme_name` params
- Validation prevents changing mode after content exists
- Request spec covers update scenarios

**What's missing:**
- Dedicated `RenderingModeController` with focused UI
- Stimulus controller for form interactivity
- Theme preview functionality

---

### Phase 7: Infrastructure ✅ Complete

| File | Description |
|------|-------------|
| `Gemfile` | Added `http` (~> 5.0) and `jwt` (~> 2.7) gems |

**Environment variable needed:**
```bash
ASTRO_CLIENT_URL=http://localhost:4321  # Default if not set
```

---

### Phase 8: Tests ✅ Complete

| File | Coverage |
|------|----------|
| `spec/models/pwb/client_theme_spec.rb` | ClientTheme validations, scopes, methods |
| `spec/models/concerns/pwb/website_rendering_mode_spec.rb` | Rendering mode concern |
| `spec/controllers/pwb/client_proxy_controller_spec.rb` | Proxy controller actions, JWT generation |
| `spec/controllers/api_public/v1/client_themes_controller_spec.rb` | API endpoints |
| `spec/requests/tenant_admin/website_rendering_mode_spec.rb` | Admin updates |
| `spec/factories/pwb_client_themes.rb` | Factory with traits for each theme |
| `spec/factories/pwb_websites.rb` | Added traits: `:rails_rendering`, `:client_rendering`, `:client_rendering_with_overrides`, `:provisioned_with_content` |

---

### Phase 9: Seed Data ✅ Complete

| File | Description |
|------|-------------|
| `db/seeds/client_themes.rb` | Seeds Amsterdam, Athens, Austin themes |

**Run seeds:**
```bash
rails db:seed:client_themes
# or
rails runner "load Rails.root.join('db/seeds/client_themes.rb')"
```

---

## Known Gaps & Future Improvements

### 1. Dedicated Rendering Mode UI (Low Priority)

Currently rendering mode is set via the general website edit form. A dedicated UI would:
- Make the decision more prominent
- Show theme previews
- Clearly communicate the permanence of the choice

**Files to create:**
- `app/controllers/tenant_admin/rendering_mode_controller.rb`
- `app/views/tenant_admin/rendering_mode/show.html.erb`
- `app/javascript/controllers/rendering_mode_controller.js`

### 2. Theme Preview Images (Medium Priority)

The `preview_image_url` column exists but is not populated. Add:
- Screenshot images for each theme
- Upload to Active Storage or CDN
- Update seed file with URLs

### 3. Authenticated Admin API (If Needed)

If Astro needs to update theme settings (not just read), create:
- `app/controllers/pwb/api/v1/client_theme_settings_controller.rb`
- Routes: `GET/PATCH /api/v1/client-theme-settings`

### 4. Request Spec for Client Config API

Add comprehensive request spec:
- `spec/requests/api_public/v1/website_client_config_spec.rb`

### 5. Infrastructure Files

Create actual config files (currently only documented):
- `config/nginx/propertywebbuilder.conf`
- `docker-compose.client-rendering.yml`

---

## Testing Commands

```bash
# Run all client rendering tests
bundle exec rspec \
  spec/models/pwb/client_theme_spec.rb \
  spec/models/concerns/pwb/website_rendering_mode_spec.rb \
  spec/controllers/pwb/client_proxy_controller_spec.rb \
  spec/controllers/api_public/v1/client_themes_controller_spec.rb \
  spec/requests/tenant_admin/website_rendering_mode_spec.rb

# Seed client themes
rails db:seed:client_themes

# Verify in console
rails console
> Pwb::ClientTheme.count  # Should be 3
> Pwb::ClientTheme.pluck(:name)  # ['amsterdam', 'athens', 'austin']
```

---

## Related Documentation

- [Astro Client Integration Guide](./astro_client_integration_guide.md) - Detailed guide for Astro updates
- [Theme Management Strategy](../claude_thoughts/astro_frontend_theme_management_strategy.md) - Architecture decision document
