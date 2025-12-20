# Meta Tags Implementation Guide

## Overview

This guide explains how to implement, customize, or extend the meta tag system in PropertyWebBuilder for property listing pages.

## Understanding the System

### Architecture Diagram

```
HTTP Request
    ↓
routes.rb
    ↓
PropsController#show_for_sale or show_for_rent
    ↓
set_property_seo(@property_details, 'for_sale')  [SeoHelper]
    ↓
render "/pwb/props/show"
    ↓
application.html.erb layout
    ↓
<head>
  <%= seo_title %>
  <%= seo_meta_tags %>
  <%= yield(:page_head) %>
</head>
    ↓
_meta_tags.html.erb partial (property-specific JSON-LD)
    ↓
Rendered HTML with all meta tags
```

## Step-by-Step: How Meta Tags Work

### 1. Request Arrives

```
GET /properties/for-sale/apartment-123/beautiful-3br-apartment
      ↓ routed to
PropsController#show_for_sale with id="apartment-123"
```

### 2. Controller Loads Property

```ruby
# app/controllers/pwb/props_controller.rb
def show_for_sale
  @property_details = find_property_by_slug_or_id(params[:id])  # Finds by slug first, then ID
  
  if @property_details && @property_details.visible && @property_details.for_sale
    set_property_seo(@property_details, 'for_sale')  # SEO SETUP HERE
    render "/pwb/props/show"
  end
end

private

def set_property_seo(property, operation_type)
  canonical_path = property.contextual_show_path(operation_type)
  canonical_url = "#{request.protocol}#{request.host_with_port}#{canonical_path}"
  
  # Get custom SEO fields if set, otherwise use defaults
  seo_title_value = property.seo_title.presence || property.title
  meta_desc_value = property.meta_description.presence || truncate_description(property.description)
  
  # Call helper to set SEO data
  set_seo(
    title: seo_title_value,
    description: meta_desc_value,
    canonical_url: canonical_url,
    image: property.primary_image_url,
    og_type: 'product'  # Real estate listing
  )
  
  @seo_property = property  # For JSON-LD in views
end
```

### 3. Helper Stores Data

```ruby
# app/helpers/seo_helper.rb
def set_seo(options = {})
  @seo_data ||= {}
  @seo_data.merge!(options)  # Stores in controller instance
end
```

### 4. View Renders Layout

```erb
<!-- app/themes/*/views/layouts/pwb/application.html.erb -->
<head>
  <title><%= seo_title %></title>
  <%= seo_meta_tags %>      <!-- ALL meta tags -->
  <%= yield(:page_head) %>  <!-- Additional property-specific tags -->
</head>
```

### 5. Helper Generates Meta Tags

```ruby
# app/helpers/seo_helper.rb
def seo_meta_tags
  tags = []
  
  # Basic meta tags
  tags << tag.meta(name: 'description', content: seo_description)
  tags << tag.link(rel: 'canonical', href: seo_canonical_url)
  
  # Open Graph tags
  tags << tag.meta(property: 'og:type', content: 'product')
  tags << tag.meta(property: 'og:title', content: seo_title)
  tags << tag.meta(property: 'og:image', content: seo_image)
  
  # Twitter Card tags
  tags << tag.meta(name: 'twitter:card', content: 'summary_large_image')
  tags << tag.meta(name: 'twitter:title', content: seo_title)
  
  safe_join(tags, "\n")
end
```

### 6. Property Partial Adds Structured Data

```erb
<!-- app/views/pwb/props/_meta_tags.html.erb -->
<% content_for :page_head do %>
  <!-- JSON-LD Structured Data -->
  <%= property_json_ld(@seo_property) %>
  <%= organization_json_ld %>
<% end %>
```

### 7. Browser Receives Complete Head

```html
<head>
  <title>Beautiful 3BR Apartment | MyAgency</title>
  
  <!-- Meta tags from seo_meta_tags -->
  <meta name="description" content="...">
  <link rel="canonical" href="...">
  <meta property="og:type" content="product">
  <meta property="og:title" content="...">
  <!-- ... more meta tags ... -->
  
  <!-- Structured data from _meta_tags.html.erb -->
  <script type="application/ld+json">
  { "@type": "RealEstateListing", ... }
  </script>
</head>
```

