# PropertyWebBuilder SEO: Gaps & Enhancement Opportunities

**Date:** December 20, 2025  
**Focus:** Specific gaps in current implementation and prioritized enhancements

---

## Critical Gaps (Must Fix)

### Gap 1: Missing noindex/nofollow Database Fields

**Issue:** Helper references `noindex` and `nofollow` but these fields don't exist in DB

**Current Code in seo_helper.rb (lines 123-128):**
```ruby
if seo_data[:noindex] || seo_data[:nofollow]
  directives = []
  directives << 'noindex' if seo_data[:noindex]
  directives << 'nofollow' if seo_data[:nofollow]
  tags << tag.meta(name: 'robots', content: directives.join(', '))
end
```

**Problem:** These can only be set in controller via `set_seo()`, not stored persistently

**Solution Required:**
```ruby
# Migration needed
add_column :pwb_props, :noindex, :boolean, default: false
add_column :pwb_props, :nofollow, :boolean, default: false
add_column :pwb_pages, :noindex, :boolean, default: false
add_column :pwb_pages, :nofollow, :boolean, default: false

# Model methods needed
class Pwb::Prop
  validates :meta_description, length: { maximum: 160 }
  validates :seo_title, length: { maximum: 70 }
end
```

**Why Important:** For marking draft/expired properties as noindex, or sensitive pages as nofollow

---

### Gap 2: Controller Implementation Not Verified

**Issue:** SeoHelper is defined but unclear if controllers are actually calling it

**What We Don't Know:**
- Is `set_seo()` being called in PropsController?
- Is `set_seo()` being called in PagesController?
- Is `set_seo()` being called in WelcomeController?
- What canonical URLs are being set?

**Expected Pattern (Not Confirmed):**
```ruby
def show_for_rent
  @property_details = find_property_by_slug_or_id(params[:id])
  if @property_details && @property_details.visible && @property_details.for_rent
    # SEO setup - IS THIS HAPPENING?
    set_seo(
      title: @property_details.title,
      description: @property_details.meta_description || 
                   truncate(strip_tags(@property_details.description), length: 160),
      image: @property_details.prop_photos.first&.image_url,
      og_type: 'product',
      canonical_url: prop_show_for_rent_url(
        id: @property_details.slug,
        url_friendly_title: @property_details.slug
      )
    )
    return render "/pwb/props/show"
  else
    @noindex = true  # For 404 pages
    return render "not_found"
  end
end
```

**Action Needed:**
1. Audit all controllers inheriting from ApplicationController
2. Grep for `set_seo` calls
3. Add missing SEO setup to any incomplete controllers
4. Ensure canonical URLs are set to slug-based versions (prevents duplicates)

---

### Gap 3: Hreflang Tags Unclear Implementation

**Issue:** Helper method exists but unclear if being called in views

**Helper Method (seo_helper.rb lines 115-120):**
```ruby
if seo_data[:alternate_urls].present?
  seo_data[:alternate_urls].each do |locale, url|
    tags << tag.link(rel: 'alternate', hreflang: locale, href: url)
  end
end
```

**Problem:** This requires `alternate_urls` to be set in controller:
```ruby
set_seo(
  alternate_urls: {
    'en' => 'https://site.com/en/properties/123',
    'es' => 'https://site.com/es/properties/123',
    'fr' => 'https://site.com/fr/properties/123'
  }
)
```

**Not Clear If:**
- Controllers are setting `alternate_urls`
- Multi-language properties are generating proper hreflang tags
- x-default hreflang is being set

**Solution Required:**
Create a helper to generate hreflang URLs:
```ruby
def generate_alternate_urls(resource)
  I18n.available_locales.each_with_object({}) do |locale, hash|
    url = case resource
          when Pwb::Prop
            prop_path(resource, locale: locale)
          when Pwb::Page
            page_path(resource, locale: locale)
          else
            root_path(locale: locale)
          end
    hash[locale] = url
  end
end
```

---

### Gap 4: Photo URL Extraction Fragile

**Issue:** Property schema attempts multiple ways to get photo URL (lines 189-193)

```ruby
if prop.respond_to?(:photos) && prop.photos.any?
  data['image'] = prop.photos.first(5).map { |photo| photo_url(photo) }.compact
elsif prop.respond_to?(:prop_photos) && prop.prop_photos.any?
  data['image'] = prop.prop_photos.first(5).map { |pp| pp.image_url }.compact
end

def photo_url(photo)
  if photo.respond_to?(:image_url)
    photo.image_url
  elsif photo.respond_to?(:url)
    photo.url
  end
end
```

**Problems:**
- `photo_url()` helper is private, hard to test
- Returns nil if photo doesn't have expected methods
- No fallback to default/placeholder image
- Doesn't validate URLs are absolute

