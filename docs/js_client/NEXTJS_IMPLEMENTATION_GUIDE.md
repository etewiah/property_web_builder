# Next.js Implementation Guide for PropertyWebBuilder

**Created**: 2026-01-10
**Status**: Ready for Implementation
**Target**: VPS deployment with Dokku

---

## Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Environment Setup](#environment-setup)
4. [API Integration](#api-integration)
5. [Page Implementation](#page-implementation)
6. [SEO Implementation](#seo-implementation)
7. [Theming System](#theming-system)
8. [Internationalization](#internationalization)
9. [Dokku Deployment](#dokku-deployment)
10. [Multi-Tenant Setup](#multi-tenant-setup)
11. [Development Workflow](#development-workflow)
12. [Troubleshooting](#troubleshooting)

---

## Overview

### Architecture

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
│  │ (Next.js)│    │ (Next.js)│    │ (Next.js)│              │
│  │ Port 5000│    │ Port 5001│    │ Port 500n│              │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘              │
│       │               │               │                     │
│       └───────────────┼───────────────┘                     │
│                       ▼                                      │
│              ┌────────────────┐                             │
│              │   PWB Rails    │                             │
│              │   API Server   │                             │
│              │ (Same or Ext)  │                             │
│              └────────────────┘                             │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| Framework | Next.js | 14.x | React framework with SSR/SSG |
| Language | TypeScript | 5.x | Type safety |
| Styling | Tailwind CSS | 3.4.x | Utility-first CSS |
| Components | shadcn/ui | latest | Accessible UI components |
| Data Fetching | TanStack Query | 5.x | Client-side caching |
| Forms | React Hook Form + Zod | 7.x + 3.x | Form handling + validation |
| i18n | next-intl | 3.x | Internationalization |
| Maps | Leaflet + react-leaflet | 4.x | Property maps |
| Deployment | Dokku | 0.33.x | PaaS on VPS |

---

## Project Structure

```
pwb-nextjs-client/
├── .dokku/                        # Dokku configuration
│   └── CHECKS                     # Health check configuration
├── app/                           # Next.js App Router
│   ├── [locale]/                  # i18n routes
│   │   ├── layout.tsx             # Locale-specific layout
│   │   ├── page.tsx               # Homepage
│   │   ├── properties/
│   │   │   ├── page.tsx           # Property search (SSR)
│   │   │   └── [slug]/
│   │   │       └── page.tsx       # Property details (ISR)
│   │   ├── about/
│   │   │   └── page.tsx           # About page (SSG)
│   │   └── contact/
│   │       └── page.tsx           # Contact page (SSG)
│   ├── api/                       # API routes (if needed)
│   │   └── revalidate/
│   │       └── route.ts           # On-demand revalidation
│   ├── layout.tsx                 # Root layout
│   ├── not-found.tsx              # 404 page
│   ├── error.tsx                  # Error boundary
│   ├── robots.ts                  # robots.txt generation
│   └── sitemap.ts                 # Sitemap generation
├── components/
│   ├── ui/                        # shadcn/ui components
│   │   ├── button.tsx
│   │   ├── card.tsx
│   │   ├── input.tsx
│   │   └── ...
│   ├── property/                  # Property components
│   │   ├── property-card.tsx
│   │   ├── property-gallery.tsx
│   │   ├── property-details.tsx
│   │   ├── property-search.tsx
│   │   ├── property-filters.tsx
│   │   └── property-map.tsx
│   ├── layout/                    # Layout components
│   │   ├── header.tsx
│   │   ├── footer.tsx
│   │   ├── navigation.tsx
│   │   └── mobile-nav.tsx
│   └── shared/                    # Shared components
│       ├── contact-form.tsx
│       ├── page-hero.tsx
│       ├── testimonials.tsx
│       └── cta-section.tsx
├── lib/
│   ├── api/                       # PWB API client
│   │   ├── client.ts              # Base API client
│   │   ├── properties.ts          # Property endpoints
│   │   ├── pages.ts               # Pages endpoints
│   │   ├── site.ts                # Site config endpoints
│   │   └── types.ts               # API response types
│   ├── utils/
│   │   ├── format-price.ts        # Price formatting
│   │   ├── format-area.ts         # Area formatting
│   │   └── cn.ts                  # className utility
│   └── hooks/
│       ├── use-properties.ts      # Properties query hook
│       └── use-site-config.ts     # Site config hook
├── config/
│   ├── site.ts                    # Site configuration
│   ├── navigation.ts              # Navigation config
│   └── i18n.ts                    # i18n configuration
├── messages/                      # i18n translations
│   ├── en.json
│   ├── es.json
│   └── ...
├── public/
│   ├── images/
│   └── fonts/
├── styles/
│   ├── globals.css                # Global styles
│   └── themes/
│       ├── variables.css          # CSS custom properties
│       └── components.css         # Component overrides
├── types/
│   ├── property.ts                # Property types
│   ├── page.ts                    # Page types
│   └── api.ts                     # API types
├── .env.example                   # Environment template
├── .env.local                     # Local development
├── Dockerfile                     # Docker build
├── docker-compose.yml             # Local development
├── next.config.js                 # Next.js config
├── tailwind.config.ts             # Tailwind config
├── tsconfig.json                  # TypeScript config
├── package.json                   # Dependencies
└── Procfile                       # Dokku process file
```

---

## Environment Setup

### Prerequisites

- Node.js 20.x LTS
- pnpm (recommended) or npm
- Git

### Initial Setup

```bash
# Create project
npx create-next-app@latest pwb-nextjs-client --typescript --tailwind --eslint --app --src-dir=false

cd pwb-nextjs-client

# Install dependencies
pnpm add @tanstack/react-query axios zod react-hook-form @hookform/resolvers
pnpm add next-intl leaflet react-leaflet
pnpm add class-variance-authority clsx tailwind-merge
pnpm add @radix-ui/react-slot @radix-ui/react-dialog @radix-ui/react-dropdown-menu
pnpm add lucide-react

# Dev dependencies
pnpm add -D @types/leaflet prettier prettier-plugin-tailwindcss

# Initialize shadcn/ui
npx shadcn-ui@latest init
```

### Environment Variables

Create `.env.local`:

```bash
# PWB API Configuration
NEXT_PUBLIC_API_URL=https://api.yourpwbsite.com
PWB_API_URL=https://api.yourpwbsite.com  # Server-side only

# Site Configuration
NEXT_PUBLIC_SITE_NAME="Example Real Estate"
NEXT_PUBLIC_SITE_URL=https://example.com
NEXT_PUBLIC_DEFAULT_LOCALE=en

# Revalidation (ISR)
REVALIDATION_SECRET=your-secret-token

# Maps
NEXT_PUBLIC_MAPBOX_TOKEN=pk.xxx  # Optional, for Mapbox
NEXT_PUBLIC_DEFAULT_LAT=40.4168
NEXT_PUBLIC_DEFAULT_LNG=-3.7038
NEXT_PUBLIC_DEFAULT_ZOOM=12

# Analytics (optional)
NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX

# Theme
NEXT_PUBLIC_THEME=default
```

---

## API Integration

### Base API Client

```typescript
// lib/api/client.ts
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';

const API_URL = process.env.PWB_API_URL || process.env.NEXT_PUBLIC_API_URL;

class ApiClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: `${API_URL}/api_public/v1`,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      timeout: 10000,
    });
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

export const apiClient = new ApiClient();
```

### Property API

```typescript
// lib/api/properties.ts
import { apiClient } from './client';
import { Property, PropertySearchParams, PropertySearchResponse } from './types';

export async function getProperties(params: PropertySearchParams = {}): Promise<PropertySearchResponse> {
  const searchParams = new URLSearchParams();

  if (params.saleOrRental) searchParams.set('sale_or_rental', params.saleOrRental);
  if (params.propertyType) searchParams.set('property_type', params.propertyType);
  if (params.minPrice) searchParams.set('for_sale_price_from', params.minPrice.toString());
  if (params.maxPrice) searchParams.set('for_sale_price_till', params.maxPrice.toString());
  if (params.minBedrooms) searchParams.set('bedrooms_from', params.minBedrooms.toString());
  if (params.minBathrooms) searchParams.set('bathrooms_from', params.minBathrooms.toString());
  if (params.locale) searchParams.set('locale', params.locale);
  if (params.page) searchParams.set('page', params.page.toString());
  if (params.perPage) searchParams.set('per_page', params.perPage.toString());

  return apiClient.get<PropertySearchResponse>(`/properties?${searchParams.toString()}`);
}

export async function getProperty(idOrSlug: string, locale?: string): Promise<Property> {
  const params = locale ? `?locale=${locale}` : '';
  return apiClient.get<Property>(`/properties/${idOrSlug}${params}`);
}

export async function getAllPropertySlugs(): Promise<string[]> {
  // Fetch all properties for static generation
  const response = await apiClient.get<Property[]>('/properties?per_page=1000');
  return response.map(p => p.slug || p.id.toString());
}
```

### Types

```typescript
// lib/api/types.ts
export interface Property {
  id: number;
  slug?: string;
  title: string;
  description: string;
  price_sale_current_cents?: number;
  price_rental_monthly_current_cents?: number;
  currency: string;
  area_unit: string;
  constructed_area?: number;
  plot_area?: number;
  count_bedrooms?: number;
  count_bathrooms?: number;
  count_garages?: number;
  for_sale: boolean;
  for_rent: boolean;
  latitude?: number;
  longitude?: number;
  address?: string;
  city?: string;
  region?: string;
  country?: string;
  property_type?: string;
  features?: string[];
  prop_photos: PropertyPhoto[];
  created_at: string;
  updated_at: string;
}

export interface PropertyPhoto {
  id: number;
  image: string;
  image_url?: string;
  thumbnail_url?: string;
  position: number;
}

export interface PropertySearchParams {
  saleOrRental?: 'sale' | 'rental';
  propertyType?: string;
  minPrice?: number;
  maxPrice?: number;
  minBedrooms?: number;
  minBathrooms?: number;
  city?: string;
  locale?: string;
  page?: number;
  perPage?: number;
}

export interface PropertySearchResponse {
  properties: Property[];
  meta: {
    total: number;
    page: number;
    per_page: number;
    total_pages: number;
  };
}

export interface SiteConfig {
  name: string;
  logo_url?: string;
  primary_color?: string;
  secondary_color?: string;
  contact_email?: string;
  contact_phone?: string;
  address?: string;
  social_links?: {
    facebook?: string;
    twitter?: string;
    instagram?: string;
    linkedin?: string;
  };
  default_currency: string;
  default_area_unit: string;
  locales: string[];
  default_locale: string;
}

export interface Page {
  id: number;
  slug: string;
  title: string;
  content: string;
  meta_title?: string;
  meta_description?: string;
  page_parts: PagePart[];
}

export interface PagePart {
  key: string;
  part_type: string;
  content: Record<string, unknown>;
  position: number;
}

export interface NavLink {
  id: number;
  label: string;
  url: string;
  position: string;
  order: number;
  children?: NavLink[];
}
```

---

## Page Implementation

### Homepage (SSG with ISR)

```typescript
// app/[locale]/page.tsx
import { Suspense } from 'react';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { getProperties } from '@/lib/api/properties';
import { getSiteConfig } from '@/lib/api/site';
import { getPage } from '@/lib/api/pages';
import { PageHero } from '@/components/shared/page-hero';
import { PropertyGrid } from '@/components/property/property-grid';
import { CTASection } from '@/components/shared/cta-section';
import { PropertyGridSkeleton } from '@/components/property/property-grid-skeleton';

interface Props {
  params: { locale: string };
}

// Revalidate every hour
export const revalidate = 3600;

export async function generateMetadata({ params: { locale } }: Props) {
  const t = await getTranslations({ locale, namespace: 'Home' });
  const siteConfig = await getSiteConfig();

  return {
    title: t('meta.title', { siteName: siteConfig.name }),
    description: t('meta.description'),
    openGraph: {
      title: t('meta.title', { siteName: siteConfig.name }),
      description: t('meta.description'),
      type: 'website',
      locale,
    },
  };
}

export default async function HomePage({ params: { locale } }: Props) {
  unstable_setRequestLocale(locale);

  const t = await getTranslations('Home');

  // Parallel data fetching
  const [page, featuredProperties] = await Promise.all([
    getPage('home', locale),
    getProperties({ locale, perPage: 6 }),
  ]);

  const heroContent = page.page_parts.find(p => p.part_type === 'hero');

  return (
    <main>
      {/* Hero Section */}
      <PageHero
        title={heroContent?.content.title as string || t('hero.title')}
        subtitle={heroContent?.content.subtitle as string || t('hero.subtitle')}
        backgroundImage={heroContent?.content.background_image as string}
        showSearch
      />

      {/* Featured Properties */}
      <section className="py-16 px-4">
        <div className="container mx-auto">
          <h2 className="text-3xl font-bold mb-8 text-center">
            {t('featured.title')}
          </h2>
          <Suspense fallback={<PropertyGridSkeleton count={6} />}>
            <PropertyGrid properties={featuredProperties.properties} />
          </Suspense>
        </div>
      </section>

      {/* CTA Section */}
      <CTASection
        title={t('cta.title')}
        description={t('cta.description')}
        buttonText={t('cta.button')}
        buttonHref="/contact"
      />
    </main>
  );
}
```

### Property Search Page (SSR)

```typescript
// app/[locale]/properties/page.tsx
import { Suspense } from 'react';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { getProperties } from '@/lib/api/properties';
import { PropertyGrid } from '@/components/property/property-grid';
import { PropertyFilters } from '@/components/property/property-filters';
import { Pagination } from '@/components/ui/pagination';

interface Props {
  params: { locale: string };
  searchParams: {
    sale_or_rental?: string;
    property_type?: string;
    min_price?: string;
    max_price?: string;
    bedrooms?: string;
    page?: string;
  };
}

// Force dynamic rendering (SSR)
export const dynamic = 'force-dynamic';

export async function generateMetadata({ params: { locale }, searchParams }: Props) {
  const t = await getTranslations({ locale, namespace: 'Properties' });

  return {
    title: t('meta.title'),
    description: t('meta.description'),
  };
}

export default async function PropertiesPage({ params: { locale }, searchParams }: Props) {
  unstable_setRequestLocale(locale);

  const t = await getTranslations('Properties');

  const properties = await getProperties({
    locale,
    saleOrRental: searchParams.sale_or_rental as 'sale' | 'rental' | undefined,
    propertyType: searchParams.property_type,
    minPrice: searchParams.min_price ? parseInt(searchParams.min_price) : undefined,
    maxPrice: searchParams.max_price ? parseInt(searchParams.max_price) : undefined,
    minBedrooms: searchParams.bedrooms ? parseInt(searchParams.bedrooms) : undefined,
    page: searchParams.page ? parseInt(searchParams.page) : 1,
    perPage: 12,
  });

  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-4xl font-bold mb-8">{t('title')}</h1>

      <div className="grid lg:grid-cols-4 gap-8">
        {/* Filters Sidebar */}
        <aside className="lg:col-span-1">
          <PropertyFilters currentFilters={searchParams} />
        </aside>

        {/* Property Grid */}
        <div className="lg:col-span-3">
          <div className="mb-4 text-muted-foreground">
            {t('resultsCount', { count: properties.meta.total })}
          </div>

          <PropertyGrid properties={properties.properties} />

          {properties.meta.total_pages > 1 && (
            <Pagination
              currentPage={properties.meta.page}
              totalPages={properties.meta.total_pages}
              className="mt-8"
            />
          )}
        </div>
      </div>
    </main>
  );
}
```

### Property Detail Page (ISR)

```typescript
// app/[locale]/properties/[slug]/page.tsx
import { notFound } from 'next/navigation';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { getProperty, getAllPropertySlugs } from '@/lib/api/properties';
import { PropertyGallery } from '@/components/property/property-gallery';
import { PropertyDetails } from '@/components/property/property-details';
import { PropertyMap } from '@/components/property/property-map';
import { ContactForm } from '@/components/shared/contact-form';
import { PropertySchema } from '@/components/seo/property-schema';

interface Props {
  params: { locale: string; slug: string };
}

// Revalidate every hour
export const revalidate = 3600;

// Generate static params for all properties
export async function generateStaticParams() {
  const slugs = await getAllPropertySlugs();
  const locales = ['en', 'es']; // Add your locales

  return locales.flatMap(locale =>
    slugs.map(slug => ({ locale, slug }))
  );
}

export async function generateMetadata({ params: { locale, slug } }: Props) {
  try {
    const property = await getProperty(slug, locale);

    return {
      title: `${property.title} | ${property.city || 'Property'}`,
      description: property.description?.slice(0, 160),
      openGraph: {
        title: property.title,
        description: property.description?.slice(0, 160),
        images: property.prop_photos[0]?.image_url ? [property.prop_photos[0].image_url] : [],
        type: 'website',
        locale,
      },
    };
  } catch {
    return {
      title: 'Property Not Found',
    };
  }
}

export default async function PropertyPage({ params: { locale, slug } }: Props) {
  unstable_setRequestLocale(locale);

  const t = await getTranslations('Property');

  let property;
  try {
    property = await getProperty(slug, locale);
  } catch {
    notFound();
  }

  return (
    <>
      {/* JSON-LD Structured Data */}
      <PropertySchema property={property} />

      <main className="container mx-auto px-4 py-8">
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Main Content */}
          <div className="lg:col-span-2">
            {/* Gallery */}
            <PropertyGallery photos={property.prop_photos} />

            {/* Details */}
            <PropertyDetails property={property} />

            {/* Map */}
            {property.latitude && property.longitude && (
              <section className="mt-8">
                <h2 className="text-2xl font-bold mb-4">{t('location')}</h2>
                <PropertyMap
                  lat={property.latitude}
                  lng={property.longitude}
                  className="h-[400px] rounded-lg"
                />
              </section>
            )}
          </div>

          {/* Sidebar */}
          <aside className="lg:col-span-1">
            <div className="sticky top-24 space-y-6">
              {/* Price Card */}
              <div className="bg-card p-6 rounded-lg shadow-lg">
                <div className="text-3xl font-bold text-primary">
                  {formatPrice(
                    property.for_sale
                      ? property.price_sale_current_cents
                      : property.price_rental_monthly_current_cents,
                    property.currency
                  )}
                  {property.for_rent && <span className="text-lg font-normal">/month</span>}
                </div>
              </div>

              {/* Contact Form */}
              <div className="bg-card p-6 rounded-lg shadow-lg">
                <h3 className="text-xl font-bold mb-4">{t('contactAgent')}</h3>
                <ContactForm propertyId={property.id} />
              </div>
            </div>
          </aside>
        </div>
      </main>
    </>
  );
}
```

---

## SEO Implementation

### Sitemap Generation

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next';
import { getAllPropertySlugs } from '@/lib/api/properties';
import { locales, defaultLocale } from '@/config/i18n';

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://example.com';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const propertySlugs = await getAllPropertySlugs();

  const staticPages = ['', '/properties', '/about', '/contact'];

  // Static pages for each locale
  const staticUrls = staticPages.flatMap(page =>
    locales.map(locale => ({
      url: `${BASE_URL}/${locale}${page}`,
      lastModified: new Date(),
      changeFrequency: page === '' ? 'daily' : 'weekly' as const,
      priority: page === '' ? 1 : 0.8,
      alternates: {
        languages: Object.fromEntries(
          locales.map(l => [l, `${BASE_URL}/${l}${page}`])
        ),
      },
    }))
  );

  // Property pages for each locale
  const propertyUrls = propertySlugs.flatMap(slug =>
    locales.map(locale => ({
      url: `${BASE_URL}/${locale}/properties/${slug}`,
      lastModified: new Date(),
      changeFrequency: 'daily' as const,
      priority: 0.9,
      alternates: {
        languages: Object.fromEntries(
          locales.map(l => [l, `${BASE_URL}/${l}/properties/${slug}`])
        ),
      },
    }))
  );

  return [...staticUrls, ...propertyUrls];
}
```

### Robots.txt

```typescript
// app/robots.ts
import { MetadataRoute } from 'next';

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://example.com';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/', '/admin/'],
      },
    ],
    sitemap: `${BASE_URL}/sitemap.xml`,
  };
}
```

### JSON-LD Schema

```typescript
// components/seo/property-schema.tsx
import { Property } from '@/lib/api/types';

interface Props {
  property: Property;
}

export function PropertySchema({ property }: Props) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'RealEstateListing',
    name: property.title,
    description: property.description,
    image: property.prop_photos.map(p => p.image_url || p.image),
    url: `${process.env.NEXT_PUBLIC_SITE_URL}/properties/${property.slug || property.id}`,
    datePosted: property.created_at,
    dateModified: property.updated_at,
    offers: {
      '@type': 'Offer',
      price: property.for_sale
        ? (property.price_sale_current_cents || 0) / 100
        : (property.price_rental_monthly_current_cents || 0) / 100,
      priceCurrency: property.currency,
      availability: 'https://schema.org/InStock',
    },
    address: property.address ? {
      '@type': 'PostalAddress',
      streetAddress: property.address,
      addressLocality: property.city,
      addressRegion: property.region,
      addressCountry: property.country,
    } : undefined,
    geo: property.latitude && property.longitude ? {
      '@type': 'GeoCoordinates',
      latitude: property.latitude,
      longitude: property.longitude,
    } : undefined,
    numberOfRooms: property.count_bedrooms,
    numberOfBathroomsTotal: property.count_bathrooms,
    floorSize: property.constructed_area ? {
      '@type': 'QuantitativeValue',
      value: property.constructed_area,
      unitCode: property.area_unit === 'sqft' ? 'FTK' : 'MTK',
    } : undefined,
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}
```

---

## Theming System

### CSS Custom Properties

```css
/* styles/themes/variables.css */
:root {
  /* Colors */
  --color-primary: 220 90% 56%;
  --color-primary-foreground: 0 0% 100%;
  --color-secondary: 220 14% 96%;
  --color-secondary-foreground: 220 9% 46%;
  --color-accent: 220 14% 96%;
  --color-accent-foreground: 220 9% 46%;
  --color-background: 0 0% 100%;
  --color-foreground: 222 47% 11%;
  --color-muted: 220 14% 96%;
  --color-muted-foreground: 220 9% 46%;
  --color-card: 0 0% 100%;
  --color-card-foreground: 222 47% 11%;
  --color-border: 220 13% 91%;
  --color-input: 220 13% 91%;
  --color-ring: 220 90% 56%;

  /* Typography */
  --font-sans: 'Inter', system-ui, sans-serif;
  --font-display: 'Playfair Display', Georgia, serif;

  /* Spacing */
  --radius: 0.5rem;

  /* Shadows */
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1);
}

/* Luxury Theme */
.theme-luxury {
  --color-primary: 39 30% 60%;
  --color-primary-foreground: 0 0% 100%;
  --color-background: 30 10% 98%;
  --color-foreground: 0 0% 10%;
  --font-display: 'Cormorant Garamond', Georgia, serif;
}

/* Modern Theme */
.theme-modern {
  --color-primary: 200 100% 50%;
  --color-primary-foreground: 0 0% 100%;
  --color-background: 0 0% 100%;
  --color-foreground: 222 47% 11%;
}
```

### Theme Provider

```typescript
// components/theme-provider.tsx
'use client';

import { createContext, useContext, useEffect, useState } from 'react';

type Theme = 'default' | 'luxury' | 'modern';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({
  children,
  defaultTheme = 'default',
}: {
  children: React.ReactNode;
  defaultTheme?: Theme;
}) {
  const [theme, setTheme] = useState<Theme>(defaultTheme);

  useEffect(() => {
    const root = document.documentElement;
    root.classList.remove('theme-default', 'theme-luxury', 'theme-modern');
    root.classList.add(`theme-${theme}`);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}
```

---

## Dokku Deployment

### Prerequisites on VPS

```bash
# Install Dokku on your VPS (Ubuntu)
wget -NP . https://dokku.com/install/v0.33.0/bootstrap.sh
sudo DOKKU_TAG=v0.33.0 bash bootstrap.sh

# Set domain
dokku domains:set-global your-server.com

# Install plugins
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git  # If needed
```

### Dockerfile

```dockerfile
# Dockerfile
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json pnpm-lock.yaml* ./
RUN corepack enable pnpm && pnpm i --frozen-lockfile

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build arguments for theming
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_SITE_NAME
ARG NEXT_PUBLIC_SITE_URL
ARG NEXT_PUBLIC_THEME=default

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_SITE_NAME=$NEXT_PUBLIC_SITE_NAME
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_THEME=$NEXT_PUBLIC_THEME
ENV NEXT_TELEMETRY_DISABLED=1

RUN corepack enable pnpm && pnpm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

### Next.js Configuration

```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',

  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'seed-assets.propertywebbuilder.com',
      },
      {
        protocol: 'https',
        hostname: '*.cloudinary.com',
      },
      // Add your image hosts
    ],
    formats: ['image/avif', 'image/webp'],
  },

  // Disable x-powered-by header
  poweredByHeader: false,

  // Enable React strict mode
  reactStrictMode: true,

  // Experimental features
  experimental: {
    // Enable if using server actions
    // serverActions: true,
  },
};

module.exports = nextConfig;
```

### Deploy to Dokku

```bash
# On your VPS - Create the app
dokku apps:create my-property-site

# Set environment variables
dokku config:set my-property-site \
  NEXT_PUBLIC_API_URL=https://api.yourpwbsite.com \
  NEXT_PUBLIC_SITE_NAME="My Property Site" \
  NEXT_PUBLIC_SITE_URL=https://my-property-site.com \
  NEXT_PUBLIC_THEME=luxury \
  NODE_ENV=production

# Set domain
dokku domains:add my-property-site my-property-site.com

# Enable SSL
dokku letsencrypt:enable my-property-site

# On your local machine - Deploy
git remote add dokku dokku@your-server.com:my-property-site
git push dokku main
```

### Health Check Configuration

```bash
# .dokku/CHECKS
WAIT=10
TIMEOUT=60
ATTEMPTS=5

/  Welcome
```

### Procfile (Alternative to Dockerfile)

```
# Procfile
web: npm run start
```

If using Procfile instead of Dockerfile, add:

```bash
# .buildpacks
https://github.com/heroku/heroku-buildpack-nodejs.git
```

---

## Multi-Tenant Setup

### Option 1: Separate Dokku Apps (Recommended)

```bash
# Create apps for each client
dokku apps:create client-luxury
dokku apps:create client-modern
dokku apps:create client-minimal

# Configure each with different settings
dokku config:set client-luxury \
  NEXT_PUBLIC_API_URL=https://luxury.api.pwb.com \
  NEXT_PUBLIC_THEME=luxury \
  NEXT_PUBLIC_SITE_NAME="Luxury Properties"

dokku config:set client-modern \
  NEXT_PUBLIC_API_URL=https://modern.api.pwb.com \
  NEXT_PUBLIC_THEME=modern \
  NEXT_PUBLIC_SITE_NAME="Modern Homes"

# Deploy same codebase to different apps
git push dokku-luxury main
git push dokku-modern main
```

### Option 2: Single App with Dynamic Theming

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const TENANT_CONFIG: Record<string, { theme: string; apiUrl: string }> = {
  'luxury.example.com': { theme: 'luxury', apiUrl: 'https://luxury.api.pwb.com' },
  'modern.example.com': { theme: 'modern', apiUrl: 'https://modern.api.pwb.com' },
};

export function middleware(request: NextRequest) {
  const host = request.headers.get('host') || '';
  const config = TENANT_CONFIG[host];

  if (config) {
    const response = NextResponse.next();
    response.headers.set('x-tenant-theme', config.theme);
    response.headers.set('x-tenant-api', config.apiUrl);
    return response;
  }

  return NextResponse.next();
}
```

### Deployment Script

```bash
#!/bin/bash
# scripts/deploy-tenant.sh

TENANT_NAME=$1
THEME=$2
API_URL=$3
DOMAIN=$4

if [ -z "$TENANT_NAME" ] || [ -z "$THEME" ] || [ -z "$API_URL" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: ./deploy-tenant.sh <tenant-name> <theme> <api-url> <domain>"
  exit 1
fi

echo "Deploying tenant: $TENANT_NAME"

# Create app if not exists
ssh dokku@your-server.com "dokku apps:list" | grep -q "^$TENANT_NAME$" || \
  ssh dokku@your-server.com "dokku apps:create $TENANT_NAME"

# Configure
ssh dokku@your-server.com "dokku config:set $TENANT_NAME \
  NEXT_PUBLIC_API_URL=$API_URL \
  NEXT_PUBLIC_SITE_NAME='$TENANT_NAME Properties' \
  NEXT_PUBLIC_SITE_URL=https://$DOMAIN \
  NEXT_PUBLIC_THEME=$THEME \
  NODE_ENV=production"

# Set domain
ssh dokku@your-server.com "dokku domains:add $TENANT_NAME $DOMAIN"

# Deploy
git push dokku@your-server.com:$TENANT_NAME main

# Enable SSL
ssh dokku@your-server.com "dokku letsencrypt:enable $TENANT_NAME"

echo "Deployed: https://$DOMAIN"
```

---

## Development Workflow

### Local Development

```bash
# Install dependencies
pnpm install

# Copy environment file
cp .env.example .env.local

# Start development server
pnpm dev

# Run linting
pnpm lint

# Run type checking
pnpm type-check

# Build for production
pnpm build

# Start production server locally
pnpm start
```

### Docker Compose for Local Development

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL:-http://localhost:3000}
        - NEXT_PUBLIC_SITE_NAME=${NEXT_PUBLIC_SITE_NAME:-Dev Site}
        - NEXT_PUBLIC_THEME=${NEXT_PUBLIC_THEME:-default}
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    volumes:
      - ./.next:/app/.next
```

### Git Workflow

```bash
# Feature branches
git checkout -b feature/property-search
git commit -m "feat: implement property search filters"
git push origin feature/property-search

# Create PR, get review, merge

# Deploy to staging
git push dokku-staging main

# Deploy to production
git push dokku main
```

---

## Troubleshooting

### Common Issues

#### 1. Build Fails on Dokku

```bash
# Check build logs
dokku logs my-app --num 100

# Rebuild
dokku ps:rebuild my-app

# Check resources
dokku resource:limit my-app
dokku resource:limit my-app --memory 2G --cpu 1
```

#### 2. API Connection Issues

```typescript
// Check if API URL is correct
console.log('API URL:', process.env.NEXT_PUBLIC_API_URL);

// Test connection
curl -v https://api.yoursite.com/api_public/v1/properties
```

#### 3. Image Loading Issues

```javascript
// next.config.js - Add image domain
images: {
  remotePatterns: [
    {
      protocol: 'https',
      hostname: '**.yourpwbsite.com',
    },
  ],
}
```

#### 4. Memory Issues During Build

```bash
# Increase Node memory
dokku config:set my-app NODE_OPTIONS="--max-old-space-size=2048"
```

#### 5. SSL Certificate Issues

```bash
# Renew certificates
dokku letsencrypt:auto-renew my-app

# Check certificate
dokku letsencrypt:ls
```

### Performance Monitoring

```bash
# Check app status
dokku ps:report my-app

# Check resource usage
dokku top

# View logs
dokku logs my-app -t

# Restart app
dokku ps:restart my-app
```

---

## Next Steps

1. **Set up base project** following the structure above
2. **Implement API client** with proper error handling
3. **Build core pages** (home, properties, property detail)
4. **Implement theming** with CSS custom properties
5. **Set up Dokku** on your VPS
6. **Deploy first tenant** and test
7. **Create deployment scripts** for multi-tenant management
8. **Add monitoring** (Sentry, analytics)

---

**Ready to start? Begin with the [Project Setup](#environment-setup) section.**
