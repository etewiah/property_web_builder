# Rails Parts Implementation Guide for JS Clients

This document provides **complete implementation details** for the Rails parts (`is_rails_part: true`) that render as ERB partials on the server. JS clients must implement equivalent components using the API endpoints.

---

## Overview: What are Rails Parts?

When fetching a page via `/api_public/v1/pages/by_slug/:slug`, the response includes `page_contents` array. Each item has a `page_part_key` which identifies the content section.

**Two types of page parts exist:**

1. **Liquid Parts** (`is_rails_part: false`): Pre-rendered HTML stored in the `content.raw` field. Display as-is.
2. **Rails Parts** (`is_rails_part: true`): Dynamic components rendered server-side via ERB. **JS clients must implement these themselves.**

### Identifying Rails Parts in API Response

```json
{
  "page_contents": [
    {
      "page_part_key": "heroes/hero_centered",
      "is_rails_part": false,
      "content": { "raw_en": "<section class='hero'>...</section>" }
    },
    {
      "page_part_key": "form_and_map",
      "is_rails_part": true,
      "content": null  // Must implement component yourself
    }
  ]
}
```

---

## Rails Part: `form_and_map`

**Purpose**: Displays a contact form with agency contact information and an optional map.

### Source Files
- Main: `/app/themes/default/views/pwb/components/_form_and_map.html.erb`
- Contact Form: `/app/themes/default/views/pwb/sections/_contact_us_form.html.erb`
- Contact Info: `/app/themes/default/views/pwb/props/_prop_contact_info.html.erb`

### What It Renders

```
┌─────────────────────────────────────────────────┐
│ [Contact Form]              │ [Contact Info]    │
│                             │ Company Name      │
│ Name: ________________      │ Address           │
│ Email: _____ Tel: _____     │ Phone: xxx-xxxx   │
│ Subject: ______________     │ Email: xxx@xxx    │
│ Message: ______________     │                   │
│                             │ [Map]             │
│ [Send Button]               │                   │
└─────────────────────────────────────────────────┘
```

### API Endpoints Required

| Data | Endpoint | Field |
|------|----------|-------|
| Agency info | `GET /api_public/v1/site_details` | `contact_info`, `agency` |
| Submit form | `POST /api_public/v1/enquiries` | Request body |
| Map markers | `GET /api_public/v1/site_details` | `agency.latitude`, `agency.longitude` |

### Data Structure from `/site_details`

```json
{
  "company_display_name": "ABC Realty",
  "contact_info": {
    "phone": "+34 123 456 789",
    "phone_mobile": "+34 987 654 321",
    "email": "info@abcrealty.com",
    "address": "123 Main Street, Barcelona, 08001"
  },
  "agency": {
    "display_name": "ABC Realty",
    "company_name": "ABC Realty SL",
    "phone_number_primary": "+34 123 456 789",
    "phone_number_mobile": "+34 987 654 321",
    "email_primary": "info@abcrealty.com",
    "email_for_contact_form": "sales@abcrealty.com",
    "street_number": "123",
    "street_address": "Main Street",
    "city": "Barcelona",
    "postal_code": "08001",
    "latitude": 41.3851,
    "longitude": 2.1734
  }
}
```

### Form Implementation

#### Form Fields (Required)

| Field | Name | Type | Required | Notes |
|-------|------|------|----------|-------|
| Name | `enquiry[name]` | text | Yes | Full name |
| Email | `enquiry[email]` | email | Yes | Contact email |
| Phone | `enquiry[phone]` | tel | No | Phone number |
| Subject | `enquiry[subject]` | text | No | Enquiry subject |
| Message | `enquiry[message]` | textarea | No | Message body |

#### Form Submission

```javascript
// POST /api_public/v1/enquiries
const response = await fetch('/api_public/v1/enquiries', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    enquiry: {
      name: formData.name,
      email: formData.email,
      phone: formData.phone,
      message: formData.message,
      // Optional: property_id if enquiring about a property
    }
  })
});

// Response
// Success: { success: true, message: "Enquiry sent", data: { contact_id: 1, message_id: 1 } }
// Error: { success: false, errors: ["Email is required"] }
```

### Map Implementation

Use **Leaflet** (open-source) for the map:

```javascript
// Initialize Leaflet map
import L from 'leaflet';

const map = L.map('contact-map').setView([agency.latitude, agency.longitude], 15);

L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '© OpenStreetMap contributors'
}).addTo(map);

L.marker([agency.latitude, agency.longitude])
  .addTo(map)
  .bindPopup(`<b>${agency.display_name}</b><br>${agency.street_address}, ${agency.city}`)
  .openPopup();
```