## Implementation Tasks

### Task 1: Add Custom SEO Fields to Admin UI

**Goal:** Allow admin users to customize SEO title and description per property

**Steps:**

1. Create or update admin property edit form:
```erb
<!-- app/views/site_admin/props/edit.html.erb -->
<%= form_with model: @prop, local: true do |form| %>
  <!-- ... existing fields ... -->
  
  <fieldset>
    <legend>SEO Settings</legend>
    
    <div class="field">
      <%= form.label :seo_title %>
      <%= form.text_field :seo_title, 
          placeholder: "Custom title for search results (50-60 chars)" %>
      <small>Leave blank to use property title</small>
    </div>
    
    <div class="field">
      <%= form.label :meta_description %>
      <%= form.text_area :meta_description, 
          placeholder: "Custom description (150-160 chars)" %>
      <small>Leave blank to auto-generate from description</small>
    </div>
  </fieldset>
  
  <%= form.submit %>
<% end %>
```

2. Update controller to permit fields:
```ruby
def prop_params
  params.require(:prop).permit(
    :title, :description,  # existing
    :seo_title, :meta_description  # new SEO fields
  )
end
```

3. Add validation to model:
```ruby
# app/models/pwb/prop.rb
validates :seo_title, length: { maximum: 60 }, allow_blank: true
validates :meta_description, length: { maximum: 160 }, allow_blank: true
```

### Task 2: Add Image Selection for OG Sharing

**Goal:** Allow selecting which property photo to use for social sharing

**Option A: Use First Photo (Current)**
- Already implemented
- Simplest approach
- Consistent across platforms

**Option B: Add Photo Selection UI**

1. Add column to select primary image:
```ruby
# db/migrate/add_og_image_index_to_props.rb
class AddOgImageIndexToProps < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_props, :og_image_index, :integer, default: 0
  end
end
```

2. Update property model:
```ruby
# app/models/pwb/prop.rb
def og_image_url
  if og_image_index.present? && og_image_index > 0
    photo = ordered_photo(og_image_index)
    photo&.image&.url
  else
    primary_image_url
  end
end
```

3. Update controller SEO setup:
```ruby
set_seo(image: @property_details.og_image_url)
```

4. Update admin UI to select photo:
```erb
<div class="field">
  <%= form.label :og_image_index, "Social Media Image" %>
  <%= form.select :og_image_index, 
      @prop.prop_photos.each_with_index.map { |p, i| 
        ["Photo #{i+1}", i+1] 
      },
      { include_blank: "Use First Photo" } %>
</div>
```

### Task 3: Improve Canonical URL Handling

**Current Implementation:**
```ruby
canonical_path = if property.slug.present?
                   property.contextual_show_path(operation_type)  # Uses slug
                 else
                   request.path  # Falls back to request path
                 end
```

**Enhancement: Always generate canonical from model**
```ruby
def set_property_seo(property, operation_type)
  # Always use slug if available, otherwise ID
  canonical_url = property.contextual_show_path(operation_type)
  canonical_url = "#{request.protocol}#{request.host}#{canonical_url}"
  
  set_seo(canonical_url: canonical_url)
end
```

### Task 4: Add Dynamic Breadcrumb Navigation

**Goal:** Improve SEO with breadcrumb structured data

**Implementation:**

1. Create breadcrumb helper:
```ruby
# app/helpers/breadcrumb_helper.rb
def property_breadcrumbs(property, operation_type)
  operation_text = operation_type == 'for_rent' ? 'Rentals' : 'Properties for Sale'
  
  [
    { name: 'Home', url: root_url },
    { name: operation_text, url: operation_type == 'for_rent' ? rent_path : buy_path },
    { name: property.title, url: request.original_url }
  ]
end
```

2. Add to property view:
```erb
<!-- app/views/pwb/props/show.html.erb -->
<% content_for :page_head do %>
  <%= breadcrumb_json_ld(property_breadcrumbs(@property_details, @operation_type)) %>
<% end %>
```

