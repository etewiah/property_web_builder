# Market Reports & Comparative Market Analysis (CMA)

## Overview

Generate professional market reports and Comparative Market Analyses (CMAs) that help agents win listings and demonstrate market expertise. Reports combine local market data, property comparisons, and AI-generated insights into polished PDF documents.

## Value Proposition

- **Win More Listings**: Show up to presentations with professional, data-driven CMAs
- **Establish Expertise**: Position agents as local market experts with market reports
- **Lead Generation**: Use reports as lead magnets with built-in contact capture
- **Time Savings**: Generate comprehensive reports in minutes, not hours
- **Brand Consistency**: Customizable templates with agent/brokerage branding

## Current Implementation Status

### Completed Features

- [x] Database schema and model (`Pwb::MarketReport`)
- [x] CMA generation service (`Reports::CmaGenerator`)
- [x] Comparable properties finder (`Reports::ComparablesFinder`)
- [x] Market statistics calculator (`Reports::StatisticsCalculator`)
- [x] AI insights generation (`Reports::CmaInsightsGenerator`)
- [x] PDF generation (`Reports::PdfGenerator`)
- [x] API endpoints for CMA management
- [x] Public sharing with share tokens
- [x] View count tracking
- [x] Site Admin UI for CMA management

### Future Enhancements

- [ ] Market Report type (neighborhood trends)
- [ ] Buyer Tour Report type
- [ ] Seller Net Sheet type
- [ ] Custom PDF template builder
- [ ] MLS data integration
- [ ] Scheduled report generation

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Site Admin UI                             │
│  (CMA Reports Index, Show, New, Actions)                        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    CmaReportsController                          │
│  - index, show, new, create, destroy                            │
│  - regenerate, share, download                                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                  Reports::CmaGenerator                           │
│  (Orchestrator service)                                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌───────────────────┐  ┌────────────────┐ │
│  │ ComparablesFinder│  │StatisticsCalculator│  │CmaInsightsGen │ │
│  │                 │  │                   │  │(AI Service)   │ │
│  └────────┬────────┘  └─────────┬─────────┘  └───────┬────────┘ │
│           │                     │                    │          │
│           ▼                     ▼                    ▼          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Pwb::MarketReport                        ││
│  │  - subject_details, comparable_properties                   ││
│  │  - market_statistics, ai_insights                           ││
│  │  - suggested_price_low/high, branding                       ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                 Reports::PdfGenerator                            │
│  (Prawn-based PDF generation)                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User initiates CMA**: Selects property in Site Admin or API
2. **Report created**: `Pwb::MarketReport` record with `draft` status
3. **Find comparables**: `ComparablesFinder` locates similar properties
4. **Calculate statistics**: `StatisticsCalculator` computes market metrics
5. **Generate insights**: `CmaInsightsGenerator` calls AI for analysis
6. **Update report**: Report marked `completed` with all data
7. **Generate PDF**: Background job creates PDF attachment
8. **Share (optional)**: Generate share token for public URL

---

## Data Model

### Pwb::MarketReport Schema

```ruby
# Table: pwb_market_reports
#
# id                         :bigint           not null, primary key
# ai_insights                :jsonb            # AI-generated analysis
# branding                   :jsonb            # Agent/company branding
# city                       :string
# comparable_properties      :jsonb            # Array of comparable data
# generated_at               :datetime
# latitude                   :decimal(10, 7)
# longitude                  :decimal(10, 7)
# market_statistics          :jsonb            # Aggregated market stats
# postal_code                :string
# radius_km                  :decimal(5, 2)
# reference_number           :string           # CMA-YYYYMMDD-XXXXXX
# region                     :string
# report_type                :string           # 'cma' or 'market_report'
# share_token                :string           # Unique URL-safe token
# shared_at                  :datetime
# status                     :string           # draft, generating, completed, shared
# subject_details            :jsonb            # Subject property snapshot
# suggested_price_currency   :string           # USD, EUR, etc.
# suggested_price_high_cents :integer
# suggested_price_low_cents  :integer
# title                      :string
# view_count                 :integer          # Public page views
# website_id                 :bigint           # Multi-tenant scope
# user_id                    :bigint           # Creator
# subject_property_id        :uuid             # FK to realty_assets
# ai_generation_request_id   :bigint           # FK to AI request log
```

