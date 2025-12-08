# SEO Implementation Guide for PropertyWebBuilder

This guide provides code examples and specific steps to implement the SEO improvements identified in the SEO_AUDIT_REPORT.

---

## Table of Contents
1. [Database Schema Changes](#database-schema-changes)
2. [Helper Methods](#helper-methods)
3. [View Templates](#view-templates)
4. [Controller Updates](#controller-updates)
5. [Robots.txt Configuration](#robotstxt-configuration)
6. [Sitemap Generation](#sitemap-generation)
7. [Structured Data (JSON-LD)](#structured-data-json-ld)

---

## Database Schema Changes

### Migration: Add SEO Fields to Props and Pages

Create migration file: `db/migrate/[timestamp]_add_seo_fields_to_props_and_pages.rb`

```ruby
class AddSeoFieldsToPropsAndPages < ActiveRecord::Migration[8.0]
  def change
    # Props table enhancements
    add_column :pwb_props, :meta_description, :text, limit: 160
    add_column :pwb_props, :seo_slug, :string  # Alternative to ID-based slug
    add_column :pwb_props, :noindex, :boolean, default: false
    add_column :pwb_props, :nofollow, :boolean, default: false
    add_index :pwb_props, :seo_slug

    # Pages table enhancements
    add_column :pwb_pages, :meta_description, :text, limit: 160
    add_column :pwb_pages, :noindex, :boolean, default: false
    add_column :pwb_pages, :nofollow, :boolean, default: false

    # Websites table - SEO settings
    add_column :pwb_websites, :seo_settings, :json, default: {}
    # Example seo_settings structure:
    # {
    #   site_description: "Real estate agency...",
    #   brand_name: "My Agency",
    #   twitter_handle: "@myagency",
    #   facebook_url: "https://facebook.com/...",
    #   default_image_url: "...",
    #   enable_sitemap: true,
    #   enable_structured_data: true
    # }
  end
end
```

---

## Helper Methods

### File: `app/helpers/pwb/seo_helper.rb`

```ruby
module Pwb
  module SeoHelper
    # Generate Open Graph meta tags
    # Usage: <%= render_og_tags(property) %>
    def render_og_tags(resource, current_url = nil)
      tags = []
      
      # og:title
      title = extract_title(resource)
      tags << tag.meta(property: 'og:title', content: title) if title.present?

      # og:description
      description = extract_description(resource)
      tags << tag.meta(property: 'og:description', content: description) if description.present?

      # og:image
      image_url = extract_image_url(resource)
      tags << tag.meta(property: 'og:image', content: image_url) if image_url.present?

      # og:url
      url = current_url || request.original_url
      tags << tag.meta(property: 'og:url', content: url) if url.present?

      # og:type
      type = extract_og_type(resource)
      tags << tag.meta(property: 'og:type', content: type) if type.present?

      # og:site_name
      if @current_website.present?
        tags << tag.meta(property: 'og:site_name', content: @current_website.company_display_name)
      end

      safe_join(tags)
    end

    # Generate Twitter Card meta tags
    # Usage: <%= render_twitter_cards(property) %>
    def render_twitter_cards(resource)
      tags = []
      
      tags << tag.meta(name: 'twitter:card', content: 'summary_large_image')
      
      if @current_website&.seo_settings&.dig('twitter_handle').present?
        tags << tag.meta(name: 'twitter:creator', content: @current_website.seo_settings['twitter_handle'])
      end

      title = extract_title(resource)
      tags << tag.meta(name: 'twitter:title', content: title) if title.present?

      description = extract_description(resource)
      tags << tag.meta(name: 'twitter:description', content: description) if description.present?

      image_url = extract_image_url(resource)
      tags << tag.meta(name: 'twitter:image', content: image_url) if image_url.present?

      safe_join(tags)
    end

    # Generate canonical link tag
    # Usage: <%= render_canonical_link(property) %>
    def render_canonical_link(url)
      tag.link(rel: 'canonical', href: url) if url.present?
    end

    # Generate meta robots tag
    # Usage: <%= render_meta_robots(resource) %>
    def render_meta_robots(resource)
      noindex = resource.respond_to?(:noindex) && resource.noindex
      nofollow = resource.respond_to?(:nofollow) && resource.nofollow

      content_parts = []
      content_parts << (noindex ? 'noindex' : 'index')
      content_parts << (nofollow ? 'nofollow' : 'follow')

      tag.meta(name: 'robots', content: content_parts.join(', '))
    end

    # Generate hreflang tags for multi-language pages
    # Usage: <%= render_hreflang_tags(property) %>
    def render_hreflang_tags(resource, base_url = nil)
      return '' if @current_website.supported_locales.blank?

      tags = []
      base_url ||= request.base_url

      @current_website.supported_locales.each do |locale|
        url = url_for_locale(resource, locale, base_url)
        next unless url.present?

        tags << tag.link(
          rel: 'alternate',
          hreflang: locale,
          href: url
        )
      end

      # Add x-default for unspecified locales
      default_url = url_for_locale(resource, I18n.default_locale, base_url)
      tags << tag.link(
        rel: 'alternate',
        hreflang: 'x-default',
        href: default_url
      ) if default_url.present?

      safe_join(tags)
    end

    private

    def extract_title(resource)
      case resource
      when Pwb::ListedProperty, Pwb::Prop
        "#{resource.title} - #{@current_website&.company_display_name}"
      when Pwb::Page
        resource.page_title.present? ? 
          "#{resource.page_title} - #{@current_website&.company_display_name}" :
          @current_website&.company_display_name
      else
        resource.title
      end
    end

    def extract_description(resource)
      case resource
      when Pwb::ListedProperty, Pwb::Prop
        resource.meta_description || truncate(resource.description, length: 160, separator: ' ')
      when Pwb::Page
        resource.meta_description
      else
        resource.description
      end
    end

    def extract_image_url(resource)
      case resource
      when Pwb::ListedProperty, Pwb::Prop
        if resource.respond_to?(:prop_photos) && resource.prop_photos.any?
          resource.prop_photos.first.optimized_image_url
        elsif resource.respond_to?(:ordered_photo) && resource.ordered_photo(1)
          resource.ordered_photo(1).optimized_image_url
        end
      when Pwb::Page
        # Assuming pages can have featured images
        resource.featured_image_url if resource.respond_to?(:featured_image_url)
      else
        nil
      end
    end

    def extract_og_type(resource)
      case resource
      when Pwb::ListedProperty, Pwb::Prop
        'product'  # Real estate properties are products
      when Pwb::Page
        'website'
      else
        'website'
      end
    end

    def url_for_locale(resource, locale, base_url)
      case resource
      when Pwb::ListedProperty
        operation = resource.for_sale ? 'for-sale' : 'for-rent'
        "#{base_url}/#{locale}/properties/#{operation}/#{resource.id}/#{resource.slug}"
      when Pwb::Page
        "#{base_url}/#{locale}/p/#{resource.slug}"
      else
        base_url
      end
    end
  end
end
```

### File: `app/helpers/pwb/structured_data_helper.rb`

```ruby
module Pwb
  module StructuredDataHelper
    # Generate Property schema.org JSON-LD
    # Usage: <%= render_property_schema(property) %>
    def render_property_schema(property)
      schema = {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": property.title,
        "description": property.description,
        "url": property_url(property),
        "image": extract_property_images(property),
        "offers": {
          "@type": "Offer",
          "priceCurrency": property.price_currency,
          "price": property.price.to_s
        }
      }

      # Add location if available
      if property.latitude.present? && property.longitude.present?
        schema["geo"] = {
          "@type": "GeoCoordinates",
          "latitude": property.latitude,
          "longitude": property.longitude
        }
      end

      # Add address
      if property.address.present?
        schema["address"] = {
          "@type": "PostalAddress",
          "streetAddress": property.address.street_address,
          "addressLocality": property.address.city,
          "addressRegion": property.address.region,
          "postalCode": property.address.postal_code,
          "addressCountry": property.address.country
        }
      end

      render_json_ld(schema)
    end

    # Generate Organization schema for homepage
    # Usage: <%= render_organization_schema(website) %>
    def render_organization_schema(website)
      schema = {
        "@context": "https://schema.org",
        "@type": "Organization",
        "name": website.company_display_name,
        "url": request.base_url,
        "sameAs": extract_social_profiles(website)
      }

      # Add contact information if available
      if website.contact_address.present?
        schema["address"] = format_address_schema(website.contact_address)
      end

      # Add image/logo if available
      if website.seo_settings&.dig('logo_url').present?
        schema["logo"] = website.seo_settings['logo_url']
      end

      render_json_ld(schema)
    end

    # Generate BreadcrumbList schema
    # Usage: <%= render_breadcrumb_schema(breadcrumbs) %>
    def render_breadcrumb_schema(breadcrumbs)
      items = breadcrumbs.each_with_index.map do |crumb, index|
        {
          "@type": "ListItem",
          "position": index + 1,
          "name": crumb[:name],
          "item": crumb[:url]
        }
      end

      schema = {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": items
      }

      render_json_ld(schema)
    end

    # Generate LocalBusiness schema
    # Usage: <%= render_local_business_schema(agency) %>
    def render_local_business_schema(agency)
      schema = {
        "@context": "https://schema.org",
        "@type": "LocalBusiness",
        "name": agency.company_name,
        "url": agency.url,
        "telephone": agency.phone_number_primary,
        "email": agency.email_primary
      }

      if agency.primary_address.present?
        schema["address"] = format_address_schema(agency.primary_address)
      end

      # Add multiple locations if applicable
      if agency.secondary_address.present?
        schema["hasMap"] = agency.secondary_address.latitude && 
                          agency.secondary_address.longitude ? 
                          "https://maps.google.com/?q=#{agency.secondary_address.latitude},#{agency.secondary_address.longitude}" :
                          nil
      end

      render_json_ld(schema)
    end

    private

    def render_json_ld(schema)
      tag.script(type: 'application/ld+json') do
        schema.to_json.html_safe
      end
    end

    def extract_property_images(property)
      if property.respond_to?(:prop_photos) && property.prop_photos.any?
        property.prop_photos.map(&:optimized_image_url).compact
      elsif property.respond_to?(:ordered_photo)
        [property.ordered_photo(1)&.optimized_image_url].compact
      else
        []
      end
    end

    def extract_social_profiles(website)
      profiles = []
      seo_settings = website.seo_settings || {}

      profiles << seo_settings['facebook_url'] if seo_settings['facebook_url'].present?
      profiles << seo_settings['instagram_url'] if seo_settings['instagram_url'].present?
      profiles << seo_settings['linkedin_url'] if seo_settings['linkedin_url'].present?
      profiles << seo_settings['twitter_url'] if seo_settings['twitter_url'].present?

      profiles.compact
    end

    def format_address_schema(address)
      {
        "@type": "PostalAddress",
        "streetAddress": address.street_address,
        "addressLocality": address.city,
        "addressRegion": address.region,
        "postalCode": address.postal_code,
        "addressCountry": address.country
      }
    end
  end
end
```

---

## View Templates

### File: `app/views/pwb/_seo_meta_tags.html.erb`

This is a comprehensive partial that should be included in all layouts:

```erb
<% content_for :page_head do %>
  <!-- Standard Meta Tags -->
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  
  <!-- Meta Description (140-160 chars) -->
  <% if @meta_description.present? %>
    <meta name="description" content="<%= @meta_description %>">
  <% elsif @page_description.present? %>
    <meta name="description" content="<%= truncate(@page_description, length: 160, separator: ' ') %>">
  <% elsif @current_website&.seo_settings&.dig('site_description').present? %>
    <meta name="description" content="<%= @current_website.seo_settings['site_description'] %>">
  <% end %>

  <!-- Meta Robots -->
  <% if @noindex %>
    <meta name="robots" content="noindex, nofollow">
  <% elsif @nofollow %>
    <meta name="robots" content="index, nofollow">
  <% else %>
    <meta name="robots" content="index, follow">
  <% end %>

  <!-- Canonical URL -->
  <% if @canonical_url.present? %>
    <%= link_to '', @canonical_url, rel: 'canonical' %>
  <% end %>

  <!-- Open Graph Meta Tags -->
  <% if @og_title.present? %>
    <meta property="og:title" content="<%= @og_title %>">
  <% elsif @page_title.present? %>
    <meta property="og:title" content="<%= @page_title %>">
  <% end %>

  <% if @og_description.present? %>
    <meta property="og:description" content="<%= @og_description %>">
  <% elsif @meta_description.present? %>
    <meta property="og:description" content="<%= @meta_description %>">
  <% end %>

  <% if @og_image.present? %>
    <meta property="og:image" content="<%= @og_image %>">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
  <% end %>

  <meta property="og:url" content="<%= request.original_url %>">
  <meta property="og:type" content="<%= @og_type || 'website' %>">
  <meta property="og:site_name" content="<%= @current_website&.company_display_name %>">

  <!-- Twitter Card Meta Tags -->
  <meta name="twitter:card" content="summary_large_image">
  <% if @current_website&.seo_settings&.dig('twitter_handle').present? %>
    <meta name="twitter:creator" content="<%= @current_website.seo_settings['twitter_handle'] %>">
  <% end %>
  <% if @page_title.present? %>
    <meta name="twitter:title" content="<%= @page_title %>">
  <% end %>
  <% if @meta_description.present? %>
    <meta name="twitter:description" content="<%= @meta_description %>">
  <% end %>
  <% if @og_image.present? %>
    <meta name="twitter:image" content="<%= @og_image %>">
  <% end %>

  <!-- Mobile App Meta Tags (Optional) -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="theme-color" content="#ffffff">

  <!-- Hreflang Tags for Multi-Language -->
  <%= render_hreflang_tags(@property_details || @page) %>

<% end %>
```

### Updated Theme Layout: `app/themes/default/views/layouts/pwb/application.html.erb`

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= yield(:page_title) %></title>
    
    <!-- SEO Meta Tags -->
    <%= render '/pwb/seo_meta_tags' %>
    
    <!-- Legacy og:image handling (keep for backwards compatibility) -->
    <%= yield(:page_head) %>
    
    <!-- Rest of head content -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- ... rest of existing head content ... -->
  </head>
  <body class="tnt-body default-theme <%= @current_website.body_style %>">
    <!-- ... body content ... -->
  </body>
</html>
```

---

## Controller Updates

### File: `app/controllers/pwb/base_controller.rb` (if exists, or ApplicationController)

Add SEO setup in before_action:

```ruby
module Pwb
  class BaseController < ApplicationController
    before_action :setup_seo_defaults

    private

    def setup_seo_defaults
      # Set sensible defaults for all pages
      @og_type = 'website'
      @noindex = false
      @nofollow = false
      @meta_description = @current_website&.seo_settings&.dig('site_description')
    end

    def set_property_seo_meta(property)
      @page_title = "#{property.title} - #{@current_website.company_display_name}"
      @meta_description = property.meta_description || 
                         truncate(strip_tags(property.description), length: 160, separator: ' ')
      @og_title = property.title
      @og_description = @meta_description
      @og_type = 'product'
      @canonical_url = request.original_url
      
      # Set og:image from first property photo
      if property.respond_to?(:prop_photos) && property.prop_photos.any?
        @og_image = property.prop_photos.first.optimized_image_url
      end
    end

    def set_page_seo_meta(page)
      @page_title = page.page_title.present? ? 
        "#{page.page_title} - #{@current_website.company_display_name}" :
        @current_website.company_display_name
      @meta_description = page.meta_description
      @og_type = 'website'
      @canonical_url = request.original_url
    end

    def set_homepage_seo_meta
      @page_title = @current_website.company_display_name
      @meta_description = @current_website.seo_settings&.dig('site_description')
      @og_type = 'website'
    end
  end
end
```

### Updated PropsController

```ruby
def show_for_rent
  @carousel_speed = 3000
  @operation_type = "for_rent"
  @operation_type_key = @operation_type.camelize(:lower)
  @map_markers = []

  @property_details = find_property_by_slug_or_id(params[:id])

  if @property_details && @property_details.visible && @property_details.for_rent
    set_map_marker
    @show_vacational_rental = @property_details.for_rent_short_term
    
    # SEO Meta Tags - NEW
    set_property_seo_meta(@property_details)
    # Set canonical to slug-based URL to prevent duplicates
    @canonical_url = prop_show_for_rent_url(
      id: @property_details.slug,
      url_friendly_title: @property_details.slug,
      locale: I18n.locale
    )
    
    return render "/pwb/props/show"
  else
    @page_title = I18n.t("propertyNotFound")
    hi_content = @current_website.contents.where(tag: "landing-carousel")[0]
    @header_image = hi_content.present? ? hi_content.default_photo : nil
    @noindex = true  # Don't index 404 pages
    return render "not_found"
  end
end
```

---

## Robots.txt Configuration

### File: `public/robots.txt`

For static setup (multiple websites sharing same domain):

```
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /site_admin/
Disallow: /tenant_admin/
Disallow: /editor
Disallow: /*.js
Disallow: /*.css
Disallow: /search
Crawl-delay: 1

# Future sitemap location
Sitemap: https://example.com/sitemap.xml
```

### For Dynamic Robots.txt (Multi-Tenant)

Create: `app/controllers/robots_txt_controller.rb`

```ruby
class RobotsTxtController < ApplicationController
  def show
    @website = @current_website
    respond_to do |format|
      format.text { render action: 'show' }
    end
  end
end
```

Create: `app/views/robots_txt/show.text.erb`

```erb
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /site_admin/
Disallow: /tenant_admin/
Disallow: /editor
Disallow: /*.js
Disallow: /*.css
Disallow: /search
Crawl-delay: 1

<% if @website.seo_settings&.dig('enable_sitemap') %>
Sitemap: <%= request.base_url %>/sitemap.xml
<% end %>
```

Add to `config/routes.rb`:

```ruby
scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
  get '/robots.txt', to: 'robots_txt#show', format: 'text'
end
```

---

## Sitemap Generation

### Option 1: Using sitemap_generator Gem (Recommended)

Add to Gemfile:
```ruby
gem 'sitemap_generator'
```

Create: `config/sitemap.rb`

```ruby
SitemapGenerator::Sitemap.default_host = 'https://example.com'
SitemapGenerator::Sitemap.sitemaps_host = 'https://example.com/'
SitemapGenerator::Sitemap.public_path = 'public/'
SitemapGenerator::Sitemap.search_engines = {
  google: 'http://www.google.com/webmasters/tools/ping?sitemap=%s',
  bing: 'http://www.bing.com/ping?sitemap=%s'
}

SitemapGenerator::Sitemap.create do
  # Static pages
  add root_path, changefreq: 'daily', priority: 1.0
  add '/buy', changefreq: 'daily', priority: 0.8
  add '/rent', changefreq: 'daily', priority: 0.8
  add '/contact-us', changefreq: 'monthly', priority: 0.6

  # Properties - only visible ones
  Pwb::ListedProperty.visible.find_each do |property|
    if property.for_sale
      add prop_show_for_sale_path(
        id: property.slug,
        url_friendly_title: property.slug
      ),
      lastmod: property.updated_at,
      changefreq: 'weekly',
      priority: 0.8
    end

    if property.for_rent
      add prop_show_for_rent_path(
        id: property.slug,
        url_friendly_title: property.slug
      ),
      lastmod: property.updated_at,
      changefreq: 'weekly',
      priority: 0.8
    end
  end

  # Pages
  Pwb::Page.where(visible: true).find_each do |page|
    add show_page_path(page_slug: page.slug),
      lastmod: page.updated_at,
      changefreq: 'monthly',
      priority: 0.6
  end
end
```

### Option 2: Custom Sitemap Controller

Create: `app/controllers/sitemaps_controller.rb`

```ruby
class SitemapsController < ApplicationController
  skip_authentication!  # Adjust based on auth strategy
  
  def index
    @website = @current_website
    
    @property_count = @website.listed_properties.visible.count
    @page_count = @website.pages.where(visible: true).count
    
    # Calculate number of sitemap files needed (50k URLs per file)
    @sitemap_count = ((@property_count + @page_count) / 50000.0).ceil
    
    respond_to do |format|
      format.xml { render action: 'index' }
    end
  end

  def show
    @website = @current_website
    page = params[:page].to_i
    
    case params[:type]
    when 'properties'
      @urls = build_property_urls(page)
    when 'pages'
      @urls = build_page_urls(page)
    else
      @urls = []
    end
    
    respond_to do |format|
      format.xml { render action: 'show' }
    end
  end

  private

  def build_property_urls(page)
    per_page = 50000
    offset = (page - 1) * per_page

    @website.listed_properties.visible.limit(per_page).offset(offset).map do |property|
      urls = []
      
      if property.for_sale
        urls << {
          loc: prop_show_for_sale_url(
            id: property.slug,
            url_friendly_title: property.slug
          ),
          lastmod: property.updated_at,
          changefreq: 'weekly',
          priority: 0.8
        }
      end
      
      if property.for_rent
        urls << {
          loc: prop_show_for_rent_url(
            id: property.slug,
            url_friendly_title: property.slug
          ),
          lastmod: property.updated_at,
          changefreq: 'weekly',
          priority: 0.8
        }
      end
      
      urls
    end.flatten
  end

  def build_page_urls(page)
    per_page = 50000
    offset = (page - 1) * per_page

    @website.pages.where(visible: true).limit(per_page).offset(offset).map do |page_obj|
      {
        loc: show_page_url(page_slug: page_obj.slug),
        lastmod: page_obj.updated_at,
        changefreq: 'monthly',
        priority: 0.6
      }
    end
  end
end
```

Create: `app/views/sitemaps/index.xml.builder`

```ruby
xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.sitemapindex(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
  # Add properties sitemap
  if @property_count > 0
    @sitemap_count.times do |i|
      xml.sitemap do
        xml.loc sitemaps_url(type: 'properties', page: i + 1, format: :xml)
        xml.lastmod Time.current.iso8601
      end
    end
  end

  # Add pages sitemap
  if @page_count > 0
    xml.sitemap do
      xml.loc sitemaps_url(type: 'pages', page: 1, format: :xml)
      xml.lastmod Time.current.iso8601
    end
  end

  # Add static pages sitemap
  xml.sitemap do
    xml.loc sitemaps_url(type: 'static', format: :xml)
    xml.lastmod Time.current.iso8601
  end
end
```

Create: `app/views/sitemaps/show.xml.builder`

```ruby
xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
  @urls.each do |url|
    xml.url do
      xml.loc url[:loc]
      xml.lastmod url[:lastmod].iso8601
      xml.changefreq url[:changefreq]
      xml.priority url[:priority]
    end
  end
end
```

Add routes:
```ruby
get '/sitemap.xml', to: 'sitemaps#index'
get '/sitemap/:type.xml', to: 'sitemaps#show'
```

---

## Structured Data (JSON-LD)

### Add to Property Show Template

In `app/themes/default/views/pwb/props/show.html.erb`:

```erb
<% page_title @property_details.title  %>
<%= render '/pwb/props/meta_tags' %>
<%= render_property_schema(@property_details) %>
<%= render_breadcrumb_schema(breadcrumb_items) %>
<!-- ... rest of template ... -->
```

### Add to Homepage

In `app/themes/default/views/pwb/welcome/index.html.erb`:

```erb
<% page_title @page_title %>
<%= render_organization_schema(@current_website) %>
<%= render_breadcrumb_schema([{ name: 'Home', url: root_url }]) %>
<!-- ... rest of template ... -->
```

---

## Testing SEO Implementation

### Tools to Test:

1. **Google Rich Results Test**
   - https://search.google.com/test/rich-results
   - Validates schema.org markup

2. **Meta Tag Validation**
   - Open Graph Debugger: https://developers.facebook.com/tools/debug/
   - Twitter Card Validator: https://cards-dev.twitter.com/validator

3. **Sitemap Validation**
   - Google Search Console: https://search.google.com/search-console
   - XML Sitemap Validator: https://www.xml-sitemaps.com/validate-xml-sitemap.html

4. **Mobile Friendliness**
   - Google Mobile-Friendly Test: https://search.google.com/test/mobile-friendly

---

## Deployment Considerations

1. **Regenerate Sitemaps on Deploy**
   - Add rake task to deployment script
   - Or use cron job to regenerate weekly

2. **Update robots.txt**
   - Ensure sitemap URL is correct for production domain

3. **Submit to Search Engines**
   - Google Search Console
   - Bing Webmaster Tools

4. **Monitor with Analytics**
   - Track organic search traffic
   - Monitor Google Search Console for indexing issues
   - Use Sentry for error tracking

5. **Performance**
   - Monitor page load times
   - Optimize image sizes (especially og:image)
   - Consider caching sitemap responses

---

**Last Updated:** December 8, 2025
