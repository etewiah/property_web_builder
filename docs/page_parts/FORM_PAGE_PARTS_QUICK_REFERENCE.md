# Form Page Parts - Quick Reference

## Naming Convention

**Pattern:** `{category}_{purpose}_{variant}`

**Rules:**
- Lowercase letters, numbers, underscores only
- No slashes (URL-safe)
- Category prefix first (e.g., `contact_`, `newsletter_`)
- Descriptive purpose (e.g., `general_enquiry`, `location_map`)

**Examples:**
| Good | Bad | Why |
|------|-----|-----|
| `contact_general_enquiry` | `contact_form` | Too generic |
| `contact_location_map` | `forms/contact_with_map` | Slash breaks URLs |
| `newsletter_signup_footer` | `newsletter` | Missing context |

---

## Available Form Page Parts

| Key | Description | Use Case |
|-----|-------------|----------|
| `contact_general_enquiry` | Standalone contact form | Any page needing a contact form |
| `contact_location_map` | Contact form + Leaflet map | Contact pages with location display |
| `contact_property_enquiry` | Property-specific enquiry | Property detail pages |
| `contact_valuation_request` | Request valuation | Seller landing pages |
| `form_and_map` | Legacy form (backward compat) | Existing sites using old system |

---

## contact_general_enquiry

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `section_title` | text | "Contact Us" | Section heading |
| `section_subtitle` | textarea | - | Description text |
| `show_phone_field` | boolean | true | Show phone input |
| `show_subject_field` | boolean | true | Show subject input |
| `submit_button_text` | text | "Send Message" | Button label |
| `success_message` | textarea | "Thank you!..." | Success message |
| `form_style` | select | "default" | Visual style |

### Form Styles

- `default` - Card with border
- `minimal` - No border
- `shadowed` - Elevated shadow

### Template Location

```
app/views/pwb/page_parts/contact/contact_general_enquiry.liquid
# or
app/views/pwb/page_parts/contact_general_enquiry.liquid
```

---

## contact_location_map

### Fields (Header)

| Field | Type | Description |
|-------|------|-------------|
| `section_title` | text | Section heading |
| `section_subtitle` | textarea | Description |

### Fields (Contact Info)

| Field | Type | Description |
|-------|------|-------------|
| `address` | textarea | Physical address |
| `phone` | phone | Contact phone |
| `email` | email | Contact email |
| `hours` | textarea | Business hours |

### Fields (Map)

| Field | Type | Description |
|-------|------|-------------|
| `map_latitude` | number | Latitude (e.g., 40.7128) |
| `map_longitude` | number | Longitude (e.g., -74.0060) |
| `map_zoom` | number | Zoom level 1-18 (default: 14) |

### Fields (Form Config)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `show_phone_field` | boolean | true | Show phone in form |
| `show_subject_field` | boolean | false | Show subject in form |
| `submit_button_text` | text | "Send Message" | Button text |
| `success_message` | textarea | "Thank you!..." | Success message |

### Fields (Layout)

| Value | Description |
|-------|-------------|
| `form_left` | Form on left, map on right |
| `form_right` | Form on right, map on left |
| `form_top` | Form above, map below |

### Template Location

```
app/views/pwb/page_parts/contact/contact_location_map.liquid
# or
app/views/pwb/page_parts/contact_location_map.liquid
```

---

## Liquid Template Access

```liquid
{% comment %} Get field value with default {% endcomment %}
{{ page_part.field_name.content | default: 'fallback' }}

{% comment %} Boolean check {% endcomment %}
{% assign show_phone = page_part.show_phone_field.content | default: 'true' %}
{% if show_phone == 'true' or show_phone == true %}
  ...
{% endif %}

{% comment %} Check if field has content {% endcomment %}
{% if page_part.section_title.content != blank %}
  <h2>{{ page_part.section_title.content }}</h2>
{% endif %}
```

---

## Stimulus Controller Setup