### JSONB Column Structures

#### subject_details
```json
{
  "property_id": "uuid",
  "reference": "REF-123",
  "address": {
    "street": "123 Main St",
    "city": "San Francisco",
    "region": "CA",
    "postal_code": "94102"
  },
  "characteristics": {
    "property_type": "single_family",
    "bedrooms": 3,
    "bathrooms": 2,
    "constructed_area": 1800,
    "year_built": 1985
  }
}
```

#### comparable_properties
```json
[
  {
    "id": "uuid",
    "reference": "REF-456",
    "address": "456 Oak Ave",
    "property_type": "single_family",
    "bedrooms": 3,
    "bathrooms": 2,
    "constructed_area": 1750,
    "price_cents": 55000000,
    "adjusted_price_cents": 56500000,
    "adjustments": [
      { "factor": "Bedrooms", "diff": 0, "amount": 0 },
      { "factor": "Size", "diff": 50, "amount": 1500000 }
    ],
    "similarity_score": 85,
    "distance_km": 0.8,
    "status": "sold",
    "sold_at": "2025-11-15"
  }
]
```

#### market_statistics
```json
{
  "average_price_cents": 52500000,
  "median_price_cents": 51000000,
  "price_per_sqft_cents": 45000,
  "days_on_market": 28,
  "comparable_count": 8,
  "average_similarity_score": 78
}
```

#### ai_insights
```json
{
  "executive_summary": "Based on 8 comparable properties...",
  "market_position": "The subject property is positioned in the upper...",
  "pricing_rationale": "The suggested price range reflects...",
  "strengths": ["Updated kitchen", "Corner lot", "Good schools"],
  "considerations": ["Older roof", "Single-car garage"],
  "recommendation": "List at $515,000 to $535,000",
  "time_to_sell_estimate": "30-45 days",
  "confidence_level": "high"
}
```

### Associations

```ruby
class Pwb::MarketReport < ApplicationRecord
  belongs_to :website
  belongs_to :user, optional: true
  belongs_to :subject_property, class_name: 'Pwb::RealtyAsset', optional: true
  belongs_to :ai_generation_request, optional: true

  has_one_attached :pdf_file
end
```

---

## Service Layer

### Reports::CmaGenerator

The main orchestrator service that coordinates the entire CMA generation workflow.

**File**: `app/services/reports/cma_generator.rb`

```ruby
# Usage:
generator = Reports::CmaGenerator.new(
  property: realty_asset,
  website: website,
  user: current_user,
  options: {
    radius_km: 2,
    months_back: 6,
    max_comparables: 10,
    generate_pdf: true,
    title: 'Custom Title',
    branding: { agent_name: 'John Doe' }
  }
)

result = generator.generate

if result.success?
  report = result.report
  comparables = result.comparables
  statistics = result.statistics
  insights = result.insights
else
  error = result.error
end
```

**Default Options**:
- `radius_km`: 2 km search radius
- `months_back`: 6 months of data
- `max_comparables`: 10 properties
- `generate_pdf`: true

### Reports::ComparablesFinder

Finds and scores comparable properties based on similarity to the subject.

**File**: `app/services/reports/comparables_finder.rb`

**Matching Criteria**:
- Geographic proximity (Haversine distance)
- Property type match
- Bedroom count (±1)
- Size range (±30% of subject)
- Recent sales (within months_back)

