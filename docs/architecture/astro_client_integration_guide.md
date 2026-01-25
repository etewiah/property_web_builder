# Astro Client Integration Guide

**Last Updated**: 2026-01-25
**Audience**: Junior Developers
**Estimated Time**: 4-6 hours

---

## Table of Contents

1. [Background & Context](#background--context)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Step 1: Environment Setup](#step-1-environment-setup)
5. [Step 2: Create Auth Middleware](#step-2-create-auth-middleware)
6. [Step 3: Create API Client](#step-3-create-api-client)
7. [Step 4: Create Theme Configuration Store](#step-4-create-theme-configuration-store)
8. [Step 5: Create Dynamic Theme Layout](#step-5-create-dynamic-theme-layout)
9. [Step 6: Update Base Layout](#step-6-update-base-layout)
10. [Step 7: Create Admin Routes](#step-7-create-admin-routes)
11. [Step 8: Testing Your Implementation](#step-8-testing-your-implementation)
12. [Troubleshooting](#troubleshooting)
13. [Glossary](#glossary)

---

## Background & Context

### What is this about?

PropertyWebBuilder has two ways to render websites:

1. **Rails Mode (B Themes)**: The Rails backend renders HTML using Liquid templates. Themes like Barcelona, Bologna, etc.

2. **Client Mode (A Themes)**: The Astro frontend renders the website using JavaScript. Themes like Amsterdam, Athens, Austin.

When a website is set to "client" mode, the Rails backend acts as a **reverse proxy** - it receives requests and forwards them to the Astro server, which renders the page.

### Why does this matter?

Your Astro app needs to:
1. Know which theme to use (Amsterdam, Athens, or Austin)
2. Get the theme colors, fonts, and other configuration from Rails
3. Verify that requests coming through the proxy are legitimate (authentication)
4. Apply the correct theme styling dynamically

### What you'll build

By the end of this guide, your Astro app will:
- Read authentication headers from the Rails proxy
- Fetch theme configuration from the Rails API
- Dynamically select and apply the correct theme
- Protect admin routes from unauthorized access

---

## Prerequisites

Before starting, make sure you have:

- [ ] Node.js 18+ installed
- [ ] The Astro project cloned and running locally
- [ ] Access to the Rails backend (for API testing)
- [ ] Basic understanding of Astro components and layouts
- [ ] Basic understanding of TypeScript (we'll use it for type safety)

### Install Required Packages

In your Astro project directory, run:

```bash
npm install jsonwebtoken
npm install -D @types/jsonwebtoken
```

---

## Architecture Overview

Here's how requests flow when a website uses client rendering:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER'S BROWSER                                   │
│                                                                          │
│   User visits: https://mysite.propertywebbuilder.com/properties         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         RAILS BACKEND                                    │
│                                                                          │
│   1. Receives request                                                   │
│   2. Checks: Is this website using client rendering? YES                │
│   3. Adds headers:                                                      │
│      - X-Website-Id: 123                                                │
│      - X-Website-Slug: mysite                                           │
│      - X-Client-Theme: amsterdam                                        │
│      - X-Auth-Token: eyJ... (JWT, for admin routes)                    │
│   4. Forwards request to Astro                                          │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         ASTRO CLIENT (Your Code)                        │
│                                                                          │
│   1. Middleware reads headers                                           │
│   2. Fetches theme config from Rails API                                │
│   3. Selects correct theme layout (Amsterdam/Athens/Austin)             │
│   4. Renders page with correct colors/fonts                             │
│   5. Returns HTML to Rails                                              │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER'S BROWSER                                   │
│                                                                          │
│   Receives rendered HTML page with Amsterdam theme                      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Environment Setup

### 1.1 Create Environment Variables File

Create or update `.env` in your Astro project root:

```bash
# .env

# URL of the Rails backend API
# In development, this is your local Rails server
# In production, this might be empty (same domain) or a specific URL
PUBLIC_API_BASE_URL=http://localhost:3000

# Secret key for verifying JWT tokens from Rails
# IMPORTANT: This MUST match Rails.application.secret_key_base
# Ask your team lead for the correct value
PROXY_AUTH_SECRET=your_rails_secret_key_base_here

# Environment
PUBLIC_ENV=development
```

### 1.2 Create Environment Type Definitions

Create `src/env.d.ts` (or update if it exists):

```typescript
// src/env.d.ts

/// <reference types="astro/client" />

interface ImportMetaEnv {
  readonly PUBLIC_API_BASE_URL: string;
  readonly PROXY_AUTH_SECRET: string;
  readonly PUBLIC_ENV: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

**What this does**: TypeScript now knows about your environment variables and will give you autocomplete and type checking.

---

## Step 2: Create Auth Middleware

Middleware runs on every request before your page renders. We'll use it to:
1. Extract authentication info from headers
2. Make it available to all pages

### 2.1 Create the Middleware File

Create `src/middleware/index.ts`:

```typescript
// src/middleware/index.ts

import { defineMiddleware } from 'astro:middleware';
import jwt from 'jsonwebtoken';

/**
 * Shape of the JWT payload sent by Rails
 */
interface AuthPayload {
  user_id: number | null;
  website_id: number | null;
  exp: number;  // Expiration timestamp
  iat: number;  // Issued at timestamp
}

/**
 * User information extracted from auth headers
 */
interface UserInfo {
  id: number | null;
  email: string | null;
  role: string;
  authenticated: boolean;
}

/**
 * Website information from proxy headers
 */
interface WebsiteInfo {
  id: string | null;
  slug: string | null;
  theme: string | null;
  renderingMode: string | null;
}

// Extend Astro's locals type
declare global {
  namespace App {
    interface Locals {
      user: UserInfo;
      website: WebsiteInfo;
    }
  }
}

export const onRequest = defineMiddleware(async ({ request, locals }, next) => {
  // ============================================
  // STEP 1: Extract user info from auth headers
  // ============================================

  const authToken = request.headers.get('X-Auth-Token');

  if (authToken) {
    try {
      // Verify the JWT token using the shared secret
      const secret = import.meta.env.PROXY_AUTH_SECRET;

      if (!secret) {
        console.error('PROXY_AUTH_SECRET not configured!');
        locals.user = createUnauthenticatedUser();
      } else {
        const payload = jwt.verify(authToken, secret) as AuthPayload;

        // Token is valid! Extract user info
        locals.user = {
          id: payload.user_id,
          email: request.headers.get('X-User-Email'),
          role: request.headers.get('X-User-Role') || 'guest',
          authenticated: true
        };

        console.log(`Authenticated user: ${locals.user.email} (${locals.user.role})`);
      }
    } catch (error) {
      // Token verification failed (expired, invalid, etc.)
      console.error('Auth token verification failed:', error);
      locals.user = createUnauthenticatedUser();
    }
  } else {
    // No auth token provided (public route)
    locals.user = createUnauthenticatedUser();
  }

  // ============================================
  // STEP 2: Extract website info from headers
  // ============================================

  locals.website = {
    id: request.headers.get('X-Website-Id'),
    slug: request.headers.get('X-Website-Slug'),
    theme: request.headers.get('X-Client-Theme'),
    renderingMode: request.headers.get('X-Rendering-Mode')
  };

  console.log(`Website: ${locals.website.slug}, Theme: ${locals.website.theme}`);

  // Continue to the page
  return next();
});

/**
 * Helper to create an unauthenticated user object
 */
function createUnauthenticatedUser(): UserInfo {
  return {
    id: null,
    email: null,
    role: 'guest',
    authenticated: false
  };
}
```

### 2.2 Understanding the Code

Let's break down what this middleware does:

1. **JWT Verification**: When Rails proxies a request to `/client-admin/*`, it includes an `X-Auth-Token` header containing a JWT (JSON Web Token). This token is signed with a secret key. We verify the signature to ensure the token wasn't tampered with.

2. **Header Extraction**: Rails adds several `X-*` headers to tell us about the website and user. We extract these and store them in `locals`.

3. **locals**: This is Astro's way of passing data from middleware to pages. Any page can access `Astro.locals.user` and `Astro.locals.website`.

### 2.3 Register the Middleware

Update `astro.config.mjs` to enable middleware:

```javascript
// astro.config.mjs

import { defineConfig } from 'astro/config';

export default defineConfig({
  // ... your existing config ...

  // Enable server-side rendering (required for middleware)
  output: 'server',

  // Or if you want hybrid (some pages static, some dynamic):
  // output: 'hybrid',
});
```

---

## Step 3: Create API Client

We need a way to fetch data from the Rails API. Let's create a reusable API client.

### 3.1 Create Types for API Responses

Create `src/lib/api/types.ts`:

```typescript
// src/lib/api/types.ts

/**
 * Color schema definition from Rails
 * Describes what colors can be customized and their defaults
 */
export interface ColorSchemaItem {
  type: 'color';
  label: string;
  default: string;
}

export interface ColorSchema {
  [key: string]: ColorSchemaItem;
}

/**
 * Font schema definition from Rails
 * Describes what fonts can be customized
 */
export interface FontSchemaItem {
  type: 'select';
  label: string;
  options: string[];
  default: string;
}

export interface FontSchema {
  [key: string]: FontSchemaItem;
}

/**
 * Layout options schema
 */
export interface LayoutOptionsItem {
  type: 'select';
  label: string;
  options: string[];
  default: string;
}

export interface LayoutOptions {
  [key: string]: LayoutOptionsItem;
}

/**
 * Theme data from the API
 */
export interface ThemeData {
  name: string;
  friendly_name: string;
  version: string;
  color_schema: ColorSchema;
  font_schema: FontSchema;
  layout_options: LayoutOptions;
}

/**
 * Theme configuration (actual values being used)
 */
export interface ThemeConfig {
  primary_color: string;
  secondary_color: string;
  accent_color?: string;
  background_color?: string;
  text_color?: string;
  font_heading: string;
  font_body: string;
  [key: string]: string | undefined;  // Allow additional properties
}

/**
 * Website data from the API
 */
export interface WebsiteData {
  id: number;
  subdomain: string;
  company_display_name: string;
  default_locale: string;
  supported_locales: string[];
}

/**
 * Full response from /api_public/v1/client-config
 */
export interface ClientConfigResponse {
  data: {
    rendering_mode: 'client';
    theme: ThemeData | null;
    config: ThemeConfig;
    css_variables: string;
    website: WebsiteData;
  };
}

/**
 * Response from /api_public/v1/client-themes
 */
export interface ClientThemesResponse {
  meta: {
    total: number;
    version: string;
  };
  data: Array<{
    name: string;
    friendly_name: string;
    version: string;
    description: string;
    preview_image_url: string | null;
    default_config: ThemeConfig;
    color_schema: ColorSchema;
    font_schema: FontSchema;
    layout_options: LayoutOptions;
  }>;
}
```

### 3.2 Create the API Client

Create `src/lib/api/client.ts`:

```typescript
// src/lib/api/client.ts

import type { ClientConfigResponse, ClientThemesResponse } from './types';

/**
 * Get the base URL for API requests
 * In production through the proxy, this might be empty (same origin)
 * In development, it's the Rails server URL
 */
function getApiBaseUrl(): string {
  return import.meta.env.PUBLIC_API_BASE_URL || '';
}

/**
 * Custom error for API failures
 */
export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public response?: unknown
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

/**
 * Fetch the client configuration for the current website
 *
 * @param websiteSlug - The subdomain/slug of the website
 * @returns The client configuration including theme, colors, fonts
 * @throws ApiError if the request fails
 *
 * @example
 * const config = await fetchClientConfig('mysite');
 * console.log(config.data.theme.name); // 'amsterdam'
 */
export async function fetchClientConfig(websiteSlug: string): Promise<ClientConfigResponse> {
  const baseUrl = getApiBaseUrl();
  const url = `${baseUrl}/api_public/v1/client-config`;

  console.log(`Fetching client config from: ${url}`);

  try {
    const response = await fetch(url, {
      headers: {
        'Accept': 'application/json',
        'X-Website-Slug': websiteSlug,
      },
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new ApiError(
        `Failed to fetch client config: ${response.status} ${response.statusText}`,
        response.status,
        errorBody
      );
    }

    const data = await response.json();
    return data as ClientConfigResponse;

  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }

    // Network error or other issue
    throw new ApiError(
      `Network error fetching client config: ${error}`,
      0
    );
  }
}

/**
 * Fetch all available client themes
 *
 * @returns List of all enabled client themes
 * @throws ApiError if the request fails
 *
 * @example
 * const themes = await fetchClientThemes();
 * themes.data.forEach(t => console.log(t.name));
 */
export async function fetchClientThemes(): Promise<ClientThemesResponse> {
  const baseUrl = getApiBaseUrl();
  const url = `${baseUrl}/api_public/v1/client-themes`;

  console.log(`Fetching client themes from: ${url}`);

  try {
    const response = await fetch(url, {
      headers: {
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new ApiError(
        `Failed to fetch client themes: ${response.status} ${response.statusText}`,
        response.status,
        errorBody
      );
    }

    const data = await response.json();
    return data as ClientThemesResponse;

  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }

    throw new ApiError(
      `Network error fetching client themes: ${error}`,
      0
    );
  }
}

/**
 * Fetch a specific client theme by name
 *
 * @param themeName - The theme name (e.g., 'amsterdam')
 * @returns The theme details
 * @throws ApiError if the request fails or theme not found
 */
export async function fetchClientTheme(themeName: string): Promise<ClientThemesResponse['data'][0]> {
  const baseUrl = getApiBaseUrl();
  const url = `${baseUrl}/api_public/v1/client-themes/${themeName}`;

  const response = await fetch(url, {
    headers: {
      'Accept': 'application/json',
    },
  });

  if (!response.ok) {
    if (response.status === 404) {
      throw new ApiError(`Theme not found: ${themeName}`, 404);
    }
    throw new ApiError(
      `Failed to fetch theme: ${response.status}`,
      response.status
    );
  }

  const data = await response.json();
  return data.data;
}
```

### 3.3 Create an Index Export

Create `src/lib/api/index.ts`:

```typescript
// src/lib/api/index.ts

export * from './types';
export * from './client';
```

---

## Step 4: Create Theme Configuration Store

We need a way to store and access theme configuration throughout the app.

### 4.1 Create the Theme Store

Create `src/lib/theme/store.ts`:

```typescript
// src/lib/theme/store.ts

import type { ThemeConfig, ThemeData, WebsiteData } from '../api/types';

/**
 * Complete theme context available to components
 */
export interface ThemeContext {
  themeName: string;
  themeData: ThemeData | null;
  config: ThemeConfig;
  cssVariables: string;
  website: WebsiteData | null;
}

/**
 * Default theme context when no data is available
 */
export const DEFAULT_THEME_CONTEXT: ThemeContext = {
  themeName: 'amsterdam',  // Default theme
  themeData: null,
  config: {
    primary_color: '#FF6B35',
    secondary_color: '#004E89',
    accent_color: '#F7C59F',
    background_color: '#FFFFFF',
    text_color: '#1A1A1A',
    font_heading: 'Inter',
    font_body: 'Open Sans',
  },
  cssVariables: '',
  website: null,
};

/**
 * Generate CSS custom properties from theme config
 *
 * @param config - The theme configuration
 * @returns CSS string with :root variables
 *
 * @example
 * const css = generateCssVariables({ primary_color: '#FF0000' });
 * // Returns: ":root { --primary-color: #FF0000; }"
 */
export function generateCssVariables(config: ThemeConfig): string {
  const variables = Object.entries(config)
    .filter(([_, value]) => value !== undefined)
    .map(([key, value]) => {
      // Convert snake_case to kebab-case
      const cssVarName = key.replace(/_/g, '-');
      return `--${cssVarName}: ${value}`;
    })
    .join('; ');

  return `:root { ${variables}; }`;
}

/**
 * Get CSS variable reference for use in styles
 *
 * @param name - Variable name in snake_case
 * @returns CSS var() reference
 *
 * @example
 * cssVar('primary_color') // Returns: "var(--primary-color)"
 */
export function cssVar(name: string): string {
  const kebabName = name.replace(/_/g, '-');
  return `var(--${kebabName})`;
}
```

### 4.2 Create Theme Utilities

Create `src/lib/theme/utils.ts`:

```typescript
// src/lib/theme/utils.ts

/**
 * Valid theme names
 */
export const VALID_THEMES = ['amsterdam', 'athens', 'austin'] as const;
export type ThemeName = typeof VALID_THEMES[number];

/**
 * Check if a theme name is valid
 */
export function isValidTheme(name: string | null | undefined): name is ThemeName {
  if (!name) return false;
  return VALID_THEMES.includes(name as ThemeName);
}

/**
 * Get the default theme name
 */
export function getDefaultTheme(): ThemeName {
  return 'amsterdam';
}

/**
 * Safely get theme name, falling back to default
 */
export function getThemeName(name: string | null | undefined): ThemeName {
  if (isValidTheme(name)) {
    return name;
  }
  console.warn(`Invalid theme name: ${name}, falling back to default`);
  return getDefaultTheme();
}
```

### 4.3 Create Index Export

Create `src/lib/theme/index.ts`:

```typescript
// src/lib/theme/index.ts

export * from './store';
export * from './utils';
```

---

## Step 5: Create Dynamic Theme Layout

Now we'll create a layout component that dynamically selects the correct theme.

### 5.1 Create Individual Theme Layouts

First, ensure you have your three theme layouts. Here are templates:

**Amsterdam Theme** - Create `src/layouts/themes/AmsterdamLayout.astro`:

```astro
---
// src/layouts/themes/AmsterdamLayout.astro

/**
 * Amsterdam Modern Theme
 *
 * A clean, modern design with:
 * - Minimalist navigation
 * - Bold accent colors
 * - Sans-serif typography (Inter)
 */

interface Props {
  title?: string;
}

const { title = 'Amsterdam Theme' } = Astro.props;
---

<div class="amsterdam-theme">
  <!-- Theme-specific header -->
  <header class="amsterdam-header">
    <nav class="amsterdam-nav">
      <slot name="logo" />
      <slot name="navigation" />
    </nav>
  </header>

  <!-- Main content -->
  <main class="amsterdam-main">
    <slot />
  </main>

  <!-- Theme-specific footer -->
  <footer class="amsterdam-footer">
    <slot name="footer" />
  </footer>
</div>

<style>
  .amsterdam-theme {
    font-family: var(--font-body, 'Open Sans', sans-serif);
    color: var(--text-color, #1A1A1A);
    background-color: var(--background-color, #FFFFFF);
  }

  .amsterdam-header {
    background: var(--primary-color, #FF6B35);
    padding: 1rem 2rem;
  }

  .amsterdam-nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 1200px;
    margin: 0 auto;
  }

  .amsterdam-main {
    min-height: 80vh;
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
  }

  .amsterdam-footer {
    background: var(--secondary-color, #004E89);
    color: white;
    padding: 2rem;
    text-align: center;
  }

  /* Typography using CSS variables */
  :global(.amsterdam-theme h1),
  :global(.amsterdam-theme h2),
  :global(.amsterdam-theme h3) {
    font-family: var(--font-heading, 'Inter', sans-serif);
    color: var(--secondary-color, #004E89);
  }

  :global(.amsterdam-theme a) {
    color: var(--primary-color, #FF6B35);
  }

  :global(.amsterdam-theme .btn-primary) {
    background: var(--primary-color, #FF6B35);
    color: white;
    padding: 0.75rem 1.5rem;
    border-radius: 4px;
    text-decoration: none;
    display: inline-block;
  }
</style>
```

**Athens Theme** - Create `src/layouts/themes/AthensLayout.astro`:

```astro
---
// src/layouts/themes/AthensLayout.astro

/**
 * Athens Classic Theme
 *
 * An elegant design with:
 * - Classical proportions
 * - Gold accents
 * - Serif typography (Playfair Display)
 */

interface Props {
  title?: string;
}

const { title = 'Athens Theme' } = Astro.props;
---

<div class="athens-theme">
  <header class="athens-header">
    <div class="athens-header-inner">
      <slot name="logo" />
      <nav class="athens-nav">
        <slot name="navigation" />
      </nav>
    </div>
  </header>

  <main class="athens-main">
    <slot />
  </main>

  <footer class="athens-footer">
    <slot name="footer" />
  </footer>
</div>

<style>
  .athens-theme {
    font-family: var(--font-body, 'Lato', sans-serif);
    color: var(--text-color, #2D2D2D);
    background-color: var(--background-color, #FAFAFA);
  }

  .athens-header {
    background: var(--primary-color, #1E3A5F);
    border-bottom: 4px solid var(--secondary-color, #D4AF37);
  }

  .athens-header-inner {
    max-width: 1200px;
    margin: 0 auto;
    padding: 1.5rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .athens-nav {
    display: flex;
    gap: 2rem;
  }

  .athens-main {
    min-height: 80vh;
    max-width: 1000px;
    margin: 0 auto;
    padding: 3rem 2rem;
  }

  .athens-footer {
    background: var(--primary-color, #1E3A5F);
    color: var(--accent-color, #F5F5DC);
    padding: 3rem 2rem;
    text-align: center;
    border-top: 4px solid var(--secondary-color, #D4AF37);
  }

  :global(.athens-theme h1),
  :global(.athens-theme h2),
  :global(.athens-theme h3) {
    font-family: var(--font-heading, 'Playfair Display', serif);
    color: var(--primary-color, #1E3A5F);
  }

  :global(.athens-theme a) {
    color: var(--secondary-color, #D4AF37);
  }

  :global(.athens-theme .btn-primary) {
    background: var(--secondary-color, #D4AF37);
    color: var(--primary-color, #1E3A5F);
    padding: 0.75rem 2rem;
    border-radius: 2px;
    text-decoration: none;
    display: inline-block;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
</style>
```

**Austin Theme** - Create `src/layouts/themes/AustinLayout.astro`:

```astro
---
// src/layouts/themes/AustinLayout.astro

/**
 * Austin Bold Theme
 *
 * A vibrant design with:
 * - Bold colors
 * - Strong typography (Montserrat)
 * - Texas-inspired warmth
 */

interface Props {
  title?: string;
}

const { title = 'Austin Theme' } = Astro.props;
---

<div class="austin-theme">
  <header class="austin-header">
    <div class="austin-header-inner">
      <slot name="logo" />
      <nav class="austin-nav">
        <slot name="navigation" />
      </nav>
    </div>
  </header>

  <main class="austin-main">
    <slot />
  </main>

  <footer class="austin-footer">
    <slot name="footer" />
  </footer>
</div>

<style>
  .austin-theme {
    font-family: var(--font-body, 'Roboto', sans-serif);
    color: var(--text-color, #1C1C1C);
    background-color: var(--background-color, #FFFFFF);
  }

  .austin-header {
    background: linear-gradient(135deg, var(--primary-color, #BF5700) 0%, var(--accent-color, #F8971F) 100%);
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  }

  .austin-header-inner {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .austin-nav {
    display: flex;
    gap: 1.5rem;
  }

  .austin-main {
    min-height: 80vh;
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
  }

  .austin-footer {
    background: var(--secondary-color, #333F48);
    color: white;
    padding: 2rem;
  }

  :global(.austin-theme h1),
  :global(.austin-theme h2),
  :global(.austin-theme h3) {
    font-family: var(--font-heading, 'Montserrat', sans-serif);
    font-weight: 700;
    color: var(--secondary-color, #333F48);
  }

  :global(.austin-theme a) {
    color: var(--primary-color, #BF5700);
    font-weight: 500;
  }

  :global(.austin-theme .btn-primary) {
    background: var(--primary-color, #BF5700);
    color: white;
    padding: 1rem 2rem;
    border-radius: 8px;
    text-decoration: none;
    display: inline-block;
    font-weight: 700;
    text-transform: uppercase;
    box-shadow: 0 4px 6px rgba(191, 87, 0, 0.3);
    transition: transform 0.2s, box-shadow 0.2s;
  }

  :global(.austin-theme .btn-primary:hover) {
    transform: translateY(-2px);
    box-shadow: 0 6px 8px rgba(191, 87, 0, 0.4);
  }
</style>
```

### 5.2 Create the Theme Selector Component

Create `src/layouts/ThemeLayout.astro`:

```astro
---
// src/layouts/ThemeLayout.astro

/**
 * Dynamic Theme Layout Selector
 *
 * This component:
 * 1. Fetches theme configuration from Rails API
 * 2. Selects the appropriate theme layout
 * 3. Injects CSS variables for theming
 *
 * Usage:
 *   <ThemeLayout title="My Page">
 *     <p>Page content here</p>
 *   </ThemeLayout>
 */

import AmsterdamLayout from './themes/AmsterdamLayout.astro';
import AthensLayout from './themes/AthensLayout.astro';
import AustinLayout from './themes/AustinLayout.astro';
import BaseHead from '../components/BaseHead.astro';

import { fetchClientConfig } from '../lib/api';
import { getThemeName, DEFAULT_THEME_CONTEXT, generateCssVariables } from '../lib/theme';
import type { ThemeContext } from '../lib/theme';

interface Props {
  title?: string;
  description?: string;
}

const { title = 'Property Website', description } = Astro.props;

// Get website info from middleware
const { website } = Astro.locals;

// Determine theme name
const themeName = getThemeName(website.theme);

// Fetch full theme configuration
let themeContext: ThemeContext = {
  ...DEFAULT_THEME_CONTEXT,
  themeName,
};

try {
  if (website.slug) {
    const configResponse = await fetchClientConfig(website.slug);
    themeContext = {
      themeName,
      themeData: configResponse.data.theme,
      config: configResponse.data.config,
      cssVariables: configResponse.data.css_variables || generateCssVariables(configResponse.data.config),
      website: configResponse.data.website,
    };
  }
} catch (error) {
  console.error('Failed to fetch theme config:', error);
  // Use defaults - already set above
}

// Select the layout component based on theme name
const THEME_COMPONENTS = {
  amsterdam: AmsterdamLayout,
  athens: AthensLayout,
  austin: AustinLayout,
} as const;

const ThemeComponent = THEME_COMPONENTS[themeName] || AmsterdamLayout;
---

<!DOCTYPE html>
<html lang="en">
<head>
  <BaseHead title={title} description={description} />

  <!-- Inject CSS variables for theming -->
  <style set:html={themeContext.cssVariables}></style>

  <!-- Theme-specific fonts -->
  {themeName === 'amsterdam' && (
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Open+Sans:wght@400;500;600&display=swap" rel="stylesheet" />
  )}
  {themeName === 'athens' && (
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;500;600;700&family=Lato:wght@400;700&display=swap" rel="stylesheet" />
  )}
  {themeName === 'austin' && (
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&family=Roboto:wght@400;500;700&display=swap" rel="stylesheet" />
  )}
</head>
<body>
  <ThemeComponent title={title}>
    <slot name="logo" slot="logo" />
    <slot name="navigation" slot="navigation" />
    <slot />
    <slot name="footer" slot="footer" />
  </ThemeComponent>
</body>
</html>
```

---

## Step 6: Update Base Layout

Create or update `src/components/BaseHead.astro`:

```astro
---
// src/components/BaseHead.astro

/**
 * Common head elements for all pages
 */

interface Props {
  title: string;
  description?: string;
  image?: string;
}

const { title, description = 'Property listings and real estate services', image } = Astro.props;

// Get website info for favicon, etc.
const { website } = Astro.locals;
---

<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta name="generator" content={Astro.generator} />

<title>{title}</title>
<meta name="description" content={description} />

<!-- Open Graph -->
<meta property="og:title" content={title} />
<meta property="og:description" content={description} />
<meta property="og:type" content="website" />
{image && <meta property="og:image" content={image} />}

<!-- Favicon (would come from website config in production) -->
<link rel="icon" type="image/svg+xml" href="/favicon.svg" />

<!-- Base styles -->
<style is:global>
  /* Reset */
  *, *::before, *::after {
    box-sizing: border-box;
  }

  body {
    margin: 0;
    padding: 0;
    min-height: 100vh;
    line-height: 1.6;
  }

  img {
    max-width: 100%;
    height: auto;
  }

  /* Use CSS variables throughout */
  a {
    color: var(--primary-color, #0066cc);
  }

  h1, h2, h3, h4, h5, h6 {
    line-height: 1.2;
    margin-top: 0;
  }
</style>
```

---

## Step 7: Create Admin Routes

Admin routes require authentication. Let's create a protected layout and some admin pages.

### 7.1 Create Admin Layout

Create `src/layouts/AdminLayout.astro`:

```astro
---
// src/layouts/AdminLayout.astro

/**
 * Layout for admin pages (under /client-admin/*)
 *
 * Features:
 * - Requires authentication
 * - Shows admin navigation
 * - Displays user info
 */

import ThemeLayout from './ThemeLayout.astro';

interface Props {
  title?: string;
}

const { title = 'Admin' } = Astro.props;

// Check authentication from middleware
const { user, website } = Astro.locals;

// If not authenticated, we should have been redirected by Rails
// But double-check here for safety
if (!user.authenticated) {
  // In production, Rails handles this redirect
  // This is a fallback for direct access during development
  console.error('Unauthenticated access to admin route');
}
---

<ThemeLayout title={`${title} | Admin`}>
  <nav slot="navigation" class="admin-nav">
    <a href="/client-admin">Dashboard</a>
    <a href="/client-admin/themes">Themes</a>
    <a href="/client-admin/settings">Settings</a>
  </nav>

  <div class="admin-container">
    <!-- Admin header with user info -->
    <header class="admin-header">
      <h1>{title}</h1>
      <div class="admin-user-info">
        {user.authenticated ? (
          <>
            <span class="user-email">{user.email}</span>
            <span class="user-role">({user.role})</span>
          </>
        ) : (
          <span class="not-authenticated">Not authenticated</span>
        )}
      </div>
    </header>

    <!-- Admin content -->
    <main class="admin-main">
      <slot />
    </main>
  </div>

  <div slot="footer">
    <p>Admin Panel - {website.slug}</p>
  </div>
</ThemeLayout>

<style>
  .admin-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
  }

  .admin-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--secondary-color, #ccc);
  }

  .admin-user-info {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .user-email {
    font-weight: 600;
  }

  .user-role {
    color: var(--secondary-color, #666);
    font-size: 0.875rem;
  }

  .not-authenticated {
    color: #dc3545;
    font-weight: 600;
  }

  .admin-nav {
    display: flex;
    gap: 1.5rem;
  }

  .admin-nav a {
    color: white;
    text-decoration: none;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    transition: background-color 0.2s;
  }

  .admin-nav a:hover {
    background-color: rgba(255, 255, 255, 0.2);
  }

  .admin-main {
    background: white;
    border-radius: 8px;
    padding: 2rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
</style>
```

### 7.2 Create Admin Dashboard Page

Create `src/pages/client-admin/index.astro`:

```astro
---
// src/pages/client-admin/index.astro

/**
 * Admin Dashboard
 */

import AdminLayout from '../../layouts/AdminLayout.astro';

const { user, website } = Astro.locals;
---

<AdminLayout title="Dashboard">
  <div class="dashboard">
    <h2>Welcome to the Admin Panel</h2>

    <div class="dashboard-cards">
      <div class="card">
        <h3>Website Info</h3>
        <dl>
          <dt>Subdomain</dt>
          <dd>{website.slug}</dd>

          <dt>Theme</dt>
          <dd>{website.theme}</dd>

          <dt>Rendering Mode</dt>
          <dd>{website.renderingMode}</dd>
        </dl>
      </div>

      <div class="card">
        <h3>Your Account</h3>
        <dl>
          <dt>Email</dt>
          <dd>{user.email || 'Unknown'}</dd>

          <dt>Role</dt>
          <dd>{user.role}</dd>
        </dl>
      </div>

      <div class="card">
        <h3>Quick Actions</h3>
        <ul>
          <li><a href="/client-admin/themes">Customize Theme</a></li>
          <li><a href="/client-admin/settings">Website Settings</a></li>
        </ul>
      </div>
    </div>
  </div>
</AdminLayout>

<style>
  .dashboard-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 1.5rem;
    margin-top: 2rem;
  }

  .card {
    background: var(--background-color, #f5f5f5);
    border-radius: 8px;
    padding: 1.5rem;
    border: 1px solid #e0e0e0;
  }

  .card h3 {
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid var(--primary-color, #007bff);
  }

  dl {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 0.5rem 1rem;
  }

  dt {
    font-weight: 600;
    color: var(--secondary-color, #666);
  }

  dd {
    margin: 0;
  }

  ul {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  ul li {
    padding: 0.5rem 0;
    border-bottom: 1px solid #e0e0e0;
  }

  ul li:last-child {
    border-bottom: none;
  }
</style>
```

### 7.3 Create Theme Customization Page

Create `src/pages/client-admin/themes.astro`:

```astro
---
// src/pages/client-admin/themes.astro

/**
 * Theme Customization Page
 *
 * Allows admins to customize theme colors and fonts
 */

import AdminLayout from '../../layouts/AdminLayout.astro';
import { fetchClientConfig } from '../../lib/api';

const { website } = Astro.locals;

// Fetch current theme configuration
let themeConfig = null;
let error = null;

try {
  if (website.slug) {
    const response = await fetchClientConfig(website.slug);
    themeConfig = response.data;
  }
} catch (e) {
  error = e instanceof Error ? e.message : 'Failed to load theme configuration';
}
---

<AdminLayout title="Theme Customization">
  {error && (
    <div class="error-message">
      <p>Error: {error}</p>
    </div>
  )}

  {themeConfig && (
    <div class="theme-editor">
      <section class="current-theme">
        <h2>Current Theme: {themeConfig.theme?.friendly_name || 'Unknown'}</h2>
        <p>Version: {themeConfig.theme?.version || 'N/A'}</p>
      </section>

      <section class="color-settings">
        <h2>Color Settings</h2>
        <p class="help-text">Click on a color to change it.</p>

        <div class="color-grid">
          {Object.entries(themeConfig.theme?.color_schema || {}).map(([key, schema]) => (
            <div class="color-input-group">
              <label for={`color-${key}`}>{schema.label}</label>
              <div class="color-preview-wrapper">
                <input
                  type="color"
                  id={`color-${key}`}
                  name={key}
                  value={themeConfig.config[key] || schema.default}
                  data-config-key={key}
                />
                <span class="color-value">{themeConfig.config[key] || schema.default}</span>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section class="font-settings">
        <h2>Font Settings</h2>

        <div class="font-grid">
          {Object.entries(themeConfig.theme?.font_schema || {}).map(([key, schema]) => (
            <div class="font-input-group">
              <label for={`font-${key}`}>{schema.label}</label>
              <select
                id={`font-${key}`}
                name={key}
                data-config-key={key}
              >
                {schema.options.map((option: string) => (
                  <option
                    value={option}
                    selected={themeConfig.config[key] === option}
                  >
                    {option}
                  </option>
                ))}
              </select>
            </div>
          ))}
        </div>
      </section>

      <section class="preview-section">
        <h2>Live Preview</h2>
        <div class="preview-box">
          <h3 style="font-family: var(--font-heading)">Heading Preview</h3>
          <p style="font-family: var(--font-body)">
            This is body text. The quick brown fox jumps over the lazy dog.
          </p>
          <button class="btn-primary">Primary Button</button>
        </div>
      </section>

      <div class="actions">
        <button type="button" class="btn-save" id="save-theme">
          Save Changes
        </button>
        <button type="button" class="btn-reset" id="reset-theme">
          Reset to Defaults
        </button>
      </div>
    </div>
  )}
</AdminLayout>

<style>
  .theme-editor {
    display: flex;
    flex-direction: column;
    gap: 2rem;
  }

  section {
    background: var(--background-color, #f9f9f9);
    padding: 1.5rem;
    border-radius: 8px;
    border: 1px solid #e0e0e0;
  }

  section h2 {
    margin-top: 0;
    margin-bottom: 1rem;
  }

  .help-text {
    color: #666;
    font-size: 0.875rem;
    margin-bottom: 1rem;
  }

  .color-grid,
  .font-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
  }

  .color-input-group,
  .font-input-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  label {
    font-weight: 600;
    font-size: 0.875rem;
  }

  .color-preview-wrapper {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  input[type="color"] {
    width: 50px;
    height: 40px;
    border: 2px solid #ccc;
    border-radius: 4px;
    cursor: pointer;
    padding: 2px;
  }

  .color-value {
    font-family: monospace;
    font-size: 0.875rem;
    color: #666;
  }

  select {
    padding: 0.5rem;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 1rem;
    background: white;
  }

  .preview-box {
    background: white;
    padding: 2rem;
    border-radius: 8px;
    border: 2px dashed var(--primary-color, #007bff);
  }

  .actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    padding-top: 1rem;
    border-top: 1px solid #e0e0e0;
  }

  .btn-save {
    background: var(--primary-color, #007bff);
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 600;
  }

  .btn-reset {
    background: #6c757d;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 4px;
    cursor: pointer;
  }

  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 4px;
    border: 1px solid #f5c6cb;
  }
</style>

<script>
  // Client-side interactivity for theme editor
  document.addEventListener('DOMContentLoaded', () => {
    // Update color value display when color input changes
    document.querySelectorAll('input[type="color"]').forEach(input => {
      input.addEventListener('input', (e) => {
        const target = e.target as HTMLInputElement;
        const valueSpan = target.nextElementSibling;
        if (valueSpan) {
          valueSpan.textContent = target.value;
        }

        // Update CSS variable for live preview
        const configKey = target.dataset.configKey;
        if (configKey) {
          document.documentElement.style.setProperty(
            `--${configKey.replace(/_/g, '-')}`,
            target.value
          );
        }
      });
    });

    // Update font CSS variable when select changes
    document.querySelectorAll('select[data-config-key]').forEach(select => {
      select.addEventListener('change', (e) => {
        const target = e.target as HTMLSelectElement;
        const configKey = target.dataset.configKey;
        if (configKey) {
          document.documentElement.style.setProperty(
            `--${configKey.replace(/_/g, '-')}`,
            target.value
          );
        }
      });
    });

    // Save button (placeholder - implement API call)
    document.getElementById('save-theme')?.addEventListener('click', () => {
      alert('Save functionality would call the Rails API here.\nThis requires implementing the admin API endpoint.');
    });

    // Reset button
    document.getElementById('reset-theme')?.addEventListener('click', () => {
      if (confirm('Reset all theme settings to defaults?')) {
        window.location.reload();
      }
    });
  });
</script>
```

---

## Step 8: Testing Your Implementation

### 8.1 Manual Testing Checklist

1. **Start the Rails server** (in the Rails project directory):
   ```bash
   rails server -p 3000
   ```

2. **Start the Astro server** (in the Astro project directory):
   ```bash
   npm run dev
   ```

3. **Create a test website with client rendering**:
   ```bash
   # In Rails console
   rails console

   # Create a client-rendered website
   theme = Pwb::ClientTheme.find_by(name: 'amsterdam')
   website = Pwb::Website.create!(
     subdomain: 'testclient',
     rendering_mode: 'client',
     client_theme_name: 'amsterdam',
     company_display_name: 'Test Client Site'
   )
   ```

4. **Test the proxy** by visiting:
   - `http://testclient.localhost:3000/` - Should show Astro-rendered page
   - `http://testclient.localhost:3000/client-admin/` - Should require login

5. **Verify headers** are being passed:
   - Add `console.log(Astro.locals)` to a page
   - Check the terminal output

### 8.2 API Testing

Test the Rails API directly:

```bash
# Get all client themes
curl http://localhost:3000/api_public/v1/client-themes

# Get client config (replace 'testclient' with your subdomain)
curl -H "X-Website-Slug: testclient" http://localhost:3000/api_public/v1/client-config
```

### 8.3 Common Test Scenarios

| Scenario | Expected Result |
|----------|-----------------|
| Visit public page | Page renders with correct theme |
| Visit `/client-admin` without login | Redirects to login |
| Visit `/client-admin` after login | Shows admin dashboard |
| Change theme color | Live preview updates |
| Invalid website slug | Falls back to default theme |

---

## Troubleshooting

### Problem: "PROXY_AUTH_SECRET not configured"

**Cause**: The `.env` file is missing the secret or Astro isn't reading it.

**Solution**:
1. Check `.env` exists and has `PROXY_AUTH_SECRET`
2. Restart the Astro dev server (it only reads `.env` on startup)
3. Verify the secret matches Rails: `Rails.application.secret_key_base`

### Problem: "Failed to fetch client config"

**Cause**: The Rails API isn't accessible or the website doesn't exist.

**Solution**:
1. Check Rails server is running on port 3000
2. Verify the website exists: `Pwb::Website.find_by(subdomain: 'yoursubdomain')`
3. Check the website has `rendering_mode: 'client'`
4. Test the API directly with curl

### Problem: Theme not changing

**Cause**: CSS variables aren't being applied or theme name is wrong.

**Solution**:
1. Check browser DevTools for CSS variable values
2. Verify `Astro.locals.website.theme` has the correct value
3. Check the `<style set:html>` element in the page source

### Problem: Admin routes accessible without login

**Cause**: Rails proxy isn't enforcing authentication.

**Solution**:
1. Verify accessing via Rails domain (not direct Astro)
2. Check Rails routes: `/client-admin/*` should require auth
3. Review `ClientProxyController#authenticate_for_admin_routes!`

### Problem: Fonts not loading

**Cause**: Google Fonts link not included or wrong font names.

**Solution**:
1. Check the `<link>` tags in ThemeLayout.astro
2. Verify font names match exactly (case-sensitive)
3. Check browser Network tab for failed font requests

---

## Glossary

| Term | Definition |
|------|------------|
| **Client Rendering** | Website rendered by JavaScript (Astro) in the browser |
| **Rails Rendering** | Website rendered by Rails on the server using Liquid templates |
| **Reverse Proxy** | Rails forwards requests to Astro and returns the response |
| **JWT** | JSON Web Token - a secure way to pass authentication info |
| **CSS Variables** | Custom properties (like `--primary-color`) that can be changed dynamically |
| **Middleware** | Code that runs before every request to set up context |
| **Theme Context** | All the configuration needed to render a theme correctly |
| **A Themes** | Client-rendered themes (Amsterdam, Athens, Austin) |
| **B Themes** | Rails-rendered themes (Barcelona, Bologna, Brisbane, etc.) |

---

## File Structure Summary

After completing this guide, your Astro project should have:

```
src/
├── components/
│   └── BaseHead.astro
├── layouts/
│   ├── AdminLayout.astro
│   ├── ThemeLayout.astro
│   └── themes/
│       ├── AmsterdamLayout.astro
│       ├── AthensLayout.astro
│       └── AustinLayout.astro
├── lib/
│   ├── api/
│   │   ├── client.ts
│   │   ├── index.ts
│   │   └── types.ts
│   └── theme/
│       ├── index.ts
│       ├── store.ts
│       └── utils.ts
├── middleware/
│   └── index.ts
├── pages/
│   ├── client-admin/
│   │   ├── index.astro
│   │   └── themes.astro
│   └── index.astro
└── env.d.ts
```

---

## Next Steps

Once you've completed this implementation:

1. **Add more admin pages** for settings, content management, etc.
2. **Implement save functionality** by creating the admin API endpoint in Rails
3. **Add error boundaries** for better error handling
4. **Write tests** using Astro's testing utilities
5. **Optimize performance** with caching for API calls

---

## Questions?

If you get stuck:
1. Check the [Rails implementation status document](./client_rendering_implementation_status.md)
2. Look at the Rails controller code for how headers are sent
3. Ask your team lead for help with the `PROXY_AUTH_SECRET` value

---

## Advanced: Per-Tenant Astro URL Routing

For multi-region deployments or enterprise tenants, each website can specify a custom Astro server URL. This allows:

- Regional Astro deployments (US, EU, APAC)
- Dedicated Astro instances for enterprise clients
- Staging/development environments with isolated Astro builds

See [Per-Tenant Astro URL Routing](./per_tenant_astro_url_routing.md) for configuration details.
