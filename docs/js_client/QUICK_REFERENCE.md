# Backend API Quick Reference

## New Endpoints

### Theme API
```bash
GET /api_public/v1/theme
```

**Example:**
```bash
curl http://localhost:3000/api_public/v1/theme | jq
```

**Response includes:**
- `colors` - Complete color palette (primary, secondary, accent, etc.)
- `fonts` - Heading and body font families
- `border_radius` - Spacing tokens (sm, md, lg, xl)
- `dark_mode` - Dark mode configuration
- `css_variables` - Ready-to-inject CSS string

---

### Testimonials API
```bash
GET /api_public/v1/testimonials
GET /api_public/v1/testimonials?limit=3
GET /api_public/v1/testimonials?featured_only=true
```

**Examples:**
```bash
# Get all testimonials
curl http://localhost:3000/api_public/v1/testimonials | jq

# Get 3 testimonials
curl "http://localhost:3000/api_public/v1/testimonials?limit=3" | jq

# Get only featured
curl "http://localhost:3000/api_public/v1/testimonials?featured_only=true" | jq
```

**Response includes:**
- `id` - Testimonial ID
- `quote` - The testimonial text
- `author_name` - Author's name
- `author_role` - Author's role/title
- `author_photo` - Author photo URL (if set)
- `rating` - Star rating (1-5)
- `position` - Display order

---

## Management

### Seed Testimonials
```bash
rails pwb:testimonials:seed
```

### Add Testimonials via Console
```ruby
website = Pwb::Website.first

website.testimonials.create!(
  author_name: "John Doe",
  author_role: "Property Buyer",
  quote: "Great service!",
  rating: 5,
  position: 1,
  visible: true,
  featured: true
)
```

### Query Testimonials
```ruby
website.testimonials.visible.ordered
website.testimonials.featured
website.testimonials.limit(3)
```

---

## Testing

### Run Tests
```bash
# Theme API tests
bundle exec rspec spec/requests/api_public/v1/theme_spec.rb

# Testimonials API tests
bundle exec rspec spec/requests/api_public/v1/testimonials_spec.rb

# All API tests
bundle exec rspec spec/requests/api_public/v1/
```

### Manual Testing
```bash
# Test theme endpoint
curl http://localhost:3000/api_public/v1/theme | jq '.theme | keys'

# Test testimonials endpoint
curl http://localhost:3000/api_public/v1/testimonials | jq '.testimonials | length'
```

---

## Frontend Integration

### TypeScript Interfaces

```typescript
// src/types/theme.ts
export interface Theme {
  name: string;
  palette_id: string;
  colors: Record<string, string>;
  fonts: {
    heading: string;
    body: string;
  };
  border_radius: {
    sm: string;
    md: string;
    lg: string;
    xl: string;
  };
  dark_mode: {
    enabled: boolean;
    setting: string;
  };
  css_variables: string;
}

// src/types/testimonial.ts
export interface Testimonial {
  id: number;
  quote: string;
  author_name: string;
  author_role?: string;
  author_photo?: string;
  rating?: number;
  position: number;
}
```

### API Functions

```typescript
// src/lib/api/site.ts

export async function getTheme(): Promise<Theme> {
  const response = await fetch(`${getApiUrl()}/api_public/v1/theme`);
  const data = await response.json();
  return data.theme;
}

export async function getTestimonials(
  limit?: number,
  featuredOnly?: boolean
): Promise<Testimonial[]> {
  const params = new URLSearchParams();
  if (limit) params.append('limit', limit.toString());
  if (featuredOnly) params.append('featured_only', 'true');
  
  const url = `${getApiUrl()}/api_public/v1/testimonials?${params}`;
  const response = await fetch(url);
  const data = await response.json();
  return data.testimonials;
}
```

### Usage in Layout

```typescript
// src/app/[locale]/layout.tsx

export default async function RootLayout({ children, params }: Props) {
  const theme = await getTheme();

  return (
    <html lang={locale}>
      <head>
        {/* Inject theme CSS variables */}
        <style dangerouslySetInnerHTML={{
          __html: theme.css_variables
        }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

### Usage in Page

```typescript
// src/app/[locale]/page.tsx

export default async function HomePage() {
  const testimonials = await getTestimonials(3, true); // Get 3 featured

  return (
    <div>
      <TestimonialsSection testimonials={testimonials} />
    </div>
  );
}
```

---

## Database Schema

```sql
CREATE TABLE pwb_testimonials (
  id              BIGINT PRIMARY KEY,
  author_name     VARCHAR NOT NULL,
  author_role     VARCHAR,
  quote           TEXT NOT NULL,
  rating          INTEGER,
  position        INTEGER DEFAULT 0 NOT NULL,
  visible         BOOLEAN DEFAULT TRUE NOT NULL,
  featured        BOOLEAN DEFAULT FALSE NOT NULL,
  website_id      BIGINT NOT NULL,
  author_photo_id BIGINT,
  created_at      TIMESTAMP NOT NULL,
  updated_at      TIMESTAMP NOT NULL
);

CREATE INDEX ON pwb_testimonials(website_id);
CREATE INDEX ON pwb_testimonials(visible);
CREATE INDEX ON pwb_testimonials(position);
```

---

## Troubleshooting

### No testimonials returned
```bash
# Check if testimonials exist
rails runner "puts Pwb::Website.first.testimonials.count"

# Seed some
rails pwb:testimonials:seed
```

### Theme endpoint returns 500 error
```bash
# Check if website has theme configured
rails runner "website = Pwb::Website.first; puts website.theme_name"
```

### Tests failing
```bash
# Make sure database is migrated
rails db:migrate

# Make sure test database is prepared
rails db:test:prepare
```

---

## Files Modified/Created

**Controllers:**
- `app/controllers/api_public/v1/theme_controller.rb`
- `app/controllers/api_public/v1/testimonials_controller.rb`

**Models:**
- `app/models/pwb/testimonial.rb`
- `app/models/pwb/website.rb` (added association)

**Database:**
- `db/migrate/20260110165317_create_pwb_testimonials.rb`

**Routes:**
- `config/routes.rb` (added 2 routes)

**Tests:**
- `spec/requests/api_public/v1/theme_spec.rb`
- `spec/requests/api_public/v1/testimonials_spec.rb`
- `spec/factories/pwb_testimonials.rb`

**Seeds:**
- `db/yml_seeds/testimonials/*.yml`
- `lib/tasks/testimonials.rake`

---

## Support

For detailed implementation information, see:
- `docs/js_client/backend-api-implementation-plan.md` - Full implementation plan
- `docs/js_client/backend-api-implementation-summary.md` - Implementation summary
- `docs/js_client/backend-api-integration.md` - Original requirements analysis
