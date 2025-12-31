# Standalone Quasar Frontend Implementation

This document outlines the steps to decouple the existing Quasar/Vue frontend from the Rails/Vite integration (`vite-plugin-ruby`) and run it as a standalone Single Page Application (SPA).

## Current Architecture

The current setup uses `vite-plugin-ruby` to integrate Vite with Rails.
- **Entrypoints**: Located in `app/frontend/entrypoints/`.
    - `v-admin.js`: Entry point for the Admin application.
    - `v-public.js`: Entry point for the Public application.
- **Source Code**:
    - Admin App: `app/frontend/v-admin-app/`
    - Public App: `app/frontend/v-public-app/`
- **Routing**: Vue Router is used within the apps, but the initial page load is handled by Rails controllers rendering a view that includes the Vite tags.

## Proposed Standalone Architecture

In a standalone setup, the Quasar application will be a pure static site (HTML/CSS/JS) built by Vite. It will communicate with the Rails backend via API calls.

### Key Changes Required

1.  **Create an `index.html`**:
    Vite needs an `index.html` file as the entry point for the build. Currently, Rails views serve this purpose. You will need to create an `index.html` (e.g., in `app/frontend/v-admin-app/index.html`) that references the main script.

2.  **Update `vite.config.ts`**:
    The current configuration uses `RubyPlugin()`. For a standalone build, you might want a separate Vite config or a conditional configuration that doesn't rely on the Ruby plugin for the standalone build, or simply configures the build output directory (`dist`) correctly.

3.  **API Configuration**:
    Ensure all API calls use a base URL that points to the Rails API. In development, you can use Vite's `server.proxy` to proxy API requests to the Rails server (e.g., localhost:3000). In production, the static files can be served by Nginx/Apache or a CDN, pointing to the API domain.

4.  **Routing**:
    The Vue Router should handle all navigation. You may need to configure the web server (Nginx/Netlify/Vercel) to rewrite all requests to `index.html` to support HTML5 History mode.

## Implementation Steps (Admin App Example)

### 1. Create `index.html`

Create `app/frontend/v-admin-app/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Admin Panel</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/app/frontend/entrypoints/v-admin.js"></script>
  </body>
</html>
```

*Note: You might need to adjust the src path depending on where you run the vite command from.*

### 2. Configure Vite for Standalone Build

You can create a separate config file, e.g., `vite.standalone.config.ts`:

```typescript
import { defineConfig } from 'vite'
import VuePlugin from '@vitejs/plugin-vue'
import { quasar, transformAssetUrls } from '@quasar/vite-plugin'
import path from 'path'

export default defineConfig({
  root: 'app/frontend/v-admin-app', // Set root to the app dir
  publicDir: 'public', // Adjust as needed
  resolve: {
    alias: {
      '~': path.resolve(__dirname, 'app/frontend'),
      '@': path.resolve(__dirname, 'app/frontend/v-admin-app/src')
    }
  },
  plugins: [
    VuePlugin({
      template: { transformAssetUrls }
    }),
    quasar({
      // sassVariables: 'src/quasar-variables.sass'
    })
  ],
  build: {
    outDir: '../../../public/admin-app', // Build to a specific public dir or separate dist
    emptyOutDir: true
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      }
    }
  }
})
```

### 3. Update API Client

Ensure your Axios or Fetch setup uses the correct base URL.

```javascript
// app/frontend/v-admin-app/src/boot/axios.js (or similar)
import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api'
})

export { api }
```

### 4. Run and Build

Add scripts to `package.json`:

```json
"scripts": {
  "dev:admin": "vite --config vite.standalone.config.ts",
  "build:admin": "vite build --config vite.standalone.config.ts"
}
```

## Migration Strategy

1.  **Pilot**: Start with the Admin app as it's likely more self-contained.
2.  **Dual Mode**: Keep the existing `vite-plugin-ruby` setup working while you test the standalone build.
3.  **Switch**: Once the standalone build is verified, you can remove the Rails view rendering for the admin section and serve the static files instead.
