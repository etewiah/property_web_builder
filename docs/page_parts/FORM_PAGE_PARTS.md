# Form Page Parts - Implementation Guide

This document describes how to extend the Page Parts system to support contact forms that can be placed on any page in PropertyWebBuilder.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Page Part Definitions](#page-part-definitions)
4. [Liquid Template Patterns](#liquid-template-patterns)
5. [Stimulus Controller Integration](#stimulus-controller-integration)
6. [API Endpoint](#api-endpoint)
7. [Styling Guidelines](#styling-guidelines)
8. [Seeding Configuration](#seeding-configuration)
9. [Testing](#testing)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### The Problem

The legacy `form_and_map` page part has limitations:
- Tightly coupled to the contact page
- No configurable fields
- Limited customization options
- Uses `is_rails_part: true` which bypasses the modern Liquid system

### The Solution

Create modern form page parts using the established PagePartLibrary pattern:
- Hash-based field definitions with explicit types and metadata
- Liquid templates for rendering
- Stimulus controllers for AJAX form submission
- Existing `/api_public/v1/contact` endpoint for processing
- Full multilingual support via `block_contents`

### Available Form Page Parts

| Page Part Key | Description |
|---------------|-------------|
| `contact_general_enquiry` | General purpose contact form (recommended) |
| `contact_location_map` | Contact form with integrated Leaflet map |
| `form_and_map` | Legacy contact form (maintained for backward compatibility) |

---

## Naming Conventions

### Why Naming Matters

Page part keys serve multiple purposes:
1. **Database identifiers** - Stored in `page_part_key` columns
2. **Template file paths** - Map to Liquid template locations
3. **API endpoints** - May be used in URLs for editing or fetching
4. **Seed file names** - Used in YAML configuration files
5. **Developer communication** - Should be self-documenting

### URL Compatibility Requirements

Page part keys may appear in URLs such as:
- `/editor/page_parts/:page_part_key/edit`
- `/api/v1/page_parts/:page_part_key`
- `/api_public/v1/liquid_page/:page_slug/parts/:page_part_key`

**Avoid slashes** (`/`) in page part keys as they:
- Break URL routing without special encoding
- Complicate API design
- Create ambiguity with path segments

### Naming Pattern

Use the pattern: `{category}_{purpose}_{variant}`

```
{category}     - What type of page part (contact, hero, cta, etc.)
{purpose}      - What it does (enquiry, newsletter, callback, etc.)
{variant}      - Optional: specific style or layout (centered, split, minimal)
```

### Examples

| Good Name | Bad Name | Reason |
|-----------|----------|--------|
| `contact_general_enquiry` | `contact_form` | Too generic - many contact forms exist |
| `contact_location_map` | `forms/contact_with_map` | Slash breaks URLs |
| `contact_property_enquiry` | `property_contact` | Category first for consistency |
| `hero_search_centered` | `hero_1` | Descriptive, not numbered |
| `newsletter_signup_footer` | `newsletter` | Specifies placement context |
| `cta_consultation_booking` | `cta_banner` | Describes actual purpose |

### Form Page Part Names

For contact/enquiry forms, use descriptive names based on purpose:

| Purpose | Recommended Name | Description |
|---------|------------------|-------------|
| General enquiries | `contact_general_enquiry` | Basic contact form for any page |
| With map display | `contact_location_map` | Form + office location map |
| Property-specific | `contact_property_enquiry` | Enquiry about a specific listing |
| Valuation request | `contact_valuation_request` | Request property valuation |
| Callback request | `contact_callback_request` | Request a phone callback |
| Newsletter signup | `newsletter_signup_inline` | Email capture form |
| Agent contact | `contact_agent_direct` | Contact a specific agent |

### Template File Organization

Even without slashes in keys, organize template files in subdirectories:

```
app/views/pwb/page_parts/
├── contact/                          # Category directory
│   ├── contact_general_enquiry.liquid
│   ├── contact_location_map.liquid
│   └── contact_property_enquiry.liquid
├── heroes/
│   └── hero_search_centered.liquid
└── cta/
    └── cta_consultation_booking.liquid
```

The `PagePartLibrary.template_path` method should handle this mapping:

```ruby
# Template lookup order:
# 1. app/views/pwb/page_parts/{category}/{key}.liquid
# 2. app/views/pwb/page_parts/{key}.liquid
```

### Seed File Naming

Seed files follow the pattern: `{page_slug}__{page_part_key}.yml`

```
db/yml_seeds/page_parts/
├── home__contact_general_enquiry.yml
├── contact__contact_location_map.yml
└── website__newsletter_signup_footer.yml
```

### Migration from Slash-Based Names

If migrating from slash-based names like `forms/contact_form`:

1. Create new definition with underscore name
2. Add migration to update existing records
3. Keep old key as alias during transition
4. Update all template references
5. Remove old definition after transition period

```ruby
# In PagePartLibrary, temporarily support both:
DEFINITIONS = {
  'contact_general_enquiry' => { ... },

  # Alias for backward compatibility (remove after migration)
  'forms/contact_form' => :alias_of_contact_general_enquiry
}
```

### Validation Rules

Page part keys should:
- Use only lowercase letters, numbers, and underscores
- Start with a letter (the category)
- Be 3-50 characters long
- Not contain consecutive underscores
- Be unique within the system

```ruby
# Validation regex
PAGE_PART_KEY_PATTERN = /\A[a-z][a-z0-9]*(_[a-z0-9]+)*\z/

# Valid examples:
# contact_general_enquiry ✓
# hero_search_centered ✓
# cta_v2 ✓

# Invalid examples:
# forms/contact_form ✗ (contains slash)
# Contact_Form ✗ (uppercase)
# _contact_form ✗ (starts with underscore)
# contact__form ✗ (consecutive underscores)
```

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    FORM PAGE PARTS SYSTEM                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐                                       │
│  │   PagePartLibrary    │                                       │
│  │   (Definitions)      │                                       │
│  │                      │                                       │
│  │   contact_general_..  │◀──── Field schema, types, groups     │
│  │   contact_location_.. │                                       │
│  └──────────────────────┘                                       │
│            │                                                    │
│            ▼                                                    │
│  ┌──────────────────────┐    ┌──────────────────────┐          │
│  │   Liquid Templates   │    │  Stimulus Controllers │          │
│  │                      │    │                       │          │
│  │   contact_form.liquid│───▶│  contact_form_ctrl.js │          │
│  │   contact_with_map.. │    │  map_controller.js    │          │
│  └──────────────────────┘    └───────────┬───────────┘          │
│                                          │                      │
│                                          ▼                      │
│                              ┌──────────────────────┐           │
│                              │   API Endpoint       │           │
│                              │                      │           │
│                              │  POST /api_public/   │           │
│                              │  v1/:locale/contact  │           │
│                              └──────────────────────┘           │
│                                          │                      │
│                                          ▼                      │
│                              ┌──────────────────────┐           │
│                              │   Pwb::Contact       │           │
│                              │   Pwb::Message       │           │
│                              │   ContactMailer      │           │
│                              └──────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Editor** places a form page part on any page via admin UI
2. **Editor** configures fields (title, which inputs to show, messages)
3. **Configuration** saved to `PagePart.block_contents` (JSON, locale-scoped)
4. **Liquid template** renders form based on configuration
5. **Stimulus controller** handles AJAX submission
6. **API endpoint** creates Contact/Message records
7. **Mailer** sends notification email

---

## Page Part Definitions

### Location

All page part definitions are in:
```
app/lib/pwb/page_part_library.rb
```

### contact_general_enquiry Definition

```ruby
'contact_general_enquiry' => {
  category: :contact,
  label: 'General Enquiry Form',
  description: 'Configurable contact form for general enquiries on any page',
  fields: {
    # Section header (editable content)
    section_title: {
      type: :text,
      label: 'Section Title',
      hint: 'Title displayed above the form',
      placeholder: 'e.g., Contact Us',
      default: 'Contact Us',
      max_length: 80,
      group: :header,
      content_guidance: {
        recommended_length: '15-40 characters',
        best_practice: 'Keep it clear and action-oriented'
      }
    },
    section_subtitle: {
      type: :textarea,
      label: 'Section Description',
      hint: 'Optional text below the title',
      max_length: 250,
      rows: 2,
      group: :header
    },

    # Form configuration
    show_phone_field: {
      type: :boolean,
      label: 'Show Phone Field',
      hint: 'Whether to display the phone number input',
      default: true,
      group: :form_config
    },
    show_subject_field: {
      type: :boolean,
      label: 'Show Subject Field',
      hint: 'Whether to display the subject/topic input',
      default: true,
      group: :form_config
    },
    submit_button_text: {
      type: :text,
      label: 'Submit Button Text',
      default: 'Send Message',
      max_length: 30,
      group: :form_config
    },

    # Messages
    success_message: {
      type: :textarea,
      label: 'Success Message',
      hint: 'Message shown after successful form submission',
      default: 'Thank you! We will get back to you soon.',
      max_length: 300,
      group: :messages
    },

    # Appearance
    form_style: {
      type: :select,
      label: 'Form Style',
      choices: [
        { value: 'default', label: 'Default (Card)' },
        { value: 'minimal', label: 'Minimal (No Border)' },
        { value: 'shadowed', label: 'Elevated (Shadow)' }
      ],
      default: 'default',
      group: :appearance
    }
  },
  field_groups: {
    header: { label: 'Section Header', order: 1 },
    form_config: { label: 'Form Settings', order: 2 },
    messages: { label: 'Messages', order: 3 },
    appearance: { label: 'Appearance', order: 4 }
  }
}
```

### Field Types Reference

| Type | Editor Component | Description |
|------|-----------------|-------------|
| `:text` | TextInput | Single-line text input |
| `:textarea` | TextArea | Multi-line text input |
| `:boolean` | Checkbox/Toggle | True/false value |
| `:select` | Dropdown | Choose from predefined options |
| `:number` | NumberInput | Numeric value |
| `:email` | EmailInput | Email with validation |
| `:phone` | PhoneInput | Phone number input |
| `:url` | UrlInput | URL with validation |

### Field Metadata Options

```ruby
{
  type: :text,              # Required: field type
  label: 'Display Label',   # Label shown in editor
  hint: 'Help text',        # Guidance for editors
  placeholder: 'Example',   # Input placeholder
  required: true,           # Validation flag
  default: 'value',         # Default value
  max_length: 100,          # Character limit
  group: :group_key,        # Field group for organization
  choices: [                # For :select type
    { value: 'v1', label: 'Option 1' }
  ],
  content_guidance: {       # Best practice tips
    recommended_length: '...',
    best_practice: '...'
  }
}
```

---

## Liquid Template Patterns

### Template Location

Form templates are stored in category subdirectories:
```
app/views/pwb/page_parts/contact/
├── contact_general_enquiry.liquid
└── contact_location_map.liquid
```

Or directly in the page_parts directory:
```
app/views/pwb/page_parts/
├── contact_general_enquiry.liquid
└── contact_location_map.liquid
```

### Accessing Field Values

Fields are accessed through the `page_part` variable:

```liquid
{% comment %} Basic access {% endcomment %}
{{ page_part.field_name.content }}

{% comment %} With default fallback {% endcomment %}
{{ page_part.section_title.content | default: 'Contact Us' }}

{% comment %} Conditional rendering {% endcomment %}
{% if page_part.section_subtitle.content != blank %}
  <p>{{ page_part.section_subtitle.content }}</p>
{% endif %}

{% comment %} Boolean field handling {% endcomment %}
{% assign show_phone = page_part.show_phone_field.content | default: 'true' %}
{% if show_phone == 'true' or show_phone == true %}
  <!-- render phone field -->
{% endif %}
```

### Template Structure

```liquid
{% comment %}
  Contact Form Page Part
  ======================
  Document available variables and purpose
{% endcomment %}

{% comment %} Extract field values with defaults {% endcomment %}
{% assign form_style = page_part.form_style.content | default: 'default' %}
{% assign submit_text = page_part.submit_button_text.content | default: 'Send Message' %}
{% assign success_msg = page_part.success_message.content | default: 'Thank you!' %}

<section class="pwb-section pwb-contact-form py-12 md:py-16 bg-gray-50">
  <div class="pwb-container max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">

    {% comment %} Section Header {% endcomment %}
    {% if page_part.section_title.content != blank %}
      <div class="pwb-section__header text-center mb-8">
        <h2 class="text-2xl md:text-3xl font-bold text-gray-900">
          {{ page_part.section_title.content }}
        </h2>
        {% if page_part.section_subtitle.content != blank %}
          <p class="text-gray-600 mt-3">{{ page_part.section_subtitle.content }}</p>
        {% endif %}
      </div>
    {% endif %}

    {% comment %} Form with Stimulus Controller {% endcomment %}
    <div data-controller="contact-form"
         data-contact-form-submit-url-value="/api_public/v1/{{ current_locale }}/contact"
         data-contact-form-success-message-value="{{ success_msg | escape }}">

      <form data-contact-form-target="form"
            data-action="submit->contact-form#submit">
        <!-- Form fields here -->
        <div data-contact-form-target="result"></div>
        <button type="submit" data-contact-form-target="submitButton">
          {{ submit_text }}
        </button>
      </form>
    </div>

  </div>
</section>
```

### Available Liquid Variables

| Variable | Description |
|----------|-------------|
| `page_part` | Hash of field values from `block_contents` |
| `current_locale` | Current language code (e.g., "en", "es") |
| `website` | Current website object |
| `agency` | Agency settings (may include coordinates) |

---

## Stimulus Controller Integration

### contact_form_controller.js

**Location:** `app/javascript/controllers/contact_form_controller.js`

The controller handles:
- Form submission via AJAX (fetch API)
- Loading state (spinner on button)
- Success/error message display
- Form reset after successful submission

### Controller Values

| Value | Type | Description |
|-------|------|-------------|
| `submitUrl` | String | API endpoint URL |
| `successMessage` | String | Custom success message |
| `errorMessage` | String | Custom error message |

### Controller Targets

| Target | Element | Purpose |
|--------|---------|---------|
| `form` | `<form>` | The form element |
| `result` | `<div>` | Container for success/error messages |
| `submitButton` | `<button>` | Submit button (for loading state) |

### HTML Data Attributes

```html
<div data-controller="contact-form"
     data-contact-form-submit-url-value="/api_public/v1/en/contact"
     data-contact-form-success-message-value="Thank you!">

  <form data-contact-form-target="form"
        data-action="submit->contact-form#submit">

    <input type="hidden" name="contact[locale]" value="en">
    <input type="text" name="contact[name]" required>
    <input type="email" name="contact[email]" required>
    <input type="tel" name="contact[phone]">
    <input type="text" name="contact[subject]">
    <textarea name="contact[message]" required></textarea>

    <div data-contact-form-target="result"></div>

    <button type="submit" data-contact-form-target="submitButton">
      Send
    </button>
  </form>
</div>
```

### map_controller.js

**Location:** `app/javascript/controllers/map_controller.js`

For the `contact_location_map` template, the map controller provides:
- Leaflet map initialization
- Marker placement
- Popup content

### Map Controller Values

| Value | Type | Description |
|-------|------|-------------|
| `markers` | Array | Array of marker objects with positions |
| `zoom` | Number | Initial zoom level (default: 13) |
| `scrollWheelZoom` | Boolean | Enable scroll wheel zoom (default: false) |

### Map HTML Data Attributes

```html
<div data-controller="map"
     data-map-markers-value='[{"id":"office","title":"Our Office","position":{"lat":40.7128,"lng":-74.0060}}]'
     data-map-zoom-value="14"
     data-map-scroll-wheel-zoom-value="false"
     data-map-target="canvas"
     style="height: 400px;">
</div>
```

---

## API Endpoint

### POST /api_public/v1/:locale/contact

**Controller:** `ApiPublic::V1::ContactController`

**Location:** `app/controllers/api_public/v1/contact_controller.rb`

### Request Parameters

```json
{
  "contact": {
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1 555-123-4567",
    "subject": "General Inquiry",
    "message": "Hello, I have a question..."
  }
}
```

### Success Response (201 Created)

```json
{
  "success": true,
  "message": "Thank you for your message. We'll get back to you soon.",
  "data": {
    "contact_id": 123,
    "message_id": 456
  }
}
```

### Error Response (422 Unprocessable Entity)

```json
{
  "success": false,
  "errors": ["Email is required."]
}
```

### What Happens on Submission

1. Validates email is present
2. Finds or creates `Pwb::Contact` by email
3. Creates `Pwb::Message` with content and metadata
4. Sends email via `ContactMailer.general_enquiry` (async)
5. Returns JSON response

---

## Styling Guidelines

### CSS Classes Convention

Use semantic, BEM-style class names:

```html
<!-- Good: Semantic classes -->
<section class="pwb-section pwb-contact-form">
  <div class="pwb-section__header">
    <h2 class="pwb-section__title">...</h2>
  </div>
  <div class="pwb-contact-form__wrapper">
    <form class="pwb-form">
      <div class="pwb-form__field">...</div>
      <button class="pwb-btn pwb-btn--primary">...</button>
    </form>
  </div>
</section>

<!-- Avoid: Utility-only classes in templates -->
<section class="py-12 bg-gray-50">...</section>
```

### Tailwind CSS Usage

Templates can use Tailwind utilities for:
- Spacing (py-12, px-4, mb-8)
- Layout (flex, grid, max-w-3xl)
- Responsive (md:py-16, lg:grid-cols-2)
- States (hover:bg-blue-700, focus:ring-2)

### Form Input Styling

```css
.pwb-form__input,
.pwb-form__textarea {
  @apply w-full px-4 py-2.5 border border-gray-300 rounded-md;
  @apply focus:ring-2 focus:ring-blue-500 focus:border-blue-500;
  @apply transition-colors;
}

.pwb-btn--primary {
  @apply px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white;
  @apply font-medium rounded-md transition-colors;
  @apply focus:outline-none focus:ring-2 focus:ring-blue-500;
  @apply disabled:opacity-50 disabled:cursor-not-allowed;
}
```

### Theme Override Location

Themes can override form styles in:
```
app/themes/{theme_name}/assets/stylesheets/
```

---

## Seeding Configuration

### Creating Form Page Parts via Seeds

**YAML Seed File:** `db/yml_seeds/page_parts/contact__contact_general_enquiry.yml`

```yaml
- page_slug: contact
  page_part_key: contact_general_enquiry
  block_contents:
    en:
      blocks:
        section_title:
          content: "Get in Touch"
        section_subtitle:
          content: "Have a question? We'd love to hear from you."
        show_phone_field:
          content: "true"
        show_subject_field:
          content: "true"
        submit_button_text:
          content: "Send Message"
        success_message:
          content: "Thank you! We'll respond within 24 hours."
        form_style:
          content: "default"
    es:
      blocks:
        section_title:
          content: "Contáctenos"
        section_subtitle:
          content: "¿Tiene alguna pregunta? Nos encantaría saber de usted."
        submit_button_text:
          content: "Enviar Mensaje"
        success_message:
          content: "¡Gracias! Responderemos dentro de 24 horas."
  order_in_editor: 1
  show_in_editor: true
```

### Content Translations

**YAML File:** `db/yml_seeds/content_translations/en.yml`

```yaml
en:
  contact:
    contact_general_enquiry:
      section_title: "Get in Touch"
      section_subtitle: "We'd love to hear from you."
      submit_button_text: "Send Message"
      success_message: "Thank you! We'll be in touch soon."
```

### Programmatic Creation

```ruby
# Create page part with PagePartManager
page = Pwb::Page.find_by(slug: 'contact')
manager = Pwb::PagePartManager.new('contact_general_enquiry', page)

content = {
  'section_title' => 'Contact Us',
  'section_subtitle' => 'Questions? Get in touch.',
  'show_phone_field' => 'true',
  'show_subject_field' => 'true',
  'submit_button_text' => 'Send',
  'success_message' => 'Thanks!',
  'form_style' => 'default'
}

manager.seed_container_block_content('en', content)
manager.set_default_page_content_order_and_visibility
```

---

## Testing

### Unit Tests for PagePartLibrary

```ruby
# spec/lib/pwb/page_part_library_spec.rb

RSpec.describe Pwb::PagePartLibrary do
  describe 'contact_general_enquiry' do
    let(:definition) { described_class.definition('contact_general_enquiry') }

    it 'exists in definitions' do
      expect(definition).to be_present
    end

    it 'has category :contact' do
      expect(definition[:category]).to eq(:contact)
    end

    it 'has expected fields' do
      fields = definition[:fields]
      expect(fields).to include(:section_title, :show_phone_field, :success_message)
    end

    it 'has field groups' do
      groups = definition[:field_groups]
      expect(groups.keys).to include(:header, :form_config, :messages)
    end
  end

  describe 'template_exists?' do
    it 'finds contact_general_enquiry template' do
      expect(described_class.template_exists?('contact_general_enquiry')).to be true
    end
  end
end
```

### Request Specs for Contact API

```ruby
# spec/requests/api_public/v1/contact_spec.rb

RSpec.describe 'ApiPublic::V1::Contact', type: :request do
  let!(:website) { create(:website) }

  before do
    host! website.host
  end

  describe 'POST /api_public/v1/contact' do
    let(:valid_params) do
      {
        contact: {
          name: 'Test User',
          email: 'test@example.com',
          phone: '555-1234',
          message: 'Hello!'
        }
      }
    end

    it 'creates contact and message' do
      expect {
        post '/api_public/v1/contact', params: valid_params
      }.to change(Pwb::Contact, :count).by(1)
        .and change(Pwb::Message, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['success']).to be true
    end

    it 'returns error for missing email' do
      post '/api_public/v1/contact', params: { contact: { name: 'Test' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['success']).to be false
    end
  end
end
```

### System Tests for Form Rendering

```ruby
# spec/system/page_parts/contact_general_enquiry_spec.rb

RSpec.describe 'Contact General Enquiry Page Part', type: :system, js: true do
  let!(:website) { create(:website) }
  let!(:page) { create(:page, website: website, slug: 'contact') }

  before do
    create_page_part('contact', 'contact_general_enquiry')
    seed_page_part_content(page, 'contact_general_enquiry', 'en',
      section_title: 'Contact Us',
      show_phone_field: 'true'
    )
  end

  it 'renders the contact form' do
    visit '/p/contact'

    expect(page).to have_content('Contact Us')
    expect(page).to have_field('contact[name]')
    expect(page).to have_field('contact[email]')
    expect(page).to have_field('contact[phone]')
  end

  it 'submits form successfully' do
    visit '/p/contact'

    fill_in 'contact[name]', with: 'Test User'
    fill_in 'contact[email]', with: 'test@example.com'
    fill_in 'contact[message]', with: 'Hello!'
    click_button 'Send Message'

    expect(page).to have_content('Thank you!')
  end
end
```

---

## Troubleshooting

### Common Issues

#### Form Not Rendering

**Symptom:** Page shows blank where form should be.

**Causes:**
1. Template file missing
2. `page_part_key` mismatch
3. `block_contents` not initialized

**Solution:**
```ruby
# Check template exists
Pwb::PagePartLibrary.template_exists?('contact_general_enquiry')

# Check page part record
page.page_parts.find_by(page_part_key: 'contact_general_enquiry')

# Initialize block_contents
manager = Pwb::PagePartManager.new('contact_general_enquiry', page)
manager.seed_container_block_content('en', {})
```

#### Stimulus Controller Not Connecting

**Symptom:** Form submits with full page reload.

**Causes:**
1. Stimulus not loaded
2. Controller name mismatch
3. Target not found

**Solution:**
```javascript
// Check in browser console
Stimulus.debug = true
// Look for connection logs
```

#### Form Submission Returns 404

**Symptom:** AJAX submission fails.

**Causes:**
1. Wrong URL path
2. Missing locale in URL
3. Routes not defined

**Solution:**
```ruby
# Check routes
Rails.application.routes.recognize_path('/api_public/v1/en/contact', method: :post)

# Verify route exists
bundle exec rails routes | grep api_public.*contact
```

#### Success Message Not Showing

**Symptom:** Form submits but no feedback.

**Causes:**
1. `result` target missing
2. Response parsing error
3. Success message value not escaped

**Solution:**
```html
<!-- Ensure target exists -->
<div data-contact-form-target="result"></div>

<!-- Escape message in Liquid -->
data-contact-form-success-message-value="{{ success_msg | escape }}"
```

### Debug Mode

Enable debug logging for page parts:

```ruby
# config/environments/development.rb
config.log_level = :debug

# In template
{% comment %} Debug: show all page_part data {% endcomment %}
<!-- DEBUG: {{ page_part | json }} -->
```

### Useful Commands

```bash
# Test template parsing
bin/rails runner "
  template = File.read('app/views/pwb/page_parts/contact/contact_general_enquiry.liquid')
  Liquid::Template.parse(template)
  puts 'Template OK'
"

# Check field schema
bin/rails runner "
  schema = Pwb::FieldSchemaBuilder.build_for_page_part('contact_general_enquiry')
  puts schema[:fields].map { |f| f[:name] }
"

# Validate page part key format
bin/rails runner "
  key = 'contact_general_enquiry'
  valid = key.match?(/\\A[a-z][a-z0-9]*(_[a-z0-9]+)*\\z/)
  puts valid ? 'Valid key format' : 'Invalid key format'
"

# Test API endpoint
curl -X POST http://localhost:3000/api_public/v1/en/contact \
  -H "Content-Type: application/json" \
  -d '{"contact":{"name":"Test","email":"test@example.com","message":"Hi"}}'
```

---

## Related Documentation

- [PagePart System Documentation](../architecture/08_PagePart_System.md) - Core system architecture
- [Stimulus Controllers](../05_Frontend.md) - Frontend JavaScript patterns
- [Multi-Tenancy](../multi_tenancy/MULTI_TENANCY_ARCHITECTURE.md) - Tenant isolation
- [Seeding Guide](../seeding/SEEDING_COMPREHENSIVE_GUIDE.md) - Seed data management
