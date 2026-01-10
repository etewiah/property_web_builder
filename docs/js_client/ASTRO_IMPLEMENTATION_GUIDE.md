# Astro.js Implementation Guide for PropertyWebBuilder

**Created**: 2026-01-10  
**Status**: Ready for Implementation  
**Framework**: Astro 4.x with React Islands  
**Deployment**: Dokku on VPS

---

## Table of Contents

1. [Overview](#overview)
2. [Why Astro for PropertyWebBuilder](#why-astro)
3. [Architecture](#architecture)
4. [Project Structure](#project-structure)
5. [Setup & Installation](#setup--installation)
6. [API Integration](#api-integration)
7. [Page Implementation](#page-implementation)
8. [Component Architecture](#component-architecture)
9. [SEO Implementation](#seo-implementation)
10. [Theming System](#theming-system)
11. [Internationalization](#internationalization)
12. [Performance Optimization](#performance-optimization)
13. [Dokku Deployment](#dokku-deployment)
14. [Multi-Tenant Setup](#multi-tenant-setup)
15. [Development Workflow](#development-workflow)
16. [Comparison with Next.js](#comparison-with-nextjs)

---

## Overview

### What is Astro?

Astro is a **content-focused web framework** that delivers:
- **Zero JavaScript by default** - Ships only HTML and CSS
- **Island Architecture** - Hydrate only interactive components
- **Framework Agnostic** - Use React, Vue, Svelte, or vanilla JS together
- **SSG & SSR** - Static site generation with optional server rendering
- **Perfect for PWB** - Property sites are mostly content with selective interactivity

### Score Comparison

| Framework | Score | Best For |
|-----------|-------|----------|
| **Next.js** | 9.25/10 | Rich ecosystems, complex apps |
| **Astro** | 8.5/10 | **Maximum performance, SEO, content sites** |
| Nuxt.js | 8.7/10 | Vue developers |
| SvelteKit | 8.4/10 | Best DX |

---

## Why Astro for PropertyWebBuilder

### ✅ Perfect Fit for Property Listing Sites

1. **Content-Heavy, Not App-Heavy**
   - Property sites are 80% content (listings, photos, text)
   - Only 20% interactive (search filters, contact forms, map)
   - Astro excels at this ratio

2. **Best-in-Class Performance**
   - Lighthouse scores: **100/100/100/100** achievable
   - First Contentful Paint: **< 0.5s** (vs 1-2s for Next.js)
   - Zero JavaScript for static content
   - Perfect for SEO-critical property listings

3. **Framework Flexibility**
   - Use React for complex UI (search filters, property gallery)
   - Use Preact for smaller bundle (buttons, forms)
   - Mix vanilla JS for simple interactions
   - Future-proof: Easy to add Vue/Svelte components later

4. **Simple Mental Model**
   - `.astro` files are like ERB/Liquid templates (familiar!)
   - Props pass data like Rails partials
   - No "use client" vs "use server" confusion
   - TypeScript optional but recommended

### ⚠️ Trade-offs vs Next.js

| Feature | Astro | Next.js | Winner |
|---------|-------|---------|--------|
| Performance | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Astro |
| SEO | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Tie |
| Bundle Size | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Astro |
| Ecosystem | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Next.js |
| SPA Transitions | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Next.js |
| Learning Curve | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Astro |
| UI Libraries | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Next.js |
| Developer Hiring | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Next.js |

**Verdict**: 
- Choose **Astro** if performance/Lighthouse scores are critical
- Choose **Next.js** if rich interactivity/SPA feel is priority
- For PWB property sites: **Astro is ideal**

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      VPS (Dokku)                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    Nginx (Dokku)                        ││
│  │              SSL Termination + Routing                  ││
│  └─────────────────────┬───────────────────────────────────┘│
│                        │                                     │
│     ┌──────────────────┼──────────────────┐                 │
│     ▼                  ▼                  ▼                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ client-1 │    │ client-2 │    │ client-n │              │
│  │ (Astro)  │    │ (Astro)  │    │ (Astro)  │              │
│  │ Port 4321│    │ Port 4322│    │ Port 432n│              │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘              │
│       │               │               │                     │
│       └───────────────┼───────────────┘                     │
│                       ▼                                      │
│              ┌────────────────┐                             │
│              │   PWB Rails    │                             │
│              │   API Server   │                             │
│              │ /api_public/v1/│                             │
│              └────────────────┘                             │
└─────────────────────────────────────────────────────────────┘
```

### Rendering Strategy

```
┌────────────────────────────────────────────────────────┐
│                    Astro Pages                         │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Homepage              → SSG (Static)                  │
│  Property Search       → SSR (Server-side)             │
│  Property Detail       → SSG (Static with revalidation)│
│  About/Contact         → SSG (Static)                  │
│  Dynamic Pages         → SSG (Static)                  │
│                                                        │
├────────────────────────────────────────────────────────┤
│                Interactive Islands                     │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Search Filters        → React (client:load)           │
│  Contact Form          → React (client:visible)        │
│  Property Map          → React (client:idle)           │
│  Image Gallery         → React (client:load)           │
│  Language Switcher     → Preact (client:load)          │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Data Flow

```
Build Time (SSG):
┌─────────────┐
│ PWB API     │ ───► Fetch all properties ───► Generate static pages
│ /properties │                                 (e.g., 150 pages)
└─────────────┘

Runtime (SSR):
┌─────────────┐
│ User Request│ ───► Astro SSR ───► Fetch from PWB API ───► Render HTML
│ /properties │                     (with filters)
└─────────────┘

Client-Side (Islands):
┌──────────────┐
│ React Island │ ───► Fetch from PWB API ───► Update UI
│ (filters)    │      (client-side)
└──────────────┘
```

---

## Project Structure

```
pwb-astro-client/
├── .dokku/                        # Dokku configuration
│   └── CHECKS                     # Health check
├── public/                        # Static assets
│   ├── fonts/
│   ├── images/
│   └── favicon.svg
├── src/
│   ├── components/                # Astro & React components
│   │   ├── astro/                 # Pure Astro components (no JS)
│   │   │   ├── Layout.astro       # Main layout wrapper
│   │   │   ├── Header.astro       # Site header
│   │   │   ├── Footer.astro       # Site footer
│   │   │   ├── PropertyCard.astro # Property card (static)
│   │   │   └── SEO.astro          # SEO meta tags
│   │   ├── react/                 # React islands (interactive)
│   │   │   ├── SearchFilters.tsx  # Property search UI
│   │   │   ├── ContactForm.tsx    # Contact form
│   │   │   ├── PropertyGallery.tsx# Image gallery
│   │   │   ├── PropertyMap.tsx    # Leaflet map
│   │   │   └── LanguageSwitcher.tsx
│   │   └── ui/                    # Shared UI components
│   │       ├── Button.tsx
│   │       ├── Card.tsx
│   │       └── Input.tsx
│   ├── layouts/                   # Layout components
│   │   ├── BaseLayout.astro       # HTML shell
│   │   ├── PageLayout.astro       # Standard page layout
│   │   └── PropertyLayout.astro   # Property page layout
│   ├── pages/                     # File-based routing
│   │   ├── index.astro            # Homepage (SSG)
│   │   ├── properties/
│   │   │   ├── index.astro        # Property search (SSR)
│   │   │   └── [slug].astro       # Property detail (SSG)
│   │   ├── about.astro            # About page (SSG)
│   │   ├── contact.astro          # Contact page (SSG)
│   │   ├── [locale]/              # i18n routes
│   │   │   ├── index.astro
│   │   │   └── properties/
│   │   │       └── [slug].astro
│   │   ├── 404.astro              # Not found page
│   │   ├── robots.txt.ts          # Dynamic robots.txt
│   │   └── sitemap.xml.ts         # Dynamic sitemap
│   ├── lib/                       # Utilities
│   │   ├── api/                   # PWB API client
│   │   │   ├── client.ts          # Base API client
│   │   │   ├── properties.ts      # Property endpoints
│   │   │   ├── pages.ts           # Page/content endpoints
│   │   │   └── site.ts            # Site config endpoints
│   │   ├── utils/                 # Helper functions
│   │   │   ├── formatters.ts      # Price, date formatting
│   │   │   ├── seo.ts             # SEO helpers
│   │   │   └── i18n.ts            # Translation helpers
│   │   └── constants.ts           # App constants
│   ├── styles/                    # Global styles
│   │   ├── global.css             # Global CSS + Tailwind
│   │   └── themes/                # Theme CSS variables
│   │       ├── default.css
│   │       ├── luxury.css
│   │       └── modern.css
│   ├── types/                     # TypeScript types
│   │   ├── property.ts
│   │   ├── page.ts
│   │   ├── site.ts
│   │   └── api.ts
│   ├── i18n/                      # Internationalization
│   │   ├── locales/
│   │   │   ├── en.json
│   │   │   ├── es.json
│   │   │   └── ru.json
│   │   └── utils.ts
│   └── env.d.ts                   # TypeScript environment types
├── .env.example                   # Environment template
├── .env.local                     # Local environment
├── .env.production                # Production environment
├── astro.config.mjs               # Astro configuration
├── tailwind.config.mjs            # Tailwind configuration
├── tsconfig.json                  # TypeScript configuration
├── package.json
├── Dockerfile                     # Docker image
└── README.md
```

---

## Setup & Installation

### Prerequisites

- Node.js 20.x or later
- npm/pnpm/yarn
- Git
- Docker (for deployment)

### 1. Create New Astro Project

```bash
# Using npm
npm create astro@latest pwb-astro-client

# Follow prompts:
# ✔ How would you like to start? → Empty
# ✔ Install dependencies? → Yes
# ✔ TypeScript? → Yes, strict
# ✔ Initialize git? → Yes

cd pwb-astro-client
```

### 2. Install Dependencies

```bash
# Core integrations
npm install @astrojs/react @astrojs/tailwind @astrojs/node

# UI Framework
npm install react react-dom @types/react @types/react-dom

# Styling
npm install tailwindcss @tailwindcss/typography @tailwindcss/forms
npm install class-variance-authority clsx tailwind-merge

# Data Fetching
npm install @tanstack/react-query axios

# Forms
npm install react-hook-form zod @hookform/resolvers

# Maps
npm install leaflet react-leaflet @types/leaflet

# i18n
npm install astro-i18n-aut

# Dev Tools
npm install -D @types/node prettier prettier-plugin-astro
```

### 3. Configure Astro

```javascript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwind from '@astrojs/tailwind';
import node from '@astrojs/node';

export default defineConfig({
  output: 'hybrid', // Mix SSG and SSR
  adapter: node({
    mode: 'standalone',
  }),
  integrations: [
    react(),
    tailwind({
      applyBaseStyles: false, // We'll import Tailwind manually
    }),
  ],
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'es', 'ru'],
    routing: {
      prefixDefaultLocale: false,
    },
  },
  vite: {
    ssr: {
      noExternal: ['@tanstack/react-query'],
    },
  },
});
```

### 4. Configure Tailwind

```javascript
// tailwind.config.mjs
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        primary: 'hsl(var(--primary))',
        'primary-foreground': 'hsl(var(--primary-foreground))',
        secondary: 'hsl(var(--secondary))',
        'secondary-foreground': 'hsl(var(--secondary-foreground))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        muted: 'hsl(var(--muted))',
        'muted-foreground': 'hsl(var(--muted-foreground))',
        accent: 'hsl(var(--accent))',
        'accent-foreground': 'hsl(var(--accent-foreground))',
        border: 'hsl(var(--border))',
      },
      fontFamily: {
        sans: ['Inter Variable', 'system-ui', 'sans-serif'],
        serif: ['Playfair Display Variable', 'Georgia', 'serif'],
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms'),
  ],
};
```

### 5. Environment Configuration

```bash
# .env.example
PUBLIC_API_URL=https://api.yourpwbsite.com
PUBLIC_SITE_URL=https://yoursite.com
PUBLIC_GOOGLE_MAPS_API_KEY=your_key_here

# Build-time variables
THEME=default
SITE_NAME=Property Website
```

```bash
# .env.local (for development)
PUBLIC_API_URL=http://localhost:3000
PUBLIC_SITE_URL=http://localhost:4321
PUBLIC_GOOGLE_MAPS_API_KEY=

THEME=luxury
SITE_NAME=Luxury Properties Demo
```

---

## API Integration

### Base API Client

```typescript
// src/lib/api/client.ts
import axios, { type AxiosInstance, type AxiosRequestConfig } from 'axios';

const API_BASE_URL = import.meta.env.PUBLIC_API_URL || 'http://localhost:3000';

class PWBApiClient {
  private client: AxiosInstance;

  constructor(baseURL: string = API_BASE_URL) {
    this.client = axios.create({
      baseURL: `${baseURL}/api_public/v1`,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    });

    // Response interceptor for unwrapping
    this.client.interceptors.response.use(
      (response) => {
        // Unwrap common response wrappers
        const data = response.data;
        return {
          ...response,
          data: data.data ?? data.payload ?? data.result ?? data,
        };
      },
      (error) => {
        console.error('API Error:', error);
        return Promise.reject(error);
      }
    );
  }

  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get<T>(url, config);
    return response.data;
  }

  async post<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.post<T>(url, data, config);
    return response.data;
  }
}

export const apiClient = new PWBApiClient();
export default apiClient;
```

### Properties API

```typescript
// src/lib/api/properties.ts
import apiClient from './client';
import type { Property, PropertySearchParams, PaginatedResponse } from '@/types/property';

export async function getProperties(
  params: PropertySearchParams = {}
): Promise<PaginatedResponse<Property>> {
  const queryParams = new URLSearchParams();
  
  if (params.locale) queryParams.set('locale', params.locale);
  if (params.page) queryParams.set('page', params.page.toString());
  if (params.per_page) queryParams.set('per_page', params.per_page.toString());
  if (params.sale_or_rental) queryParams.set('sale_or_rental', params.sale_or_rental);
  if (params.property_type) queryParams.set('property_type', params.property_type);
  if (params.for_sale_price_from) {
    queryParams.set('for_sale_price_from', params.for_sale_price_from.toString());
  }
  if (params.for_sale_price_till) {
    queryParams.set('for_sale_price_till', params.for_sale_price_till.toString());
  }
  if (params.bedrooms_from) queryParams.set('bedrooms_from', params.bedrooms_from.toString());
  
  const url = `/properties?${queryParams.toString()}`;
  return apiClient.get<PaginatedResponse<Property>>(url);
}

export async function getProperty(slugOrId: string | number, locale?: string): Promise<Property> {
  const queryParams = locale ? `?locale=${locale}` : '';
  return apiClient.get<Property>(`/properties/${slugOrId}${queryParams}`);
}

export async function getAllPropertySlugs(locale?: string): Promise<string[]> {
  // For static generation - fetch all property slugs
  const response = await getProperties({ locale, per_page: 1000 });
  return response.properties.map((p) => p.slug);
}
```

### Site Configuration API

```typescript
// src/lib/api/site.ts
import apiClient from './client';
import type { SiteDetails, NavigationLink, Page, SelectValues, Theme } from '@/types/site';

export async function getSiteDetails(): Promise<SiteDetails> {
  return apiClient.get<SiteDetails>('/site_details');
}

export async function getNavigationLinks(position: 'top_nav' | 'footer'): Promise<NavigationLink[]> {
  return apiClient.get<NavigationLink[]>(`/links?position=${position}`);
}

export async function getPage(slugOrId: string | number, locale?: string): Promise<Page> {
  const queryParams = locale ? `?locale=${locale}` : '';
  const endpoint = typeof slugOrId === 'string' 
    ? `/pages/by_slug/${slugOrId}${queryParams}`
    : `/pages/${slugOrId}${queryParams}`;
  return apiClient.get<Page>(endpoint);
}

export async function getSelectValues(): Promise<SelectValues> {
  return apiClient.get<SelectValues>('/select_values');
}

export async function getTranslations(locale: string): Promise<Record<string, string>> {
  return apiClient.get<Record<string, string>>(`/translations?locale=${locale}`);
}

// NEW: Theme endpoint (requires backend implementation)
export async function getTheme(): Promise<Theme> {
  try {
    return await apiClient.get<Theme>('/theme');
  } catch (error) {
    // Fallback if endpoint doesn't exist yet
    const siteDetails = await getSiteDetails();
    return {
      colors: {
        primary: siteDetails.primary_color || '#3B82F6',
        secondary: siteDetails.secondary_color || '#10B981',
      },
    };
  }
}
```

### TypeScript Types

```typescript
// src/types/property.ts
export interface PropertyPhoto {
  id: number;
  image: string;
  thumbnail?: string;
  position?: number;
}

export interface Property {
  id: number;
  slug: string;
  title: string;
  description: string;
  price_sale_current_cents: number | null;
  price_rental_monthly_current_cents: number | null;
  currency: string;
  area_unit: string;
  constructed_area: number;
  plot_area?: number;
  count_bedrooms: number;
  count_bathrooms: number;
  count_garages?: number;
  for_sale: boolean;
  for_rent: boolean;
  latitude: number;
  longitude: number;
  address?: string;
  city?: string;
  region?: string;
  country?: string;
  property_type: string;
  reference?: string;
  year_construction?: number;
  featured: boolean;
  visible: boolean;
  prop_photos: PropertyPhoto[];
}

export interface PropertySearchParams {
  locale?: string;
  page?: number;
  per_page?: number;
  sale_or_rental?: 'sale' | 'rental';
  property_type?: string;
  for_sale_price_from?: number;
  for_sale_price_till?: number;
  for_rent_price_from?: number;
  for_rent_price_till?: number;
  bedrooms_from?: number;
  bathrooms_from?: number;
}

export interface PaginatedResponse<T> {
  properties: T[];
  meta: {
    total: number;
    page: number;
    per_page: number;
    total_pages: number;
  };
}
```

```typescript
// src/types/site.ts
export interface SiteDetails {
  name: string;
  logo_url?: string;
  primary_color: string;
  secondary_color?: string;
  contact_email: string;
  contact_phone?: string;
  default_currency: string;
  default_area_unit: string;
  locales: string[];
  default_locale: string;
  social_links?: {
    facebook?: string;
    twitter?: string;
    instagram?: string;
    linkedin?: string;
  };
}

export interface NavigationLink {
  id: number;
  title: string;
  url: string;
  position: 'top_nav' | 'footer';
  order: number;
  visible: boolean;
  external: boolean;
}

export interface PagePart {
  key: string;
  part_type: string;
  content: Record<string, any>;
  position: number;
  visible: boolean;
}

export interface Page {
  id: number;
  slug: string;
  title: string;
  meta_title?: string;
  meta_description?: string;
  page_parts: PagePart[];
}

export interface SelectValues {
  select_values: Record<string, {
    label: string;
    values: Array<{ value: string; label: string }>;
  }>;
}

export interface Theme {
  colors: {
    primary: string;
    secondary?: string;
    background?: string;
    foreground?: string;
    muted?: string;
    accent?: string;
  };
  fonts?: {
    heading?: string;
    body?: string;
  };
  borderRadius?: Record<string, string>;
  customCss?: string;
}
```

---

## Page Implementation

### Base Layout

```astro
---
// src/layouts/BaseLayout.astro
import { ViewTransitions } from 'astro:transitions';
import { getTheme, getSiteDetails } from '@/lib/api/site';
import '@/styles/global.css';

interface Props {
  title?: string;
  description?: string;
  image?: string;
  locale?: string;
}

const { title, description, image, locale = 'en' } = Astro.props;

// Fetch site config and theme at build time
const [siteDetails, theme] = await Promise.all([
  getSiteDetails(),
  getTheme(),
]);

const pageTitle = title ? `${title} | ${siteDetails.name}` : siteDetails.name;
const pageDescription = description || `Find your dream property with ${siteDetails.name}`;

// Generate CSS custom properties from theme
const themeStyles = `
  :root {
    --primary: ${theme.colors.primary};
    --secondary: ${theme.colors.secondary || theme.colors.primary};
    --background: ${theme.colors.background || '#ffffff'};
    --foreground: ${theme.colors.foreground || '#000000'};
  }
`;
---

<!DOCTYPE html>
<html lang={locale}>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <meta name="generator" content={Astro.generator} />
    
    <!-- SEO -->
    <title>{pageTitle}</title>
    <meta name="description" content={pageDescription} />
    
    <!-- Open Graph -->
    <meta property="og:title" content={pageTitle} />
    <meta property="og:description" content={pageDescription} />
    <meta property="og:type" content="website" />
    {image && <meta property="og:image" content={image} />}
    
    <!-- Theme Colors (Dynamic from API) -->
    <style set:html={themeStyles}></style>
    {theme.customCss && <style set:html={theme.customCss}></style>}
    
    <!-- View Transitions (Optional SPA-like navigation) -->
    <ViewTransitions />
  </head>
  <body class="min-h-screen bg-background font-sans text-foreground antialiased">
    <slot />
  </body>
</html>
```

### Page Layout with Header/Footer

```astro
---
// src/layouts/PageLayout.astro
import BaseLayout from './BaseLayout.astro';
import Header from '@/components/astro/Header.astro';
import Footer from '@/components/astro/Footer.astro';

interface Props {
  title?: string;
  description?: string;
  locale?: string;
}

const { title, description, locale } = Astro.props;
---

<BaseLayout title={title} description={description} locale={locale}>
  <Header locale={locale} />
  <main class="flex-1">
    <slot />
  </main>
  <Footer locale={locale} />
</BaseLayout>
```

### Homepage

```astro
---
// src/pages/index.astro
import PageLayout from '@/layouts/PageLayout.astro';
import PropertyCard from '@/components/astro/PropertyCard.astro';
import SearchFilters from '@/components/react/SearchFilters';
import { getProperties, getPage } from '@/lib/api';

// Static generation at build time
export const prerender = true;

const locale = 'en';

// Fetch featured properties and homepage content
const [propertiesData, homePage] = await Promise.all([
  getProperties({ featured: true, per_page: 6, locale }),
  getPage('home', locale).catch(() => null),
]);

// Extract hero content from page parts
const heroPart = homePage?.page_parts?.find((p) => p.part_type === 'hero_section');
const heroContent = heroPart?.content || {};
---

<PageLayout title="Home" locale={locale}>
  <!-- Hero Section -->
  <section 
    class="relative bg-cover bg-center py-32"
    style={heroContent.background_image ? `background-image: url(${heroContent.background_image})` : ''}
  >
    <div class="absolute inset-0 bg-black/40"></div>
    <div class="container relative z-10 mx-auto px-4 text-center text-white">
      <h1 class="mb-4 text-5xl font-bold">
        {heroContent.title || 'Find Your Dream Property'}
      </h1>
      <p class="mb-8 text-xl">
        {heroContent.subtitle || 'Browse our exclusive listings'}
      </p>
      
      <!-- Search Filters (React Island) -->
      <SearchFilters client:load />
    </div>
  </section>

  <!-- Featured Properties -->
  <section class="py-16">
    <div class="container mx-auto px-4">
      <h2 class="mb-8 text-3xl font-bold">Featured Properties</h2>
      <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
        {propertiesData.properties.map((property) => (
          <PropertyCard property={property} />
        ))}
      </div>
    </div>
  </section>

  <!-- CTA Section -->
  <section class="bg-primary py-16 text-primary-foreground">
    <div class="container mx-auto px-4 text-center">
      <h2 class="mb-4 text-3xl font-bold">Ready to Find Your Perfect Home?</h2>
      <p class="mb-8 text-lg">Browse our full collection of properties</p>
      <a 
        href="/properties" 
        class="inline-block rounded-lg bg-white px-8 py-3 font-semibold text-primary transition hover:bg-opacity-90"
      >
        View All Properties
      </a>
    </div>
  </section>
</PageLayout>
```

### Property Search Page (SSR)

```astro
---
// src/pages/properties/index.astro
import PageLayout from '@/layouts/PageLayout.astro';
import PropertyCard from '@/components/astro/PropertyCard.astro';
import SearchFilters from '@/components/react/SearchFilters';
import { getProperties } from '@/lib/api/properties';

// Enable SSR for this page (dynamic based on query params)
export const prerender = false;

const locale = Astro.currentLocale || 'en';
const searchParams = Astro.url.searchParams;

// Extract query params
const params = {
  locale,
  page: parseInt(searchParams.get('page') || '1'),
  per_page: 12,
  sale_or_rental: searchParams.get('sale_or_rental') as 'sale' | 'rental' | undefined,
  property_type: searchParams.get('property_type') || undefined,
  bedrooms_from: searchParams.get('bedrooms_from') 
    ? parseInt(searchParams.get('bedrooms_from')!) 
    : undefined,
};

// Fetch properties based on search params (server-side)
const propertiesData = await getProperties(params);
---

<PageLayout title="Properties" locale={locale}>
  <div class="container mx-auto px-4 py-8">
    <h1 class="mb-8 text-4xl font-bold">Property Listings</h1>
    
    <!-- Search Filters (React Island - loads on client) -->
    <div class="mb-8">
      <SearchFilters 
        client:load 
        initialParams={params}
      />
    </div>

    <!-- Results Count -->
    <p class="mb-4 text-muted-foreground">
      Showing {propertiesData.properties.length} of {propertiesData.meta.total} properties
    </p>

    <!-- Property Grid -->
    <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
      {propertiesData.properties.map((property) => (
        <PropertyCard property={property} />
      ))}
    </div>

    <!-- Pagination -->
    {propertiesData.meta.total_pages > 1 && (
      <div class="mt-8 flex justify-center gap-2">
        {Array.from({ length: propertiesData.meta.total_pages }, (_, i) => i + 1).map((pageNum) => (
          <a
            href={`/properties?page=${pageNum}`}
            class:list={[
              'rounded px-4 py-2',
              pageNum === params.page 
                ? 'bg-primary text-primary-foreground' 
                : 'bg-muted hover:bg-muted/80'
            ]}
          >
            {pageNum}
          </a>
        ))}
      </div>
    )}
  </div>
</PageLayout>
```

### Property Detail Page (SSG with dynamic paths)

```astro
---
// src/pages/properties/[slug].astro
import PageLayout from '@/layouts/PageLayout.astro';
import PropertyGallery from '@/components/react/PropertyGallery';
import PropertyMap from '@/components/react/PropertyMap';
import ContactForm from '@/components/react/ContactForm';
import { getProperty, getAllPropertySlugs } from '@/lib/api/properties';
import { formatPrice, formatArea } from '@/lib/utils/formatters';

// Static generation - generate all property pages at build time
export const prerender = true;

export async function getStaticPaths() {
  const slugs = await getAllPropertySlugs();
  return slugs.map((slug) => ({ params: { slug } }));
}

const { slug } = Astro.params;
const locale = Astro.currentLocale || 'en';

const property = await getProperty(slug!, locale);

const metaTitle = `${property.title} - ${formatPrice(property.price_sale_current_cents, property.currency)}`;
const metaDescription = property.description.substring(0, 160);
---

<PageLayout title={metaTitle} description={metaDescription} locale={locale}>
  <article class="container mx-auto px-4 py-8">
    <!-- Image Gallery (React Island - hydrates on load) -->
    <PropertyGallery 
      client:load 
      images={property.prop_photos} 
      alt={property.title}
    />

    <!-- Property Details -->
    <div class="mt-8 grid grid-cols-1 gap-8 lg:grid-cols-3">
      <!-- Main Content -->
      <div class="lg:col-span-2">
        <h1 class="mb-4 text-4xl font-bold">{property.title}</h1>
        
        <div class="mb-6 flex items-center gap-4 text-lg">
          <span class="font-bold text-primary">
            {formatPrice(property.price_sale_current_cents, property.currency)}
          </span>
          <span class="text-muted-foreground">
            {property.count_bedrooms} beds • {property.count_bathrooms} baths • 
            {formatArea(property.constructed_area, property.area_unit)}
          </span>
        </div>

        <div class="prose max-w-none">
          <h2>Description</h2>
          <p>{property.description}</p>
        </div>

        <!-- Features -->
        {property.features && property.features.length > 0 && (
          <div class="mt-8">
            <h2 class="mb-4 text-2xl font-bold">Features</h2>
            <ul class="grid grid-cols-2 gap-2">
              {property.features.map((feature) => (
                <li class="flex items-center gap-2">
                  <svg class="h-5 w-5 text-primary" /* checkmark icon */ />
                  <span>{feature}</span>
                </li>
              ))}
            </ul>
          </div>
        )}

        <!-- Map (React Island - hydrates when visible) -->
        <div class="mt-8">
          <h2 class="mb-4 text-2xl font-bold">Location</h2>
          <PropertyMap 
            client:visible 
            latitude={property.latitude}
            longitude={property.longitude}
            title={property.title}
          />
        </div>
      </div>

      <!-- Sidebar -->
      <aside class="lg:col-span-1">
        <div class="sticky top-4 rounded-lg bg-muted p-6">
          <h3 class="mb-4 text-xl font-bold">Interested?</h3>
          
          <!-- Contact Form (React Island - hydrates when visible) -->
          <ContactForm 
            client:visible 
            propertyId={property.id}
            propertyTitle={property.title}
          />
        </div>
      </aside>
    </div>
  </article>
</PageLayout>
```

---

## Component Architecture

### Astro Components (Static, Zero JS)

```astro
---
// src/components/astro/PropertyCard.astro
import type { Property } from '@/types/property';
import { formatPrice, formatArea } from '@/lib/utils/formatters';

interface Props {
  property: Property;
}

const { property } = Astro.props;
const mainImage = property.prop_photos[0]?.image || '/placeholder.jpg';
---

<a 
  href={`/properties/${property.slug}`}
  class="group block overflow-hidden rounded-lg border border-border bg-card transition hover:shadow-lg"
>
  <div class="aspect-video overflow-hidden">
    <img 
      src={mainImage} 
      alt={property.title}
      class="h-full w-full object-cover transition group-hover:scale-105"
      loading="lazy"
    />
  </div>
  <div class="p-4">
    <h3 class="mb-2 text-xl font-semibold group-hover:text-primary">
      {property.title}
    </h3>
    <p class="mb-2 font-bold text-primary">
      {formatPrice(property.price_sale_current_cents, property.currency)}
    </p>
    <p class="text-sm text-muted-foreground">
      {property.count_bedrooms} beds • {property.count_bathrooms} baths • 
      {formatArea(property.constructed_area, property.area_unit)}
    </p>
  </div>
</a>
```

```astro
---
// src/components/astro/Header.astro
import { getSiteDetails, getNavigationLinks } from '@/lib/api/site';
import LanguageSwitcher from '@/components/react/LanguageSwitcher';

interface Props {
  locale?: string;
}

const { locale = 'en' } = Astro.props;

const [siteDetails, navLinks] = await Promise.all([
  getSiteDetails(),
  getNavigationLinks('top_nav'),
]);

const visibleLinks = navLinks.filter((link) => link.visible).sort((a, b) => a.order - b.order);
---

<header class="sticky top-0 z-50 border-b border-border bg-background/95 backdrop-blur">
  <div class="container mx-auto flex items-center justify-between px-4 py-4">
    <!-- Logo -->
    <a href="/" class="flex items-center gap-2">
      {siteDetails.logo_url && (
        <img src={siteDetails.logo_url} alt={siteDetails.name} class="h-10" />
      )}
      <span class="text-xl font-bold">{siteDetails.name}</span>
    </a>

    <!-- Navigation -->
    <nav class="hidden md:flex items-center gap-6">
      {visibleLinks.map((link) => (
        <a 
          href={link.url}
          class="font-medium transition hover:text-primary"
          target={link.external ? '_blank' : undefined}
          rel={link.external ? 'noopener noreferrer' : undefined}
        >
          {link.title}
        </a>
      ))}
    </nav>

    <!-- Language Switcher (React Island) -->
    <LanguageSwitcher client:load currentLocale={locale} />
  </div>
</header>
```

### React Islands (Interactive Components)

```tsx
// src/components/react/SearchFilters.tsx
import { useState } from 'react';
import { useRouter } from 'next/router'; // Or custom routing
import type { PropertySearchParams } from '@/types/property';

interface SearchFiltersProps {
  initialParams?: Partial<PropertySearchParams>;
}

export default function SearchFilters({ initialParams = {} }: SearchFiltersProps) {
  const [params, setParams] = useState<Partial<PropertySearchParams>>(initialParams);

  const handleSearch = () => {
    const queryString = new URLSearchParams(
      Object.entries(params)
        .filter(([_, value]) => value !== undefined)
        .map(([key, value]) => [key, String(value)])
    ).toString();

    window.location.href = `/properties?${queryString}`;
  };

  return (
    <div className="rounded-lg bg-white p-6 shadow-lg">
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        {/* Sale/Rental Filter */}
        <select
          value={params.sale_or_rental || ''}
          onChange={(e) => setParams({ ...params, sale_or_rental: e.target.value as 'sale' | 'rental' })}
          className="rounded-md border border-gray-300 px-4 py-2"
        >
          <option value="">Sale or Rental</option>
          <option value="sale">For Sale</option>
          <option value="rental">For Rent</option>
        </select>

        {/* Property Type */}
        <select
          value={params.property_type || ''}
          onChange={(e) => setParams({ ...params, property_type: e.target.value })}
          className="rounded-md border border-gray-300 px-4 py-2"
        >
          <option value="">Property Type</option>
          <option value="house">House</option>
          <option value="apartment">Apartment</option>
          <option value="villa">Villa</option>
        </select>

        {/* Bedrooms */}
        <select
          value={params.bedrooms_from || ''}
          onChange={(e) => setParams({ ...params, bedrooms_from: parseInt(e.target.value) })}
          className="rounded-md border border-gray-300 px-4 py-2"
        >
          <option value="">Bedrooms</option>
          <option value="1">1+</option>
          <option value="2">2+</option>
          <option value="3">3+</option>
          <option value="4">4+</option>
        </select>

        {/* Search Button */}
        <button
          onClick={handleSearch}
          className="rounded-md bg-primary px-6 py-2 font-semibold text-primary-foreground hover:bg-primary/90"
        >
          Search
        </button>
      </div>
    </div>
  );
}
```

```tsx
// src/components/react/PropertyGallery.tsx
import { useState } from 'react';
import type { PropertyPhoto } from '@/types/property';

interface PropertyGalleryProps {
  images: PropertyPhoto[];
  alt: string;
}

export default function PropertyGallery({ images, alt }: PropertyGalleryProps) {
  const [selectedIndex, setSelectedIndex] = useState(0);

  if (!images || images.length === 0) {
    return <div className="aspect-video bg-gray-200" />;
  }

  return (
    <div className="space-y-4">
      {/* Main Image */}
      <div className="aspect-video overflow-hidden rounded-lg">
        <img
          src={images[selectedIndex].image}
          alt={`${alt} - Image ${selectedIndex + 1}`}
          className="h-full w-full object-cover"
        />
      </div>

      {/* Thumbnails */}
      <div className="grid grid-cols-5 gap-2">
        {images.map((photo, index) => (
          <button
            key={photo.id}
            onClick={() => setSelectedIndex(index)}
            className={`aspect-video overflow-hidden rounded border-2 ${
              index === selectedIndex ? 'border-primary' : 'border-transparent'
            }`}
          >
            <img
              src={photo.thumbnail || photo.image}
              alt={`${alt} - Thumbnail ${index + 1}`}
              className="h-full w-full object-cover"
            />
          </button>
        ))}
      </div>
    </div>
  );
}
```

```tsx
// src/components/react/PropertyMap.tsx
import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

interface PropertyMapProps {
  latitude: number;
  longitude: number;
  title: string;
}

export default function PropertyMap({ latitude, longitude, title }: PropertyMapProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return;

    // Initialize map
    const map = L.map(mapRef.current).setView([latitude, longitude], 15);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
    }).addTo(map);

    L.marker([latitude, longitude]).addTo(map).bindPopup(title);

    mapInstanceRef.current = map;

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
  }, [latitude, longitude, title]);

  return <div ref={mapRef} className="h-96 w-full rounded-lg" />;
}
```

---

## SEO Implementation

### Dynamic Sitemap

```typescript
// src/pages/sitemap.xml.ts
import type { APIRoute } from 'astro';
import { getAllPropertySlugs } from '@/lib/api/properties';

const SITE_URL = import.meta.env.PUBLIC_SITE_URL || 'https://example.com';

export const GET: APIRoute = async () => {
  const propertySlugs = await getAllPropertySlugs();

  const propertyUrls = propertySlugs.map((slug) => ({
    url: `${SITE_URL}/properties/${slug}`,
    lastmod: new Date().toISOString(),
    changefreq: 'daily',
    priority: 0.8,
  }));

  const staticUrls = [
    { url: SITE_URL, lastmod: new Date().toISOString(), changefreq: 'daily', priority: 1.0 },
    { url: `${SITE_URL}/properties`, lastmod: new Date().toISOString(), changefreq: 'daily', priority: 0.9 },
    { url: `${SITE_URL}/about`, lastmod: new Date().toISOString(), changefreq: 'monthly', priority: 0.5 },
    { url: `${SITE_URL}/contact`, lastmod: new Date().toISOString(), changefreq: 'monthly', priority: 0.5 },
  ];

  const allUrls = [...staticUrls, ...propertyUrls];

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${allUrls
    .map(
      (url) => `
    <url>
      <loc>${url.url}</loc>
      <lastmod>${url.lastmod}</lastmod>
      <changefreq>${url.changefreq}</changefreq>
      <priority>${url.priority}</priority>
    </url>`
    )
    .join('')}
</urlset>`;

  return new Response(sitemap, {
    headers: {
      'Content-Type': 'application/xml',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
```

### Robots.txt

```typescript
// src/pages/robots.txt.ts
import type { APIRoute } from 'astro';

const SITE_URL = import.meta.env.PUBLIC_SITE_URL || 'https://example.com';

export const GET: APIRoute = () => {
  const robots = `User-agent: *
Allow: /

Sitemap: ${SITE_URL}/sitemap.xml
`;

  return new Response(robots, {
    headers: {
      'Content-Type': 'text/plain',
    },
  });
};
```

### Structured Data Component

```astro
---
// src/components/astro/PropertySchema.astro
import type { Property } from '@/types/property';

interface Props {
  property: Property;
}

const { property } = Astro.props;

const schema = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: property.title,
  description: property.description,
  image: property.prop_photos.map((p) => p.image),
  offers: {
    '@type': 'Offer',
    price: property.price_sale_current_cents / 100,
    priceCurrency: property.currency,
    availability: 'https://schema.org/InStock',
  },
  address: {
    '@type': 'PostalAddress',
    addressLocality: property.city,
    addressCountry: property.country,
  },
};
---

<script type="application/ld+json" set:html={JSON.stringify(schema)}></script>
```

---

## Theming System

### Dynamic Theme Injection

```astro
---
// src/components/astro/ThemeStyles.astro
import { getTheme } from '@/lib/api/site';

const theme = await getTheme();

// Convert theme object to CSS custom properties
const cssVariables = `
  :root {
    --primary: ${theme.colors.primary};
    --primary-foreground: ${theme.colors.primary_foreground || '#ffffff'};
    --secondary: ${theme.colors.secondary || theme.colors.primary};
    --background: ${theme.colors.background || '#ffffff'};
    --foreground: ${theme.colors.foreground || '#000000'};
    --muted: ${theme.colors.muted || '#f3f4f6'};
    --accent: ${theme.colors.accent || theme.colors.primary};
    --border: ${theme.colors.border || '#e5e7eb'};
  }
  
  ${theme.customCss || ''}
`;
---

<style is:global set:html={cssVariables}></style>
```

---

## Internationalization

### i18n Setup

```astro
---
// src/pages/[locale]/index.astro
import PageLayout from '@/layouts/PageLayout.astro';
import { getTranslations } from '@/lib/api/site';

export function getStaticPaths() {
  return [
    { params: { locale: 'en' } },
    { params: { locale: 'es' } },
    { params: { locale: 'ru' } },
  ];
}

const { locale } = Astro.params;
const t = await getTranslations(locale);
---

<PageLayout title={t['Home.title']} locale={locale}>
  <h1>{t['Home.welcome']}</h1>
</PageLayout>
```

---

## Performance Optimization

### Image Optimization

```astro
---
// Use Astro's built-in Image component
import { Image } from 'astro:assets';
---

<Image
  src={property.prop_photos[0].image}
  alt={property.title}
  width={800}
  height={600}
  format="webp"
  quality={80}
  loading="lazy"
/>
```

### Code Splitting Strategy

```astro
---
// Heavy components only load when needed
import PropertyMap from '@/components/react/PropertyMap';
---

<!-- Only hydrates when component enters viewport -->
<PropertyMap client:visible latitude={lat} longitude={lng} />
```

### Client Directives

- `client:load` - Hydrate immediately on page load
- `client:idle` - Hydrate when browser is idle
- `client:visible` - Hydrate when component enters viewport
- `client:media` - Hydrate based on media query
- `client:only` - Only render on client (skip SSR)

---

## Dokku Deployment

### Dockerfile

```dockerfile
# Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci

# Copy source
COPY . .

# Build args for environment
ARG PUBLIC_API_URL
ARG PUBLIC_SITE_URL
ARG THEME=default

ENV PUBLIC_API_URL=$PUBLIC_API_URL
ENV PUBLIC_SITE_URL=$PUBLIC_SITE_URL
ENV THEME=$THEME

# Build
RUN npm run build

# Production image
FROM node:20-alpine AS runner

WORKDIR /app

# Copy built files
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

ENV HOST=0.0.0.0
ENV PORT=4321

EXPOSE 4321

CMD ["node", "./dist/server/entry.mjs"]
```

### Dokku Health Check

```
# .dokku/CHECKS
WAIT=5
ATTEMPTS=10
/  200
```

### Deployment Commands

```bash
# On VPS with Dokku installed

# Create app
dokku apps:create client-luxury

# Set environment variables
dokku config:set client-luxury \
  PUBLIC_API_URL=https://api.yourpwb.com \
  PUBLIC_SITE_URL=https://luxury.yoursite.com \
  THEME=luxury

# Set domain
dokku domains:set client-luxury luxury.yoursite.com

# Enable SSL
dokku letsencrypt:enable client-luxury

# Deploy from Git
git remote add dokku-luxury dokku@your-vps:client-luxury
git push dokku-luxury main

# Or deploy via Docker
docker build -t client-luxury \
  --build-arg PUBLIC_API_URL=https://api.yourpwb.com \
  --build-arg THEME=luxury .
docker tag client-luxury dokku/client-luxury:latest
dokku tags:deploy client-luxury latest
```

---

## Multi-Tenant Setup

### Approach: Single Codebase, Multiple Deployments

```bash
# Deploy client 1 (Luxury theme)
dokku apps:create client-luxury
dokku config:set client-luxury THEME=luxury PUBLIC_API_URL=https://client1.api.com
git push dokku-luxury main

# Deploy client 2 (Modern theme)
dokku apps:create client-modern
dokku config:set client-modern THEME=modern PUBLIC_API_URL=https://client2.api.com
git push dokku-modern main

# Deploy client 3 (Minimal theme)
dokku apps:create client-minimal
dokku config:set client-minimal THEME=minimal PUBLIC_API_URL=https://client3.api.com
git push dokku-minimal main
```

---

## Development Workflow

### Local Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Scripts in package.json

```json
{
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "check": "astro check",
    "lint": "eslint . --ext .js,.jsx,.ts,.tsx,.astro",
    "format": "prettier --write ."
  }
}
```

---

## Comparison with Next.js

### When to Choose Astro

✅ **Choose Astro if:**
- Performance/Lighthouse scores are critical (aim for 100/100/100/100)
- Site is mostly content (80%+) with selective interactivity
- You want minimal JavaScript shipped to users
- SEO is absolutely critical
- Budget is tight (cheaper hosting)
- Team prefers simpler mental model

### When to Choose Next.js

✅ **Choose Next.js if:**
- Need rich SPA-like interactivity throughout
- Want best-in-class ecosystem (Shadcn/ui, etc.)
- Team already knows React deeply
- Need complex client-side state management
- Easier to find developers
- Want first-party Vercel deployment

### Performance Comparison

| Metric | Astro | Next.js |
|--------|-------|---------|
| Initial Bundle Size | ~50KB | ~150KB |
| Time to Interactive | 0.5-1s | 1-2s |
| Lighthouse Performance | 100 | 90-95 |
| Lighthouse SEO | 100 | 100 |
| First Contentful Paint | < 0.5s | < 1s |

---

## Summary

### Astro Advantages for PWB

1. ✅ **Best Performance** - Zero JS by default
2. ✅ **Perfect SEO** - 100/100 Lighthouse scores achievable
3. ✅ **Simple Mental Model** - Like ERB/Liquid templates
4. ✅ **Framework Flexible** - Use React where needed
5. ✅ **Lower Costs** - Smaller bundles = cheaper hosting

### Implementation Timeline

- **Week 1-2**: Setup + Base layouts + API integration
- **Week 3-4**: Core pages (Homepage, Properties, Property Detail)
- **Week 5**: SEO + Performance optimization
- **Week 6**: Theming system + i18n
- **Week 7**: Deployment + Multi-tenant setup
- **Week 8**: Testing + Documentation

**Total**: 8 weeks to production-ready

### Next Steps

1. ✅ Review this plan
2. ⏭️ Initialize Astro project
3. ⏭️ Set up API integration
4. ⏭️ Build core pages
5. ⏭️ Deploy POC to Dokku
6. ⏭️ Measure performance
7. ⏭️ Compare with Next.js POC (if built)
8. ⏭️ Make final framework decision

---

**Ready to start? Create your first Astro project:**

```bash
npm create astro@latest pwb-astro-client
cd pwb-astro-client
npm install
npm run dev
```

**Happy building! 🚀**