### Task 5: Add SEO Health Check Feature

**Goal:** Help content team understand SEO quality

**Implementation:**

```ruby
# app/services/property_seo_check.rb
module PropertySeoCheck
  def self.check(property)
    issues = []
    warnings = []
    
    # Critical issues
    issues << "Missing title" if property.title.blank?
    issues << "Missing description" if property.description.blank?
    issues << "No photos" if property.prop_photos.empty?
    issues << "Missing address" if property.street_address.blank?
    
    # Warnings
    warnings << "Title should be 50-60 chars (current: #{property.title&.length})" if property.title&.length.to_i > 60
    warnings << "Description should be 150-160 chars (current: #{property.description&.length})" if property.description&.length.to_i > 160
    warnings << "No SEO customization set" if property.seo_title.blank? && property.meta_description.blank?
    
    {
      issues: issues,
      warnings: warnings,
      score: 100 - (issues.count * 25) - (warnings.count * 10)
    }
  end
end
```

3. Add to admin property view:
```erb
<% check = PropertySeoCheck.check(@prop) %>
<div class="seo-health-<%= check[:score] > 75 ? 'good' : 'needs-work' %>">
  <h3>SEO Health: <%= check[:score] %>/100</h3>
  
  <% if check[:issues].any? %>
    <div class="issues">
      <h4>Critical Issues:</h4>
      <ul>
        <% check[:issues].each do |issue| %>
          <li><%= issue %></li>
        <% end %>
      </ul>
    </div>
  <% end %>
  
  <% if check[:warnings].any? %>
    <div class="warnings">
      <h4>Warnings:</h4>
      <ul>
        <% check[:warnings].each do |warning| %>
          <li><%= warning %></li>
        <% end %>
      </ul>
    </div>
  <% end %>
</div>
```

### Task 6: Add Multi-Language SEO Support

**Current:** Single language per property, with locale switching

**Enhancement: Add per-locale SEO customization**

1. Update model with translatable SEO fields:
```ruby
# app/models/pwb/prop.rb
extend Mobility
translates :title, :description, :seo_title, :meta_description
```

2. Update migrations:
```ruby
# db/migrate/add_mobility_translations.rb
create_table :pwb_prop_translations do |t|
  t.references :pwb_prop
  t.string :locale
  t.string :seo_title
  t.text :meta_description
  t.timestamps
end
```

3. Use in controller:
```ruby
def set_property_seo(property, operation_type)
  # Mobility handles locale automatically
  seo_title_value = property.seo_title.presence || property.title
  
  # For hreflang
  alternate_urls = I18n.available_locales.map do |locale|
    path = property.contextual_show_path(operation_type)
    [locale, "#{request.protocol}#{request.host}#{locale}/#{path}"]
  end.to_h
  
  set_seo(
    title: seo_title_value,
    alternate_urls: alternate_urls
  )
end
```

## Common Patterns

### Pattern 1: Override Default SEO for Specific Property

```ruby
# In controller
property = Pwb::ListedProperty.find(params[:id])

if property.seo_title.present?
  # Use custom SEO
  title = property.seo_title
else
  # Use default
  title = "#{property.title} - #{property.location}"
end

set_seo(title: title)
```

### Pattern 2: Add Price to Meta Description

```ruby
def set_property_seo(property, operation_type)
  price_text = property.contextual_price_with_currency(operation_type)
  description = "#{truncate_description(property.description)} | #{price_text}"
  
  set_seo(description: description)
end
```

### Pattern 3: Conditional OG Type Based on Property

```ruby
og_type = case property.prop_type_key
          when 'types.apartment'
            'product'
          when 'types.commercial'
            'business.business'
          else
            'product'
          end

set_seo(og_type: og_type)
```

## Testing

### Manual Testing Checklist

- [ ] Visit property page: `/properties/for-sale/123/title`
- [ ] Inspect `<head>` element for meta tags
- [ ] Verify canonical URL is correct
- [ ] Check og:image points to a valid image
- [ ] Validate JSON-LD with https://schema.org/validate
- [ ] Test with Facebook debugger
- [ ] Test with Twitter validator
- [ ] Test with Google Rich Results tool

