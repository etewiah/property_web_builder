# Backend API Implementation Plan

**Document Version:** 1.0  
**Created:** 2026-01-10  
**Status:** Planning Phase  

## Purpose

This document provides a detailed, step-by-step plan to implement the remaining backend API endpoints required for full Next.js client integration. Based on the analysis in `backend-api-integration.md`, we need to add theming, testimonials, and optionally homepage configuration endpoints.

---

## Table of Contents

1. [Overview](#overview)
2. [Phase 1: Theme API (CRITICAL)](#phase-1-theme-api-critical)
3. [Phase 2: Testimonials API (RECOMMENDED)](#phase-2-testimonials-api-recommended)
4. [Phase 3: API Response Standardization (OPTIONAL)](#phase-3-api-response-standardization-optional)
5. [Phase 4: Homepage Sections API (OPTIONAL)](#phase-4-homepage-sections-api-optional)
6. [Testing Strategy](#testing-strategy)
7. [Deployment Checklist](#deployment-checklist)

---

## Overview

### Current Status

The PropertyWebBuilder backend already has:
- ✅ Properties API (`/api_public/v1/properties`)
- ✅ Site Details API (`/api_public/v1/site_details`)
- ✅ Pages API (`/api_public/v1/pages`)
- ✅ Links API (`/api_public/v1/links`)
- ✅ Translations API (`/api_public/v1/translations`)
- ✅ Select Values API (`/api_public/v1/select_values`)

### Missing Endpoints

1. **Theme API** - CRITICAL for multi-tenant theming
2. **Testimonials API** - RECOMMENDED for dynamic content
3. **Homepage Sections API** - OPTIONAL for full CMS control

### Existing Infrastructure

The codebase already has robust theming infrastructure:
- `Pwb::Theme` model (ActiveJSON)
- `Pwb::WebsiteThemeable` concern
- `Pwb::WebsiteStyleable` concern  
- `PaletteLoader` service for color palettes
- `PaletteCompiler` service for optimized CSS

**Our task is to expose this existing functionality via a public API.**

---

## Phase 1: Theme API (CRITICAL)

**Priority:** HIGH  
**Estimated Time:** 4-6 hours  
**Blocker For:** Multi-tenant theming, production readiness  

### 1.1 Objective

Create a public API endpoint that exposes the existing theme system to Next.js clients, allowing each tenant to have customized branding with:
- Dynamic color palettes
- Font selections
- Border radius settings
- Custom CSS injection

### 1.2 Existing Code to Leverage

The backend already has all the logic we need:

```ruby
# app/models/pwb/website.rb
# Lines 75, 80, 85 show theme-related fields:
#  selected_palette       :string
#  theme_name            :string
#  style_variables_for_theme :json

# app/models/concerns/pwb/website_styleable.rb
# Lines 49-61: style_variables method merges theme + palette
# Lines 196-200: css_variables_with_dark_mode generates CSS
# Lines 203-207: css_variables generates light mode CSS

# app/models/pwb/theme.rb
# Lines 189-197: palette_colors method returns color hash
# Lines 229-231: generate_palette_css generates CSS variables
```

### 1.3 Implementation Steps

#### Step 1: Create Theme Controller

**File:** `app/controllers/api_public/v1/theme_controller.rb`

```ruby
# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for theme configuration
    # Returns complete theme data including colors, fonts, and CSS
    class ThemeController < BaseController

      # GET /api_public/v1/theme
      # Returns theme configuration for the current website
      #
      # Query Parameters:
      # - locale: optional locale code (e.g., "en", "es")
      #
      # Response:
      # {
      #   "theme": {
      #     "name": "brisbane",
      #     "palette_id": "ocean_blue",
      #     "colors": {
      #       "primary_color": "#3B82F6",
      #       "secondary_color": "#10B981",
      #       ...
      #     },
      #     "fonts": {
      #       "heading": "Playfair Display",
      #       "body": "Inter"
      #     },
      #     "dark_mode": {
      #       "enabled": true,
      #       "setting": "auto"
      #     },
      #     "css_variables": ":root { --primary-color: #3B82F6; ... }"
      #   }
      # }
      def index
        website = Pwb::Current.website
        
        render json: {
          theme: build_theme_response(website)
        }
      end

      private

      def build_theme_response(website)
        {
          name: website.theme_name || "default",
          palette_id: website.effective_palette_id,
          palette_mode: website.palette_mode || "dynamic",
          colors: website.style_variables,
          fonts: extract_fonts(website),
          border_radius: extract_border_radius(website),
          dark_mode: build_dark_mode_config(website),
          css_variables: website.css_variables_with_dark_mode,
          custom_css: website.raw_css
        }
      end

      def extract_fonts(website)
        vars = website.style_variables
        {
          heading: vars["font_primary"] || vars["font_secondary"] || "Inter",
          body: vars["font_primary"] || "Inter"
        }
      end

      def extract_border_radius(website)
        vars = website.style_variables
        base_radius = vars["border_radius"] || "0.5rem"
        
        {
          sm: "calc(#{base_radius} * 0.5)",
          md: base_radius,
          lg: "calc(#{base_radius} * 1.5)",
          xl: "calc(#{base_radius} * 2)"
        }
      end

      def build_dark_mode_config(website)
        {
          enabled: website.dark_mode_enabled?,
          setting: website.dark_mode_setting,
          force_dark: website.force_dark_mode?,
          auto: website.auto_dark_mode?
        }
      end
    end
  end
end
```

**Rationale:**
- Leverages existing `WebsiteStyleable` concern methods
- Returns CSS variables pre-generated (no client-side color calculation)
- Includes dark mode support
- Provides structured data AND ready-to-inject CSS

#### Step 2: Add Route

**File:** `config/routes.rb`

Find the `api_public` namespace (around line 720) and add:

```ruby
namespace :api_public do
  namespace :v1 do
    # ... existing routes ...
    get "/theme" => "theme#index"        # ADD THIS LINE
  end
end
```

#### Step 3: Create RSpec Tests

**File:** `spec/requests/api_public/v1/theme_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Theme", type: :request do
  let(:website) { create(:pwb_website, :with_theme) }
  
  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe "GET /api_public/v1/theme" do
    it "returns theme configuration" do
      get "/api_public/v1/theme"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json["theme"]).to be_present
      expect(json["theme"]["name"]).to eq(website.theme_name)
      expect(json["theme"]["colors"]).to be_a(Hash)
      expect(json["theme"]["colors"]["primary_color"]).to be_present
    end

    it "includes CSS variables" do
      get "/api_public/v1/theme"
      
      json = JSON.parse(response.body)
      expect(json["theme"]["css_variables"]).to include(":root")
      expect(json["theme"]["css_variables"]).to include("--primary-color")
    end

    it "includes dark mode configuration" do
      website.update(dark_mode_setting: "auto")
      get "/api_public/v1/theme"
      
      json = JSON.parse(response.body)
      expect(json["theme"]["dark_mode"]["enabled"]).to be true
      expect(json["theme"]["dark_mode"]["setting"]).to eq("auto")
    end

    it "includes font configuration" do
      get "/api_public/v1/theme"
      
      json = JSON.parse(response.body)
      expect(json["theme"]["fonts"]).to have_key("heading")
      expect(json["theme"]["fonts"]).to have_key("body")
    end
  end
end
```

#### Step 4: Test Manually

```bash
# Start Rails server
rails s

# In another terminal, test the endpoint
curl http://localhost:3000/api_public/v1/theme | jq

# Expected output:
# {
#   "theme": {
#     "name": "brisbane",
#     "palette_id": "ocean_blue",
#     "colors": {
#       "primary_color": "#3B82F6",
#       "secondary_color": "#10B981",
#       ...
#     },
#     "css_variables": ":root { ... }",
#     ...
#   }
# }
```

#### Step 5: Enhance `site_details` Endpoint (Alternative Approach)

**Option:** Instead of a separate `/theme` endpoint, we could expand the existing `/site_details` endpoint.

**File:** `app/controllers/api_public/v1/site_details_controller.rb`

```ruby
module ApiPublic
  module V1
    class SiteDetailsController < BaseController

      def index
        locale = params[:locale]
        if locale
          I18n.locale = locale
        end
        
        website = Pwb::Current.website
        
        # Expand the response to include theme data
        render json: website.as_json.merge(
          theme: build_theme_data(website)
        )
      end

      private

      def build_theme_data(website)
        {
          name: website.theme_name || "default",
          palette_id: website.effective_palette_id,
          colors: website.style_variables,
          fonts: extract_fonts(website),
          css_variables: website.css_variables_with_dark_mode
        }
      end

      def extract_fonts(website)
        vars = website.style_variables
        {
          heading: vars["font_primary"] || "Inter",
          body: vars["font_primary"] || "Inter"
        }
      end
    end
  end
end
```

**Decision Point:** Choose between:
- **Separate `/theme` endpoint** - Cleaner separation of concerns, easier to cache
- **Expanded `/site_details`** - Fewer API calls, simpler frontend integration

**Recommendation:** Start with separate `/theme` endpoint for clarity, can merge later if needed.

### 1.4 Frontend Integration

Once the backend endpoint is ready, the Next.js client needs to:

1. **Fetch theme at build time** (for static generation)
2. **Inject CSS variables into `<head>`**

**File (Frontend):** `src/app/[locale]/layout.tsx`

```typescript
// Add to existing imports
import { getTheme } from '@/lib/api/site';

export default async function RootLayout({ children, params }: Props) {
  const { locale } = await params;
  
  const [siteDetails, theme] = await Promise.all([
    getSiteDetails(),
    getTheme(),  // NEW: Fetch theme
  ]);

  return (
    <html lang={locale}>
      <head>
        {/* Inject theme CSS variables */}
        <style dangerouslySetInnerHTML={{
          __html: theme.css_variables
        }} />
      </head>
      <body>
        {children}
      </body>
    </html>
  );
}
```

**File (Frontend):** `src/lib/api/site.ts`

```typescript
export async function getTheme(): Promise<Theme> {
  const response = await fetch(`${getApiUrl()}/api_public/v1/theme`);
  const data = await response.json();
  return data.theme;
}
```

### 1.5 Success Criteria

- [ ] `/api_public/v1/theme` endpoint returns complete theme data
- [ ] Response includes CSS variables ready for injection
- [ ] Colors from backend appear in Next.js frontend
- [ ] Dark mode support works
- [ ] Tests pass
- [ ] Manual testing with multiple themes confirms branding changes

---

## Phase 2: Testimonials API (RECOMMENDED)

**Priority:** MEDIUM  
**Estimated Time:** 6-8 hours  
**Benefits:** Dynamic content management, no hardcoded testimonials  

### 2.1 Objective

Replace hardcoded testimonials in the Next.js frontend with dynamic testimonials managed through the backend CMS.

### 2.2 Implementation Steps

#### Step 1: Create Testimonial Model & Migration

**File:** `app/models/pwb/testimonial.rb`

```ruby
# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_testimonials
#
#  id              :bigint           not null, primary key
#  author_name     :string           not null
#  author_role     :string
#  quote           :text             not null
#  rating          :integer
#  position        :integer          default(0), not null
#  visible         :boolean          default(TRUE), not null
#  featured        :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  website_id      :integer          not null
#  author_photo_id :integer
#
# Indexes
#
#  index_pwb_testimonials_on_website_id  (website_id)
#  index_pwb_testimonials_on_visible     (visible)
#  index_pwb_testimonials_on_position    (position)
#
module Pwb
  class Testimonial < ApplicationRecord
    # ===================
    # Associations
    # ===================
    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :author_photo, class_name: 'Pwb::Media', optional: true

    # ===================
    # Validations
    # ===================
    validates :author_name, presence: true
    validates :quote, presence: true, length: { minimum: 10, maximum: 1000 }
    validates :rating, numericality: { 
      only_integer: true, 
      greater_than_or_equal_to: 1, 
      less_than_or_equal_to: 5 
    }, allow_nil: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # ===================
    # Scopes
    # ===================
    scope :visible, -> { where(visible: true) }
    scope :featured, -> { where(featured: true) }
    scope :ordered, -> { order(position: :asc, created_at: :desc) }

    # ===================
    # Instance Methods
    # ===================
    
    def author_photo_url
      author_photo&.image_url
    end

    def as_api_json
      {
        id: id,
        quote: quote,
        author_name: author_name,
        author_role: author_role,
        author_photo: author_photo_url,
        rating: rating,
        position: position
      }
    end
  end
end
```

**File:** `db/migrate/YYYYMMDDHHMMSS_create_pwb_testimonials.rb`

```ruby
class CreatePwbTestimonials < ActiveRecord::Migration[7.1]
  def change
    create_table :pwb_testimonials do |t|
      t.string :author_name, null: false
      t.string :author_role
      t.text :quote, null: false
      t.integer :rating
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false
      t.boolean :featured, default: false, null: false

      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :author_photo, foreign_key: { to_table: :pwb_media }

      t.timestamps
    end

    add_index :pwb_testimonials, :visible
    add_index :pwb_testimonials, :position
  end
end
```

#### Step 2: Add Association to Website Model

**File:** `app/models/pwb/website.rb`

Add to the associations section (around line 148):

```ruby
has_many :testimonials, class_name: 'Pwb::Testimonial', dependent: :destroy
```

#### Step 3: Create Testimonials Controller

**File:** `app/controllers/api_public/v1/testimonials_controller.rb`

```ruby
# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for testimonials
    # Returns visible testimonials for display on the website
    class TestimonialsController < BaseController

      # GET /api_public/v1/testimonials
      # Returns testimonials for the current website
      #
      # Query Parameters:
      # - locale: optional locale code (e.g., "en", "es")
      # - limit: max number of testimonials to return (default: all)
      # - featured_only: if true, only return featured testimonials
      #
      # Response:
      # {
      #   "testimonials": [
      #     {
      #       "id": 1,
      #       "quote": "Great service!",
      #       "author_name": "John Doe",
      #       "author_role": "Buyer",
      #       "author_photo": "https://...",
      #       "rating": 5,
      #       "position": 1
      #     }
      #   ]
      # }
      def index
        locale = params[:locale]
        I18n.locale = locale if locale.present?

        testimonials = Pwb::Current.website.testimonials.visible.ordered
        testimonials = testimonials.featured if params[:featured_only] == 'true'
        testimonials = testimonials.limit(params[:limit].to_i) if params[:limit].present?

        render json: {
          testimonials: testimonials.map(&:as_api_json)
        }
      end
    end
  end
end
```

#### Step 4: Add Route

**File:** `config/routes.rb`

```ruby
namespace :api_public do
  namespace :v1 do
    # ... existing routes ...
    get "/testimonials" => "testimonials#index"  # ADD THIS LINE
  end
end
```

#### Step 5: Create Seed Data

**File:** `db/yml_seeds/testimonials/testimonial_001.yml`

```yaml
author_name: "Sarah Johnson"
author_role: "Property Buyer"
quote: "The team helped us find our dream home in record time. Professional, responsive, and genuinely caring about our needs."
rating: 5
position: 1
visible: true
featured: true
```

**File:** `db/yml_seeds/testimonials/testimonial_002.yml`

```yaml
author_name: "Michael Chen"
author_role: "Landlord"
quote: "Excellent property management service. They handle everything from tenant screening to maintenance, making my life so much easier."
rating: 5
position: 2
visible: true
featured: true
```

**File:** `db/yml_seeds/testimonials/testimonial_003.yml`

```yaml
author_name: "Emma Rodriguez"
author_role: "First-Time Buyer"
quote: "As a first-time buyer, I was nervous about the process. The team walked me through every step with patience and expertise."
rating: 5
position: 3
visible: true
featured: false
```

#### Step 6: Add Seeding Logic

**File:** `lib/pwb/seed_pack_base.rb` or create a new seeder

```ruby
module Pwb
  class TestimonialSeeder
    def self.seed(website)
      testimonial_files = Dir[Rails.root.join('db/yml_seeds/testimonials/*.yml')]
      
      testimonial_files.each do |file|
        data = YAML.load_file(file)
        
        website.testimonials.find_or_create_by(
          author_name: data['author_name']
        ) do |testimonial|
          testimonial.author_role = data['author_role']
          testimonial.quote = data['quote']
          testimonial.rating = data['rating']
          testimonial.position = data['position']
          testimonial.visible = data['visible']
          testimonial.featured = data['featured']
        end
      end
      
      Rails.logger.info "✓ Seeded #{website.testimonials.count} testimonials"
    end
  end
end
```

Call this in your main seed file or rake task.

#### Step 7: Create RSpec Tests

**File:** `spec/models/pwb/testimonial_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe Pwb::Testimonial, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:author_name) }
    it { should validate_presence_of(:quote) }
    it { should validate_length_of(:quote).is_at_least(10).is_at_most(1000) }
  end

  describe 'associations' do
    it { should belong_to(:website) }
    it { should belong_to(:author_photo).optional }
  end

  describe 'scopes' do
    let(:website) { create(:pwb_website) }
    
    before do
      create(:pwb_testimonial, website: website, visible: true, position: 2)
      create(:pwb_testimonial, website: website, visible: false, position: 1)
      create(:pwb_testimonial, website: website, visible: true, position: 3)
    end

    it 'returns only visible testimonials' do
      expect(website.testimonials.visible.count).to eq(2)
    end

    it 'orders by position' do
      testimonials = website.testimonials.visible.ordered
      expect(testimonials.first.position).to eq(2)
      expect(testimonials.last.position).to eq(3)
    end
  end
end
```

**File:** `spec/requests/api_public/v1/testimonials_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "ApiPublic::V1::Testimonials", type: :request do
  let(:website) { create(:pwb_website) }
  
  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
    create_list(:pwb_testimonial, 3, website: website, visible: true)
    create(:pwb_testimonial, website: website, visible: false)
  end

  describe "GET /api_public/v1/testimonials" do
    it "returns only visible testimonials" do
      get "/api_public/v1/testimonials"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json["testimonials"].length).to eq(3)
    end

    it "limits results when limit param is provided" do
      get "/api_public/v1/testimonials?limit=2"
      
      json = JSON.parse(response.body)
      expect(json["testimonials"].length).to eq(2)
    end

    it "returns only featured when featured_only is true" do
      create(:pwb_testimonial, website: website, featured: true, visible: true)
      
      get "/api_public/v1/testimonials?featured_only=true"
      
      json = JSON.parse(response.body)
      expect(json["testimonials"].length).to eq(1)
      expect(json["testimonials"].first["author_name"]).to be_present
    end
  end
end
```

#### Step 8: Create Admin UI (Optional)

**File:** `app/controllers/site_admin/testimonials_controller.rb`

```ruby
module SiteAdmin
  class TestimonialsController < SiteAdminController
    before_action :set_testimonial, only: [:edit, :update, :destroy]

    def index
      @testimonials = current_website.testimonials.ordered
    end

    def new
      @testimonial = current_website.testimonials.build
    end

    def create
      @testimonial = current_website.testimonials.build(testimonial_params)
      
      if @testimonial.save
        redirect_to site_admin_testimonials_path, notice: 'Testimonial created.'
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @testimonial.update(testimonial_params)
        redirect_to site_admin_testimonials_path, notice: 'Testimonial updated.'
      else
        render :edit
      end
    end

    def destroy
      @testimonial.destroy
      redirect_to site_admin_testimonials_path, notice: 'Testimonial deleted.'
    end

    private

    def set_testimonial
      @testimonial = current_website.testimonials.find(params[:id])
    end

    def testimonial_params
      params.require(:pwb_testimonial).permit(
        :author_name, :author_role, :quote, :rating, 
        :position, :visible, :featured, :author_photo_id
      )
    end
  end
end
```

Add routes in `config/routes.rb` under `site_admin` namespace:

```ruby
namespace :site_admin do
  resources :testimonials
end
```

### 2.3 Frontend Integration

**File (Frontend):** `src/lib/api/site.ts`

```typescript
export interface Testimonial {
  id: number;
  quote: string;
  author_name: string;
  author_role?: string;
  author_photo?: string;
  rating?: number;
  position: number;
}

export async function getTestimonials(limit?: number): Promise<Testimonial[]> {
  const url = limit 
    ? `${getApiUrl()}/api_public/v1/testimonials?limit=${limit}`
    : `${getApiUrl()}/api_public/v1/testimonials`;
    
  const response = await fetch(url);
  const data = await response.json();
  return data.testimonials;
}
```

**File (Frontend):** `src/app/[locale]/page.tsx`

Replace hardcoded testimonials:

```typescript
// BEFORE:
testimonials={[
  { quote: t('t1Quote'), name: t('t1Name'), title: t('t1Role') },
  // ...
]}

// AFTER:
const testimonials = await getTestimonials(3);  // Fetch from API

<TestimonialsSection testimonials={testimonials} />
```

### 2.4 Success Criteria

- [ ] Migration runs successfully
- [ ] Testimonial model validates correctly
- [ ] Seed data creates testimonials
- [ ] API endpoint returns testimonials
- [ ] Frontend displays dynamic testimonials
- [ ] Admin UI allows CRUD operations (if implemented)
- [ ] Tests pass

---

## Phase 3: API Response Standardization (OPTIONAL)

**Priority:** LOW  
**Estimated Time:** 2-3 hours  
**Benefits:** Cleaner API contracts, easier frontend integration  

### 3.1 Problem

The frontend currently has "unwrap" logic because responses are inconsistent:

```typescript
// From frontend: src/lib/api/properties.ts:65-69
const unwrap = (value: unknown): unknown => {
  const record = value as Record<string, unknown>;
  return record.data ?? record.payload ?? record.result ?? record;
};
```

Some endpoints return:
- `{ data: { ... } }`
- `{ payload: { ... } }`
- `{ result: { ... } }`
- `{ ... }` (no wrapper)

### 3.2 Recommended Standard

Choose ONE consistent format for all `/api_public/v1/*` endpoints:

```json
{
  "data": { /* main payload */ },
  "meta": { /* pagination, total, etc */ },
  "errors": [ /* validation errors if any */ ]
}
```

### 3.3 Implementation

Create a base response helper:

**File:** `app/controllers/api_public/v1/base_controller.rb`

```ruby
module ApiPublic
  module V1
    class BaseController < ApplicationController
      # Standard JSON response format
      def render_success(data, meta: {})
        render json: {
          data: data,
          meta: meta
        }
      end

      def render_error(errors, status: :unprocessable_entity)
        render json: {
          errors: Array(errors)
        }, status: status
      end
    end
  end
end
```

Update all controllers:

```ruby
# BEFORE:
render json: { properties: properties, meta: meta }

# AFTER:
render_success(properties, meta: meta)
```

### 3.4 Rollout Strategy

1. Add new response helpers to `BaseController`
2. Gradually update endpoints one by one
3. Document breaking changes in CHANGELOG
4. Consider API versioning (`/api_public/v2`) if existing clients depend on old format

---

## Phase 4: Homepage Sections API (OPTIONAL)

**Priority:** LOW  
**Estimated Time:** 8-12 hours  
**Benefits:** Full CMS control over homepage layout  

### 4.1 Objective

Allow backend to control homepage section visibility, order, and content without frontend code changes.

### 4.2 Existing Infrastructure

The codebase already has `PagePart` system for dynamic content blocks:

```ruby
# app/models/pwb/website.rb:204-210
def page_parts
  Pwb::PagePart.where(page_slug: 'website', website_id: id)
end

def get_page_part(page_part_key)
  page_parts.where(page_part_key: page_part_key).first
end
```

### 4.3 Implementation Steps

#### Option A: Extend Existing PageParts

Leverage the existing `Pwb::PagePart` model to define homepage sections:

**File:** `app/controllers/api_public/v1/homepage_sections_controller.rb`

```ruby
module ApiPublic
  module V1
    class HomepageSectionsController < BaseController
      def index
        website = Pwb::Current.website
        sections = build_sections(website)
        
        render json: { sections: sections }
      end

      private

      def build_sections(website)
        [
          build_hero_section(website),
          build_featured_properties_section(website),
          build_testimonials_section(website),
          build_cta_section(website)
        ].compact
      end

      def build_hero_section(website)
        hero_part = website.get_page_part('home__hero')
        return nil unless hero_part&.visible

        {
          type: 'hero',
          position: hero_part.position || 1,
          visible: true,
          content: hero_part.content
        }
      end

      def build_featured_properties_section(website)
        {
          type: 'featured_properties',
          position: 2,
          visible: true,
          content: {
            title: I18n.t('homepage.featured_properties.title'),
            limit: 6
          }
        }
      end

      def build_testimonials_section(website)
        {
          type: 'testimonials',
          position: 3,
          visible: website.testimonials.visible.any?,
          content: {
            title: I18n.t('homepage.testimonials.title')
          }
        }
      end

      def build_cta_section(website)
        cta_part = website.get_page_part('home__cta')
        
        {
          type: 'cta',
          position: 4,
          visible: cta_part&.visible || true,
          content: cta_part&.content || default_cta_content
        }
      end

      def default_cta_content
        {
          title: I18n.t('homepage.cta.title'),
          primary_text: I18n.t('common.browse_listings'),
          primary_link: '/properties'
        }
      end
    end
  end
end
```

Add route:

```ruby
get "/homepage_sections" => "homepage_sections#index"
```

#### Option B: Create HomepageSection Model

More structured approach with a dedicated model:

**File:** `app/models/pwb/homepage_section.rb`

```ruby
module Pwb
  class HomepageSection < ApplicationRecord
    belongs_to :website
    
    SECTION_TYPES = %w[hero featured_properties testimonials cta custom].freeze
    
    validates :section_type, inclusion: { in: SECTION_TYPES }
    validates :position, presence: true, numericality: { only_integer: true }
    
    scope :visible, -> { where(visible: true) }
    scope :ordered, -> { order(position: :asc) }
    
    def as_api_json
      {
        type: section_type,
        position: position,
        visible: visible,
        content: content
      }
    end
  end
end
```

**Migration:**

```ruby
create_table :pwb_homepage_sections do |t|
  t.references :website, null: false
  t.string :section_type, null: false
  t.integer :position, default: 0, null: false
  t.boolean :visible, default: true, null: false
  t.jsonb :content, default: {}
  
  t.timestamps
end
```

### 4.4 Decision Point

**Question:** Is this level of dynamic control needed?

**Current approach (hardcoded sections):**
- ✅ Fast page loads
- ✅ Type-safe components
- ❌ Requires code deploy to change layout

**Dynamic sections API:**
- ✅ Full CMS control
- ✅ No code deploys for layout changes
- ❌ More complex
- ❌ Potential performance impact

**Recommendation:** Skip this phase unless you have a strong business need for non-technical users to control homepage layout.

---

## Testing Strategy

### Unit Tests

For each new model:
- Validations
- Associations
- Scopes
- Instance methods

### Controller/Request Tests

For each new endpoint:
- Happy path (200 OK with valid data)
- Empty state (no data returns empty array)
- Locale handling
- Query parameter filtering

### Integration Tests

- Full page render with theme CSS injected
- Homepage with dynamic testimonials
- Multi-tenant isolation (one site's data doesn't leak to another)

### Manual Testing

Create a test checklist:

```markdown
## Theme API Testing
- [ ] Create two websites with different themes
- [ ] Verify each returns different colors
- [ ] Confirm CSS variables are valid CSS
- [ ] Test dark mode toggle

## Testimonials API Testing
- [ ] Create testimonials via admin UI
- [ ] Verify they appear in API response
- [ ] Test featured_only filter
- [ ] Test limit parameter
- [ ] Confirm position ordering

## Frontend Integration
- [ ] Next.js site applies backend colors
- [ ] Testimonials replace hardcoded ones
- [ ] Dark mode works
- [ ] Build succeeds without errors
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] All tests pass (`bundle exec rspec`)
- [ ] No linting errors (`bundle exec rubocop`)
- [ ] Database migrations reviewed
- [ ] Seed data tested on local environment
- [ ] API documentation updated (Swagger/OpenAPI)
- [ ] CHANGELOG.md updated

### Deployment Steps

1. **Database Migration**
   ```bash
   rails db:migrate
   ```

2. **Seed Sample Data** (for existing sites)
   ```bash
   rails pwb:seed_testimonials
   ```

3. **Deploy Backend**
   ```bash
   git push production main
   ```

4. **Update Frontend** (if needed)
   - Deploy new Next.js version with theme integration

5. **Verify in Production**
   - Test `/api_public/v1/theme`
   - Test `/api_public/v1/testimonials`
   - Check frontend applies theme correctly

### Rollback Plan

If issues occur:

1. **Database rollback:**
   ```bash
   rails db:rollback STEP=1
   ```

2. **Code rollback:**
   ```bash
   git revert <commit-hash>
   git push production main
   ```

3. **Feature flag** (future improvement):
   Add feature flags to toggle new endpoints on/off without deployment

---

## Success Metrics

### Phase 1 (Theme API)
- ✅ All tenants have unique branding via API
- ✅ CSS injection works in Next.js
- ✅ No hardcoded colors in frontend
- ✅ Theme changes in admin reflect immediately

### Phase 2 (Testimonials API)
- ✅ Testimonials manageable via admin UI
- ✅ Frontend fetches from API
- ✅ No hardcoded testimonial strings

### Overall
- ✅ API response time < 200ms (p95)
- ✅ Zero N+1 queries in endpoints
- ✅ 100% test coverage for new code
- ✅ Frontend builds successfully
- ✅ Production deployment with zero downtime

---

## Future Enhancements

### API Versioning

When breaking changes are needed:

```ruby
# config/routes.rb
namespace :api_public do
  namespace :v1 do
    # Current endpoints
  end
  
  namespace :v2 do
    # Future improved endpoints
  end
end
```

### Caching Strategy

Add caching to frequently-accessed endpoints:

```ruby
def index
  cache_key = "api/v1/theme/#{Pwb::Current.website.id}/#{Pwb::Current.website.updated_at}"
  
  theme_data = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
    build_theme_response(Pwb::Current.website)
  end
  
  render json: { theme: theme_data }
end
```

### GraphQL Alternative

Consider GraphQL for more flexible querying:

```graphql
query Homepage {
  theme {
    colors { primary secondary }
    cssVariables
  }
  testimonials(limit: 3) {
    quote authorName rating
  }
}
```

### Webhook Support

Notify frontend when theme changes:

```ruby
after_save :notify_frontend_of_theme_change, if: :saved_change_to_style_variables_for_theme?

def notify_frontend_of_theme_change
  WebhookService.trigger(:theme_updated, website_id: id)
end
```

---

## Questions & Decisions

### Question 1: Theme Endpoint Location

**Options:**
1. Separate `/api_public/v1/theme` endpoint
2. Expand existing `/api_public/v1/site_details` to include theme

**Decision:** Start with separate endpoint for clarity. Can merge later if performance is a concern.

### Question 2: Translation Strategy

**Current:** Hybrid (bundled + API)  
**Alternative:** 100% from API

**Decision Needed:** Clarify with team if ALL translations should come from backend.

### Question 3: Homepage Sections Complexity

**Question:** Do we need full dynamic homepage section control?

**Decision:** Skip Phase 4 unless there's a proven business need. Current PageParts system is sufficient.

---

## Appendix A: API Endpoint Summary

| Endpoint | Method | Purpose | Priority |
|----------|--------|---------|----------|
| `/api_public/v1/theme` | GET | Theme colors, fonts, CSS | **HIGH** |
| `/api_public/v1/testimonials` | GET | Dynamic testimonials | **MEDIUM** |
| `/api_public/v1/homepage_sections` | GET | Homepage layout control | **LOW** |

---

## Appendix B: Database Schema Changes

### New Tables

**pwb_testimonials**
- id (bigint, PK)
- website_id (bigint, FK)
- author_name (string, required)
- author_role (string, optional)
- quote (text, required)
- rating (integer, 1-5)
- position (integer)
- visible (boolean)
- featured (boolean)
- author_photo_id (bigint, FK to pwb_media)
- created_at, updated_at

**pwb_homepage_sections** (optional, Phase 4)
- id (bigint, PK)
- website_id (bigint, FK)
- section_type (string, enum)
- position (integer)
- visible (boolean)
- content (jsonb)
- created_at, updated_at

---

## Appendix C: Existing Code References

### Theme System
- `app/models/pwb/theme.rb` - Theme configuration loader
- `app/models/concerns/pwb/website_themeable.rb` - Theme access control
- `app/models/concerns/pwb/website_styleable.rb` - Style variables & CSS generation
- `app/services/palette_loader.rb` - Palette loading service
- `app/services/palette_compiler.rb` - CSS compilation service

### Page Parts System
- `app/models/pwb/page_part.rb` - Dynamic content blocks
- `app/models/pwb/website.rb#page_parts` - Website page parts

### API Controllers
- `app/controllers/api_public/v1/base_controller.rb` - Base API controller
- `app/controllers/api_public/v1/site_details_controller.rb` - Site config endpoint
- `app/controllers/api_public/v1/properties_controller.rb` - Property listings

---

## Document Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-10 | AI Assistant | Initial implementation plan created |

---

**End of Document**