### Contact Form Controller

```html
<div data-controller="contact-form"
     data-contact-form-submit-url-value="/api_public/v1/{{ current_locale }}/contact"
     data-contact-form-success-message-value="{{ success_msg | escape }}">

  <form data-contact-form-target="form"
        data-action="submit->contact-form#submit">

    <input type="hidden" name="contact[locale]" value="{{ current_locale }}">
    <input type="text" name="contact[name]" required>
    <input type="email" name="contact[email]" required>
    <input type="tel" name="contact[phone]">
    <input type="text" name="contact[subject]">
    <textarea name="contact[message]" required></textarea>

    <div data-contact-form-target="result"></div>
    <button type="submit" data-contact-form-target="submitButton">Send</button>
  </form>
</div>
```

### Map Controller

```html
<div data-controller="map"
     data-map-markers-value='[{"id":"office","title":"Office","position":{"lat":40.7,"lng":-74.0}}]'
     data-map-zoom-value="14"
     data-map-scroll-wheel-zoom-value="false"
     data-map-target="canvas"
     style="height: 400px;">
</div>
```

---

## API Endpoint

### POST /api_public/v1/:locale/contact

**Request:**
```json
{
  "contact": {
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "555-1234",
    "subject": "Inquiry",
    "message": "Hello!"
  }
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Thank you...",
  "data": { "contact_id": 1, "message_id": 1 }
}
```

**Error Response (422):**
```json
{
  "success": false,
  "errors": ["Email is required."]
}
```

---

## Seed Example

```yaml
# db/yml_seeds/page_parts/home__contact_general_enquiry.yml
- page_slug: home
  page_part_key: contact_general_enquiry
  block_contents:
    en:
      blocks:
        section_title:
          content: "Contact Us"
        show_phone_field:
          content: "true"
        submit_button_text:
          content: "Send Message"
  order_in_editor: 5
  show_in_editor: true
```

---

## Testing Commands

```bash
# Verify definition exists
bin/rails runner "puts Pwb::PagePartLibrary.definition('contact_general_enquiry').present?"

# Check template parsing
bin/rails runner "
  t = File.read('app/views/pwb/page_parts/contact/contact_general_enquiry.liquid')
  Liquid::Template.parse(t)
  puts 'OK'
"

# Validate key format
bin/rails runner "
  key = 'contact_general_enquiry'
  valid = key.match?(/\\A[a-z][a-z0-9]*(_[a-z0-9]+)*\\z/)
  puts valid ? 'Valid' : 'Invalid'
"

# Test API
curl -X POST http://localhost:3000/api_public/v1/en/contact \
  -H "Content-Type: application/json" \
  -d '{"contact":{"email":"test@example.com","message":"Hi"}}'
```

---

## Common Patterns

### Adding a Form to Any Page

1. Ensure page part definition exists in `PagePartLibrary`
2. Create seed YAML or use admin UI
3. Page part renders automatically via `ordered_visible_page_contents`

### Customizing Success Message per Locale

```yaml
block_contents:
  en:
    blocks:
      success_message:
        content: "Thank you! We'll be in touch."
  es:
    blocks:
      success_message:
        content: "Gracias! Nos pondremos en contacto."
```

### Hiding Form Fields

Set boolean fields to `"false"` in block_contents:

```yaml
show_phone_field:
  content: "false"
show_subject_field:
  content: "false"
```

---

## Naming Quick Reference

| Purpose | Recommended Key |
|---------|-----------------|
| General contact | `contact_general_enquiry` |
| With map | `contact_location_map` |
| Property inquiry | `contact_property_enquiry` |
| Valuation request | `contact_valuation_request` |
| Callback request | `contact_callback_request` |
| Newsletter | `newsletter_signup_inline` |
| Agent contact | `contact_agent_direct` |

**Key format regex:** `/\A[a-z][a-z0-9]*(_[a-z0-9]+)*\z/`