**Solution Required:**
```ruby
# Create dedicated photo URL helper
def extract_property_images(property, max_count: 5)
  images = []
  
  if property.respond_to?(:prop_photos)
    images = property.prop_photos.first(max_count).map do |photo|
      build_absolute_url(photo.image_url || photo.url)
    end.compact
  elsif property.respond_to?(:photos)
    images = property.photos.first(max_count).map do |photo|
      build_absolute_url(photo.image_url || photo.url)
    end.compact
  end
  
  # Fallback to placeholder
  images.any? ? images : [build_absolute_url(property.website.logo_url)]
end

def build_absolute_url(url)
  return nil unless url.present?
  url.start_with?('http') ? url : "#{request.protocol}#{request.host_with_port}#{url}"
end
```

---

## Feature Gaps (High Priority)

### Gap 5: No Admin UI for SEO Fields

**Missing Completely:** Admin interface to edit/preview SEO data

**What Should Exist:**
```erb
<!-- Admin form for property SEO -->
<%= form_with model: @property do |f| %>
  <div class="form-group">
    <%= f.label :seo_title, "SEO Title (max 70 chars)" %>
    <%= f.text_field :seo_title, class: 'form-control', maxlength: 70 %>
    <small><%= @property.seo_title&.length || 0 %>/70</small>
  </div>

  <div class="form-group">
    <%= f.label :meta_description, "Meta Description (120-160 chars)" %>
    <%= f.text_area :meta_description, class: 'form-control', maxlength: 160, rows: 3 %>
    <small><%= @property.meta_description&.length || 0 %>/160</small>
  </div>

  <div class="form-group">
    <%= f.label :noindex, "Prevent indexing" %>
    <%= f.check_box :noindex %>
    <small>Check to prevent search engines from indexing this property</small>
  </div>

  <!-- Preview Section -->
  <div class="search-result-preview">
    <h4>Search Result Preview</h4>
    <div class="google-search-preview">
      <div class="title"><%= @property.seo_title %></div>
      <div class="url"><%= prop_show_for_sale_url(@property) %></div>
      <div class="description"><%= @property.meta_description %></div>
    </div>
  </div>
<% end %>
```

**Implementation Effort:** 2-3 days
**Priority:** High (users need way to manage SEO)

---

### Gap 6: No Sitemap Index for Large Catalogs

**Issue:** Sitemap in single file. XML Sitemap protocol recommends max 50,000 URLs per file

**Current Implementation:**
- Single sitemap file
- All properties + pages in one file
- Works for small catalogs (<5k properties)
- Will break for large catalogs (>50k properties)

**Solution Required:**
```ruby
# sitemaps_controller.rb enhancement
class SitemapsController < ActionController::Base
  def index
    @website = Pwb::Current.website
    return render_not_found unless @website

    @property_count = fetch_properties.count
    @page_count = fetch_pages.count
    
    # If total URLs < 50k, render single sitemap
    if @property_count + @page_count < 50000
      @properties = fetch_properties
      @pages = fetch_pages
      respond_to { |format| format.xml { render :single } }
    else
      # Otherwise render sitemap index
      @sitemap_count = ((@property_count + @page_count) / 50000.0).ceil
      respond_to { |format| format.xml { render :index } }
    end
  end

  def show
    @website = Pwb::Current.website
    page = params[:page].to_i
    
    case params[:type]
    when 'properties'
      @properties = fetch_properties.limit(50000).offset((page - 1) * 50000)
      respond_to { |format| format.xml { render :properties } }
    when 'pages'
      @pages = fetch_pages.limit(50000).offset((page - 1) * 50000)
      respond_to { |format| format.xml { render :pages } }
    end
  end
end
```

**Route Changes:**
```ruby
get '/sitemap.xml', to: 'sitemaps#index', defaults: { format: 'xml' }
get '/sitemap/:type/:page.xml', to: 'sitemaps#show', defaults: { format: 'xml' }
```

**Priority:** Medium (only needed for large catalogs)

---

### Gap 7: No Image Sitemap

**Issue:** XML namespace exists but images never included

**Current Template (lines 2-3):**
```xml
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
```

**But no image entries generated**

**Enhancement:**
```erb
<% @properties.each do |property| %>
  <url>
    <loc><%= property_url(property) %></loc>
    <lastmod><%= property.updated_at.strftime('%Y-%m-%d') %></lastmod>
    
    <!-- Add images for Google Image Search -->
    <% if property.prop_photos.any? %>
      <% property.prop_photos.first(10).each do |photo| %>
        <image:image>
          <image:loc><%= photo.image_url %></image:loc>
          <image:title><%= property.title %></image:title>
          <image:caption><%= property.address %></image:caption>
        </image:image>
      <% end %>
    <% end %>
  </url>
<% end %>
```