### Complete React Component Example

```jsx
// components/FormAndMap.jsx
import { useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';

export function FormAndMap({ siteDetails }) {
  const { contact_info, agency, company_display_name } = siteDetails;
  const [formData, setFormData] = useState({
    name: '', email: '', phone: '', subject: '', message: ''
  });
  const [status, setStatus] = useState({ loading: false, error: null, success: false });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setStatus({ loading: true, error: null, success: false });
    
    try {
      const res = await fetch('/api_public/v1/enquiries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enquiry: formData })
      });
      const data = await res.json();
      
      if (data.success) {
        setStatus({ loading: false, error: null, success: true });
        setFormData({ name: '', email: '', phone: '', subject: '', message: '' });
      } else {
        setStatus({ loading: false, error: data.errors?.join(', '), success: false });
      }
    } catch (err) {
      setStatus({ loading: false, error: 'Failed to send message', success: false });
    }
  };

  const showMap = agency?.latitude && agency?.longitude;

  return (
    <section className="py-8">
      <div className="container mx-auto px-4">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Contact Form */}
          <div className="bg-white rounded-lg shadow-sm border p-6">
            <p className="text-gray-600 mb-6">
              Fill in the form below and we'll get back to you as soon as possible.
            </p>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name *</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full border rounded-md px-3 py-2"
                />
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
                  <input
                    type="email"
                    required
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    className="w-full border rounded-md px-3 py-2"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                  <input
                    type="tel"
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    className="w-full border rounded-md px-3 py-2"
                  />
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Subject</label>
                <input
                  type="text"
                  value={formData.subject}
                  onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                  className="w-full border rounded-md px-3 py-2"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Message</label>
                <textarea
                  rows={4}
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                  className="w-full border rounded-md px-3 py-2"
                />
              </div>
              
              {status.error && (
                <div className="text-red-600 text-sm">{status.error}</div>
              )}
              {status.success && (
                <div className="text-green-600 text-sm">Message sent successfully!</div>
              )}
              
              <button
                type="submit"
                disabled={status.loading}
                className="bg-blue-600 text-white font-medium py-2 px-6 rounded-lg hover:bg-blue-700"
              >
                {status.loading ? 'Sending...' : 'Send Message'}
              </button>
            </form>
          </div>
          
          {/* Contact Info + Map */}
          <div className="space-y-6">
            {/* Contact Information Card */}
            <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
              <div className="bg-gray-800 px-4 py-3">
                <h2 className="text-lg font-semibold text-white">Contact Information</h2>
              </div>
              <div className="p-4">
                <h4 className="font-semibold text-gray-800 mb-2">{company_display_name}</h4>
                
                {contact_info.address && (
                  <p className="text-gray-600 mb-4">{contact_info.address}</p>
                )}
                
                <div className="space-y-2">
                  {contact_info.phone && (
                    <div className="flex items-center text-gray-700">
                      <PhoneIcon className="w-5 text-blue-600" />
                      <a href={`tel:${contact_info.phone}`} className="ml-2 hover:text-blue-600">
                        {contact_info.phone}
                      </a>
                    </div>
                  )}
                  {contact_info.email && (
                    <div className="flex items-center text-gray-700">
                      <EmailIcon className="w-5 text-blue-600" />
                      <a href={`mailto:${contact_info.email}`} className="ml-2 hover:text-blue-600">
                        {contact_info.email}
                      </a>
                    </div>
                  )}
                </div>
              </div>
            </div>
            
            {/* Map */}
            {showMap && (
              <div className="rounded-lg overflow-hidden shadow-sm border" style={{ height: 400 }}>
                <MapContainer
                  center={[agency.latitude, agency.longitude]}
                  zoom={15}
                  style={{ height: '100%', width: '100%' }}
                >
                  <TileLayer
                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                    attribution='&copy; OpenStreetMap contributors'
                  />
                  <Marker position={[agency.latitude, agency.longitude]}>
                    <Popup>
                      <b>{company_display_name}</b><br />
                      {contact_info.address}
                    </Popup>
                  </Marker>
                </MapContainer>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
```

---

## Rails Part: `search_cmpt`

**Purpose**: A landing page search widget for finding properties.