### Automated Testing

```ruby
# spec/controllers/pwb/props_controller_spec.rb
describe PropsController do
  describe 'show_for_sale' do
    let(:property) { create(:listed_property, for_sale: true, visible: true) }
    
    it 'sets correct SEO meta tags' do
      get :show_for_sale, params: { id: property.slug }
      
      expect(assigns(:seo_data)[:title]).to eq(property.title)
      expect(assigns(:seo_data)[:canonical_url]).to include(property.slug)
      expect(assigns(:seo_data)[:og_type]).to eq('product')
    end
    
    it 'uses custom SEO title when set' do
      property.update(seo_title: 'Custom SEO Title')
      get :show_for_sale, params: { id: property.slug }
      
      expect(assigns(:seo_data)[:title]).to eq('Custom SEO Title')
    end
  end
end
```

## Database Schema

### Existing SEO Columns

```ruby
# pwb_props table
add_column :pwb_props, :seo_title, :string
add_column :pwb_props, :meta_description, :text

# pwb_websites table  
add_column :pwb_websites, :default_meta_description, :text

# pwb_pages table
add_column :pwb_pages, :seo_title, :string
add_column :pwb_pages, :meta_description, :text
```

### Potential Extensions

```ruby
# For advanced SEO
add_column :pwb_props, :og_image_index, :integer, default: 0
add_column :pwb_props, :seo_keywords, :text  # Informational, not meta tag
add_column :pwb_props, :slug, :string
add_column :pwb_props, :internal_seo_notes, :text

add_index :pwb_props, :slug
```

## Troubleshooting

### Meta Tags Not Appearing

**Debug Steps:**
1. Check layout includes `<%= seo_meta_tags %>`
2. Verify controller calls `set_seo()`
3. Inspect page source to confirm tags exist
4. Clear browser cache and hard refresh

**Common Cause:** Theme layout doesn't include seo_meta_tags

```erb
<!-- app/themes/custom/views/layouts/pwb/application.html.erb -->
<head>
  <title><%= seo_title %></title>
  <%= seo_meta_tags %>  <!-- ADD THIS LINE -->
</head>
```

### Wrong Title Showing

**Debug Steps:**
1. Check `@seo_data[:title]` in controller
2. Verify `seo_title` field has data
3. Check `include_site_name` setting

**Common Cause:** Using page_title instead of SEO title

```ruby
# Wrong
@page_title = "Property Name"  # Used for display only

# Right
set_seo(title: "Custom SEO Title")
```

### Images Not in OG Tags

**Debug Steps:**
1. Verify property has photos
2. Check `primary_image_url` method returns valid URL
3. Verify image dimensions (1200x630 recommended)

**Test:**
```ruby
property = Pwb::ListedProperty.find(123)
puts property.primary_image_url  # Should print URL
```

## Performance Optimization

### Eager Loading

```ruby
# Property query with all needed data
Pwb::ListedProperty.with_eager_loading
  .where(website_id: current_website.id)
  .find_by(slug: slug)
```

### Caching

```ruby
# Cache meta tags per property per website
def seo_meta_tags
  cache_key = "seo_tags/#{@current_website.id}/#{@seo_data.hash}"
  Rails.cache.fetch(cache_key, expires_in: 1.day) do
    # Generate tags
  end
end
```

### Image Optimization

```ruby
# Use CDN with image optimization
def seo_image
  image_url = property.primary_image_url
  # Add CDN optimization parameters
  "#{image_url}?w=1200&h=630&fit=crop&quality=auto"
end
```

## Security Considerations

- All user input is HTML-escaped by Rails ERB
- Canonical URLs use `request.protocol` to respect HTTPS
- No sensitive data should be in meta tags
- Multi-tenant scoping via `current_website` prevents data leaks

## Resources

- [Open Graph Protocol](https://ogp.me/)
- [Twitter Card Documentation](https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/abouts-cards)
- [Schema.org RealEstateListing](https://schema.org/RealEstateListing)
- [Google Search Central - Structured Data](https://developers.google.com/search/docs/appearance/structured-data)
- [MDN - Meta Tags](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta)