**Similarity Scoring** (0-100 points):
- Property type match: 20 points
- Bedroom difference: 15 points (−3 per difference)
- Bathroom difference: 10 points (−5 per difference)
- Size similarity: 20 points (proportional)
- Distance: 20 points (−5 per km)
- Year built: 10 points (−1 per 5 years)
- Features match: 5 points

**Price Adjustments** (per unit difference):
- Bedroom: $15,000
- Bathroom: $10,000
- Size (sqft): $150
- Year built: $1,000
- Garage: $8,000

### Reports::StatisticsCalculator

Computes market statistics from comparable properties.

**File**: `app/services/reports/statistics_calculator.rb`

**Calculated Metrics**:
- Average price
- Median price
- Price per square foot
- Average days on market
- Comparable count
- Average similarity score

### Reports::CmaInsightsGenerator

Generates AI-powered analysis using configured AI provider.

**File**: `app/services/reports/cma_insights_generator.rb`

**Generated Content**:
- Executive summary
- Market position analysis
- Pricing rationale
- Property strengths (list)
- Considerations (list)
- Recommendation
- Time to sell estimate
- Confidence level
- Suggested price range

Uses `Ai::BaseService` for provider abstraction (Anthropic, OpenAI, etc.).

### Reports::PdfGenerator

Creates professional PDF reports using Prawn.

**File**: `app/services/reports/pdf_generator.rb`

**PDF Sections**:
1. Cover page with branding
2. Executive summary with pricing box
3. Subject property details
4. Comparable properties table
5. Market analysis
6. Pricing recommendation
7. Disclaimer footer

---

## API Endpoints

### List CMAs
```http
GET /api_manage/v1/:locale/reports/cmas
```

**Response**:
```json
{
  "success": true,
  "reports": [
    {
      "id": 123,
      "reference_number": "CMA-20260130-A1B2C3",
      "title": "CMA Report for 123 Main St",
      "status": "completed",
      "created_at": "2026-01-30T10:00:00Z",
      "pdf_ready": true
    }
  ]
}
```

### Create CMA
```http
POST /api_manage/v1/:locale/reports/cmas
Content-Type: application/json

{
  "property_id": "uuid",
  "radius_km": 2,
  "months_back": 6,
  "max_comparables": 10,
  "title": "Custom Title",
  "generate_pdf": true,
  "branding": {
    "agent_name": "John Doe",
    "agent_phone": "555-0123"
  }
}
```

**Response** (201 Created):
```json
{
  "success": true,
  "report": {
    "id": 124,
    "reference_number": "CMA-20260130-X7Y8Z9",
    "title": "Custom Title",
    "status": "completed",
    "suggested_price": {
      "low": 33000000,
      "high": 37000000,
      "currency": "USD",
      "formatted_low": "$330,000",
      "formatted_high": "$370,000"
    },
    "comparables": [...],
    "statistics": {...},
    "insights": {...}
  },
  "comparable_count": 8
}
```

### Show CMA
```http
GET /api_manage/v1/:locale/reports/cmas/:id
```

### Delete CMA
```http
DELETE /api_manage/v1/:locale/reports/cmas/:id
```

### Download PDF
```http
GET /api_manage/v1/:locale/reports/cmas/:id/pdf
```

Redirects to PDF blob URL.

### Share CMA
```http
POST /api_manage/v1/:locale/reports/cmas/:id/share
```

**Response**:
```json
{
  "success": true,
  "share_token": "abc123xyz",
  "share_url": "https://example.com/reports/shared/abc123xyz",
  "shared_at": "2026-01-30T12:00:00Z"
}
```

### Public CMA View
```http
GET /reports/shared/:share_token
```

No authentication required. Increments view count.

---

## Site Admin Integration

### Navigation

CMA Reports is accessible under the **Listings** section in Site Admin navigation:
- Path: `/site_admin/cma_reports`
- Icon: Chart/analytics icon
- Shows report count badge

### Available Pages