### Source Files
- Main: `/app/themes/default/views/pwb/components/_search_cmpt.html.erb`
- Form: `/app/themes/default/views/pwb/search/_search_form_landing.html.erb`

### What It Renders

```
┌─────────────────────────────────────────────────┐
│          Find A Property                        │
├─────────────────────────────────────────────────┤
│ Price From: [____]    Price To: [____]          │
│ Property Type: [____] Bedrooms: [____]          │
│                                                 │
│            [ 🔍 Search ]                        │
└─────────────────────────────────────────────────┘
```

### API Endpoints Required

| Data | Endpoint | Notes |
|------|----------|-------|
| Price options | `GET /api_public/v1/site_details` | `sale_price_options_from/till` |
| Property types | `GET /api_public/v1/select_values?field_names=property-types` | Or use search config |
| Search results | `GET /api_public/v1/properties?sale_or_rental=sale&...` | Navigate to results |

### Form Fields

| Field | Name | Type | Values |
|-------|------|------|--------|
| Price From | `for_sale_price_from` | select | From site_details.sale_price_options_from |
| Price To | `for_sale_price_till` | select | From site_details.sale_price_options_till |
| Property Type | `property_type` | select | ["apartment", "house", "villa", ...] |
| Bedrooms | `bedrooms_from` | select | [1, 2, 3, 4, 5] |

### Implementation Logic

This component should:
1. Fetch configuration options on mount
2. Display dropdowns with options
3. On submit, redirect to `/buy` or `/rent` page with query params

```javascript
// Form submission
const handleSearch = (formData) => {
  const params = new URLSearchParams({
    sale_or_rental: 'sale',
    for_sale_price_from: formData.priceFrom,
    for_sale_price_till: formData.priceTo,
    property_type: formData.propertyType,
    bedrooms_from: formData.bedrooms
  });
  
  // Redirect to search results page
  window.location.href = `/en/buy?${params.toString()}`;
};
```

### Complete React Component Example

```jsx
// components/SearchWidget.jsx
import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';

export function SearchWidget({ locale = 'en' }) {
  const router = useRouter();
  const [config, setConfig] = useState(null);
  const [formData, setFormData] = useState({
    priceFrom: '',
    priceTo: '',
    propertyType: '',
    bedrooms: ''
  });

  useEffect(() => {
    // Fetch configuration
    Promise.all([
      fetch('/api_public/v1/site_details').then(r => r.json()),
      fetch('/api_public/v1/select_values?field_names=property-types').then(r => r.json())
    ]).then(([siteDetails, selectValues]) => {
      setConfig({
        priceOptions: siteDetails.sale_price_options_from || [50000, 100000, 150000, 200000, 300000, 500000],
        propertyTypes: selectValues['property-types'] || []
      });
    });
  }, []);

  const handleSubmit = (e) => {
    e.preventDefault();
    const params = new URLSearchParams();
    
    if (formData.priceFrom) params.set('price_min', formData.priceFrom);
    if (formData.priceTo) params.set('price_max', formData.priceTo);
    if (formData.propertyType) params.set('type', formData.propertyType);
    if (formData.bedrooms) params.set('bedrooms', formData.bedrooms);
    
    router.push(`/${locale}/buy?${params.toString()}`);
  };

  if (!config) return <div>Loading...</div>;

  return (
    <div className="bg-white rounded-lg shadow-lg">
      <div className="bg-blue-600 px-6 py-4 rounded-t-lg">
        <h2 className="text-xl font-bold text-white">Find A Property</h2>
      </div>
      
      <form onSubmit={handleSubmit} className="p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Price From
            </label>
            <select
              value={formData.priceFrom}
              onChange={(e) => setFormData({ ...formData, priceFrom: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
            >
              <option value="">Any</option>
              {config.priceOptions.map((price) => (
                <option key={price} value={price}>
                  {new Intl.NumberFormat(locale, { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(price)}
                </option>
              ))}
            </select>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Price To
            </label>
            <select
              value={formData.priceTo}
              onChange={(e) => setFormData({ ...formData, priceTo: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
            >
              <option value="">Any</option>
              {config.priceOptions.map((price) => (
                <option key={price} value={price}>
                  {new Intl.NumberFormat(locale, { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(price)}
                </option>
              ))}
            </select>
          </div>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Property Type
            </label>
            <select
              value={formData.propertyType}
              onChange={(e) => setFormData({ ...formData, propertyType: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
            >
              <option value="">Any</option>
              {config.propertyTypes.map((type) => (
                <option key={type.value} value={type.value}>{type.label}</option>
              ))}
            </select>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Bedrooms
            </label>
            <select
              value={formData.bedrooms}
              onChange={(e) => setFormData({ ...formData, bedrooms: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
            >
              <option value="">Any</option>
              {[1, 2, 3, 4, 5].map((num) => (
                <option key={num} value={num}>{num}+</option>
              ))}
            </select>
          </div>
        </div>
        
        <div className="flex justify-center">
          <button
            type="submit"
            className="bg-blue-600 text-white font-medium py-3 px-8 rounded-lg hover:bg-blue-700 flex items-center"
          >
            <SearchIcon className="w-5 h-5 mr-2" />
            Search
          </button>
        </div>
      </form>
    </div>
  );
}
```