**Benefits:**
- Better indexing in Google Image Search
- Increased property visibility
- Shows property images in image results

**Priority:** Medium (nice-to-have for larger sites)

---

## Enhancement Opportunities (Medium Priority)

### Enhancement 1: Schema.org AggregateRating

**Current State:** No review/rating schema

**Enhancement:**
```ruby
# In seo_helper.rb
def property_json_ld(prop)
  data = { ... existing fields ... }
  
  # Add if property has reviews
  if prop.respond_to?(:reviews) && prop.reviews.any?
    reviews = prop.reviews.select(&:approved)
    if reviews.any?
      average_rating = reviews.sum(:rating) / reviews.count.to_f
      data['aggregateRating'] = {
        '@type' => 'AggregateRating',
        'ratingValue' => average_rating.round(1),
        'ratingCount' => reviews.count,
        'bestRating' => 5,
        'worstRating' => 1
      }
    end
  end
  
  tag.script(data.to_json.html_safe, type: 'application/ld+json')
end
```

**Impact:** Rich stars in Google search results

---

### Enhancement 2: Schema.org Person for Agents

**Current State:** Organization schema exists but no agent/person schema

**Enhancement:**
```ruby
def agent_json_ld(agent)
  data = {
    '@context' => 'https://schema.org',
    '@type' => 'Person',
    'name' => agent.name,
    'telephone' => agent.phone,
    'email' => agent.email,
    'url' => agent_profile_url(agent)
  }
  
  if agent.photo_url
    data['image'] = agent.photo_url
  end
  
  if agent.bio
    data['description'] = agent.bio
  end
  
  tag.script(data.to_json.html_safe, type: 'application/ld+json')
end
```

**Use Case:** Show agent profiles in search results

---

### Enhancement 3: Schema.org OpeningHours

**Current State:** Not implemented

**Enhancement:**
```ruby
def business_json_ld(website)
  data = {
    '@context' => 'https://schema.org',
    '@type' => 'RealEstateAgent',
    'name' => website.company_display_name,
    # ... existing fields ...
  }
  
  if website.opening_hours.present?
    data['openingHoursSpecification'] = 
      website.opening_hours.map do |day, hours|
        {
          '@type' => 'OpeningHoursSpecification',
          'dayOfWeek' => day,
          'opens' => hours[:open],
          'closes' => hours[:close]
        }
      end
  end
  
  tag.script(data.to_json.html_safe, type: 'application/ld+json')
end
```

---

### Enhancement 4: Dynamic Sitemap Regeneration

**Current State:** Manual regeneration required

**Enhancement - Sidekiq Job:**
```ruby
class RegenerateSitemapJob
  include Sidekiq::Worker
  sidekiq_options retry: 3, dead: true

  def perform(website_id)
    @website = Pwb::Website.find(website_id)
    Pwb::Current.website = @website
    
    # Force sitemap re-render by clearing cache
    Rails.cache.delete("sitemap_#{website_id}")
    
    # Trigger sitemap generation
    SitemapsController.new.index
    
    # Optionally ping search engines
    notify_google_sitemap
    notify_bing_sitemap
  end

  private

  def notify_google_sitemap
    url = "http://www.google.com/webmasters/tools/ping?sitemap=" +
          ERB::Util.url_encode(sitemap_url)
    HTTParty.get(url)
  end
end

# In models
class Pwb::Prop
  after_update :schedule_sitemap_update, if: :visible_changed?
  
  def schedule_sitemap_update
    RegenerateSitemapJob.perform_async(website_id)
  end
end
```

**Priority:** Medium (improves SEO freshness)

---

### Enhancement 5: Meta Tag Validation

**Current State:** No validation of field lengths

**Enhancement - Model Validators:**
```ruby
class Pwb::Prop < ApplicationRecord
  validates :seo_title, length: { 
    maximum: 70, 
    message: 'should be 50-70 characters for optimal display' 
  }, allow_blank: true
  
  validates :meta_description, length: { 
    maximum: 160, 
    message: 'should be 120-160 characters for optimal display' 
  }, allow_blank: true
  
  validate :validate_meta_seo_fields_if_visible
  
  private
  
  def validate_meta_seo_fields_if_visible
    if visible && seo_title.blank?
      errors.add(:seo_title, 'should be set for visible properties')
    end
    
    if visible && meta_description.blank?
      errors.add(:meta_description, 'should be set for visible properties')
    end
  end
end
```

---

### Enhancement 6: SEO Audit/Health Dashboard

**Current State:** No visibility into SEO quality