#### Index Page (`/site_admin/cma_reports`)
- List of all CMA reports with filtering
- Columns: Reference, Property, Status, Created, Price Range, Actions
- Quick actions: View, Download PDF, Share, Delete
- "Generate Report" button to create new

#### Show Page (`/site_admin/cma_reports/:id`)
- Report header with title and reference number
- Subject property card with photo and details
- Suggested price range (prominent display)
- Comparable properties table with adjustments
- Market statistics grid
- AI insights sections
- Actions: Download PDF, Share, Regenerate, Delete

#### New Page (`/site_admin/cma_reports/new`)
- Property selector (dropdown of website properties)
- Analysis options:
  - Search radius (1-10 km)
  - Time period (3, 6, 12 months)
  - Max comparables (5, 10, 15)
- Custom title (optional)
- Branding options (uses defaults if not set)
- Generate button with loading state

### Controller Actions

```ruby
class SiteAdmin::CmaReportsController < SiteAdminController
  def index      # List all reports with search/filter
  def show       # View report details
  def new        # Form to create new CMA
  def create     # Generate CMA for property
  def destroy    # Delete report
  def regenerate # Re-run AI generation
  def share      # Generate share link
  def download   # Download PDF
end
```

---

## Public Sharing

### Share URL Format
```
https://{subdomain}.example.com/reports/shared/{share_token}
```

### Features
- No authentication required
- View count tracking (increments on each visit)
- Professional display of report data
- Download PDF option (if generated)
- Company branding display

### Access Control
- Reports must be `completed` or `shared` status to share
- Share token is unique, URL-safe base64 (16 bytes)
- Token generated on first share, reused for subsequent shares

---

## Configuration

### AI Provider Setup

CMA insights require a configured AI integration:

1. Go to **Settings > Integrations** in Site Admin
2. Add an AI provider (Anthropic Claude, OpenAI, etc.)
3. Enter API credentials
4. Enable the integration

The system uses `Ai::BaseService` which auto-selects the configured provider.

### Branding Settings

Default branding is pulled from:
- **Agency Profile**: Company name, logo
- **User Profile**: Agent name, email, phone
- **Website Settings**: Logo URL, company name

Can be overridden per-report in the create request.

---

## Error Handling

### AI Not Configured
```json
{
  "success": false,
  "error": "AI is not configured: No AI provider enabled"
}
```
HTTP Status: 503 Service Unavailable

### Rate Limited
```json
{
  "success": false,
  "error": "Rate limit exceeded. Please try again later.",
  "retry_after": 60
}
```
HTTP Status: 429 Too Many Requests

### No Comparables Found
```json
{
  "success": true,
  "report": {...},
  "comparable_count": 0,
  "message": "No comparable properties found within search criteria"
}
```
Report is still created but without comparables or AI insights.

---

## Testing

### Running Tests

```bash
# API tests
rspec spec/requests/api_manage/v1/reports/cmas_spec.rb

# Site Admin tests
rspec spec/requests/site_admin/cma_reports_spec.rb

# Service tests
rspec spec/services/reports/

# Model tests
rspec spec/models/pwb/market_report_spec.rb
```

### Factory

```ruby
# spec/factories/pwb_market_reports.rb
FactoryBot.define do
  factory :pwb_market_report, class: 'Pwb::MarketReport' do
    website
    title { "CMA Report for Test Property" }
    report_type { 'cma' }
    status { 'draft' }

    trait :completed do
      status { 'completed' }
      generated_at { Time.current }
      market_statistics { { average_price_cents: 50000000 } }
      ai_insights { { executive_summary: 'Test summary' } }
    end

    trait :shared do
      status { 'shared' }
      shared_at { Time.current }
      share_token { SecureRandom.urlsafe_base64(16) }
    end

    trait :with_pdf do
      after(:create) do |report|
        report.pdf_file.attach(
          io: StringIO.new('%PDF-1.4 test'),
          filename: 'test.pdf',
          content_type: 'application/pdf'
        )
      end
    end
  end
end
```