---

## Rails Part: `generic_page_part`

**Purpose**: A fallback component for rendering arbitrary HTML content.

### Source File
- `/app/themes/default/views/pwb/components/_generic_page_part.html.erb`

### What It Does

Simply wraps content in a styled prose container:

```erb
<div class="prose prose-lg max-w-none">
  <%== content %>
</div>
```

### Implementation

This is the simplest Rails part. Just render the HTML content:

```jsx
// components/GenericPagePart.jsx
export function GenericPagePart({ content, pagePartKey }) {
  return (
    <div 
      className="prose prose-lg max-w-none"
      data-pwb-page-part={pagePartKey}
      dangerouslySetInnerHTML={{ __html: content }}
    />
  );
}
```

---

## Full Page Content Renderer

Here's how to render all page parts (both Liquid and Rails):

```jsx
// components/PageContentRenderer.jsx
import { FormAndMap } from './FormAndMap';
import { SearchWidget } from './SearchWidget';
import { GenericPagePart } from './GenericPagePart';

const RAILS_PART_COMPONENTS = {
  'form_and_map': FormAndMap,
  'search_cmpt': SearchWidget,
};

export function PageContentRenderer({ pageContents, siteDetails, locale }) {
  return (
    <div className="container mx-auto px-4 py-8">
      {pageContents.map((pageContent, index) => {
        const { page_part_key, is_rails_part, content } = pageContent;
        
        if (is_rails_part) {
          // Render custom component for Rails parts
          const Component = RAILS_PART_COMPONENTS[page_part_key];
          
          if (Component) {
            return (
              <div key={index} className="w-full mb-6">
                <Component siteDetails={siteDetails} locale={locale} />
              </div>
            );
          }
          
          // Fallback for unknown Rails parts
          return (
            <div key={index} className="w-full mb-6 p-4 bg-yellow-100 border border-yellow-400 rounded">
              <p>Unsupported component: {page_part_key}</p>
            </div>
          );
        }
        
        // Render Liquid content (pre-rendered HTML)
        const htmlContent = content?.[`raw_${locale}`] || content?.raw_en || '';
        
        return (
          <div key={index} className="w-full mb-6">
            <div dangerouslySetInnerHTML={{ __html: htmlContent }} />
          </div>
        );
      })}
    </div>
  );
}
```

---

## Translations Required

The Rails parts use these translation keys (fetch via `/api_public/v1/translations?locale=xx`):

```javascript
// Contact form
t("contactUsPrompt")  // e.g., "Fill in the form below..."
t("send")             // e.g., "Send"
t("webContentSections.contactInformation") // e.g., "Contact Information"

// Search widget
t("findAProperty")    // e.g., "Find A Property"
t("search")           // e.g., "Search"
t("simple_form.labels.search.for_sale_price_from")  // e.g., "Price From"
t("simple_form.labels.search.for_sale_price_till")  // e.g., "Price To"
t("simple_form.labels.search.property_type")        // e.g., "Property Type"
t("simple_form.labels.search.num_bedrooms")         // e.g., "Bedrooms"
```

---

## Summary

| Rails Part | API Data Source | Key Component |
|------------|-----------------|---------------|
| `form_and_map` | `/site_details`, `POST /enquiries` | Contact form + map |
| `search_cmpt` | `/site_details`, `/select_values` | Search widget |
| `generic_page_part` | Page content `raw` field | HTML wrapper |

**For any Rails part not listed here**, check if it has a matching component in:
- `/app/themes/default/views/pwb/components/`
- `/app/themes/[theme_name]/views/pwb/components/`

Examine the ERB file to understand what data it needs and implement an equivalent JS component.