**Enhancement - Admin Dashboard:**
```ruby
class SeoAuditController < AdminController
  def index
    @missing_descriptions = Pwb::Prop.where(meta_description: [nil, ''])
    @missing_titles = Pwb::Prop.where(seo_title: [nil, ''])
    @long_descriptions = Pwb::Prop.where("LENGTH(meta_description) > 160")
    @long_titles = Pwb::Prop.where("LENGTH(seo_title) > 70")
    @no_images = Pwb::Prop.left_joins(:prop_photos).where(prop_photos: { id: nil })
    
    @audit_score = calculate_seo_health
  end
  
  private
  
  def calculate_seo_health
    total = Pwb::Prop.count
    
    has_title = Pwb::Prop.where.not(seo_title: [nil, '']).count
    has_description = Pwb::Prop.where.not(meta_description: [nil, '']).count
    has_images = Pwb::Prop.joins(:prop_photos).distinct.count
    
    ((has_title + has_description + has_images) / (total * 3).to_f * 100).round
  end
end
```

---

## Testing Gaps (Critical)

### Missing Test Suites

```ruby
# spec/helpers/seo_helper_spec.rb
describe SeoHelper do
  describe '#seo_title' do
    it 'includes page title if present'
    it 'includes site name if no page title'
    it 'removes duplicates'
    it 'uses custom format with pipe separator'
  end
  
  describe '#seo_meta_tags' do
    it 'includes all required meta tags'
    it 'handles missing og:image gracefully'
    it 'includes hreflang tags when available'
    it 'sets robots noindex when requested'
  end
  
  describe '#property_json_ld' do
    it 'generates valid JSON-LD'
    it 'includes all property fields'
    it 'handles missing address gracefully'
    it 'formats price in schema.org format'
    it 'includes up to 5 images'
  end
end

# spec/controllers/sitemaps_controller_spec.rb
describe SitemapsController do
  it 'generates valid XML sitemap'
  it 'includes only visible properties'
  it 'scopes to current website'
  it 'includes proper change frequencies'
  it 'includes proper priorities'
  it 'handles large catalogs (sitemap index)'
end

# spec/controllers/robots_controller_spec.rb
describe RobotsController do
  it 'generates valid robots.txt'
  it 'includes sitemap reference'
  it 'blocks admin paths'
  it 'allows property paths'
  it 'includes crawl-delay'
end

# spec/requests/seo_integration_spec.rb
describe 'SEO Integration' do
  it 'renders meta tags on property pages'
  it 'renders JSON-LD on property pages'
  it 'handles multi-language hreflang'
  it 'generates canonical URLs'
  it 'marks draft properties as noindex'
end
```

---

## Timeline & Priority Matrix

| Gap/Enhancement | Priority | Effort | Impact | Timeline |
|-----------------|----------|--------|--------|----------|
| noindex/nofollow fields | Critical | 1 day | High | Week 1 |
| Verify controller implementation | Critical | 1-2 days | High | Week 1 |
| Hreflang verification | Critical | 1 day | Medium | Week 1 |
| Photo URL robustness | High | 1 day | Medium | Week 1 |
| Admin UI for SEO fields | High | 3-5 days | High | Week 2-3 |
| Add tests | High | 3-4 days | High | Week 2-3 |
| Sitemap index | Medium | 2 days | Medium | Week 3 |
| Image sitemap | Medium | 1 day | Medium | Week 3 |
| AggregateRating schema | Medium | 1 day | Low | Week 4 |
| Person schema | Medium | 1 day | Low | Week 4 |
| OpeningHours schema | Medium | 1 day | Low | Week 4 |
| Dynamic sitemap regeneration | Medium | 2 days | Medium | Week 4 |
| Meta validation | Low | 1 day | Medium | Week 4 |
| SEO dashboard | Low | 2-3 days | Low | Week 5 |

---

## Code Review Checklist for PRs

When implementing these gaps/enhancements:

- [ ] All JSON-LD is valid (test with https://search.google.com/test/rich-results)
- [ ] All URLs in schemas are absolute
- [ ] All images have proper dimensions (og:image should be 1200x630)
- [ ] Meta descriptions are 120-160 characters
- [ ] Page titles are 50-70 characters
- [ ] Canonical URLs prevent duplicates
- [ ] Hreflang tags include x-default
- [ ] Noindex is set on draft/unpublished content
- [ ] Tests cover happy path and edge cases
- [ ] Multi-tenant isolation is maintained
- [ ] Performance impact is assessed (avoid N+1 queries)
- [ ] Backwards compatibility maintained

---

**Created:** December 20, 2025  
**Purpose:** Guide development of SEO improvements
**Status:** Prioritized and ready for implementation
