# PropertyWebBuilder Admin Interface - Complete Feature Guide

## Overview

PropertyWebBuilder's site admin interface (`/site_admin`) provides comprehensive website and property management tools for real estate professionals. This guide documents all features available to admin users for managing their real estate website.

---

## Dashboard & Navigation

### Dashboard (`/site_admin`)
The main entry point showing:
- **Key Statistics**: Total properties, pages, content blocks, messages, and contacts
- **Recent Activity**: Latest 5 properties, messages, and contacts
- **Subscription Info**: 
  - Current plan and pricing
  - Trial days remaining
  - Property limits and usage
  - Feature availability
  - Subscription status and billing period

---

## Property Management

### Property Listing & Search (`/site_admin/props`)

**Features:**
- View all properties with pagination (25 per page)
- Search properties by:
  - Reference number
  - Title/Name
  - Street address
  - City
- Quick access to property details

### Create New Property (`/site_admin/props/new`)

**Initial Property Setup:**
- Property reference number
- Property type (apartment, house, villa, etc.)
- Bedrooms and bathrooms count
- Basic address information

### Property Editing

Properties are edited through tabbed interface with the following sections:

#### 1. General Information (`edit_general`)
- Reference number
- Bedrooms, bathrooms, garages, toilets
- Plot area and constructed area
- Year of construction
- Energy rating and performance
- Address details (street, postal code, city, region, country)
- GPS coordinates (latitude/longitude)
- Property type, state, and origin

#### 2. Text & Descriptions (`edit_text`)
- **Sale Listings**: Title, description, SEO title, meta description (per locale)
- **Rental Listings**: Title, description, SEO title, meta description (per locale)
- Multi-language support for all text fields
- Rich text editing capabilities

#### 3. Sale & Rental Pricing (`edit_sale_rental`)
- **Sale Listings**:
  - Sale price with currency
  - Commission amount
  - Visibility toggle
  - Highlight option
  - Archive/unarchive status
  - Reserved status
  - Furnished status
  
- **Rental Listings**:
  - Monthly rental price
  - Seasonal pricing (low/high season)
  - Currency selection
  - Short-term/long-term rental options
  - Visibility and archive controls
  - Furnished status

#### 4. Location (`edit_location`)
- Street number and name
- Full street address
- Postal code
- City and region
- Country
- Latitude and longitude
- Map preview (if integrated)

#### 5. Labels & Features (`edit_labels`)
Organize properties with customizable labels organized by categories:
- **Property Types**: apartment, house, villa, penthouse, etc.
- **Features**: parking, pool, terrace, balcony, garden, etc.
- **Amenities**: air conditioning, heating, dishwasher, etc.
- **Status**: new, renovated, needs-update, etc.
- **Highlights**: luxury, investment-opportunity, etc.

Each property can have multiple labels selected from available field keys.

#### 6. Photos (`edit_photos`)
- **Upload photos**: Batch upload multiple image files
- **External URLs**: Paste external image URLs (if external image mode enabled)
- **Photo Management**:
  - Reorder photos via drag-and-drop
  - Remove individual photos
  - Sort order determines display order on property pages
- **Photo Limits**: Based on subscription plan

### Property Import/Export

#### Import (`/site_admin/property_import_export`)

**CSV Bulk Import:**
- Upload CSV file with property data
- Field mapping to property attributes
- Options:
  - Update existing properties (match by reference)
  - Skip duplicates
  - Set default currency
  - Create visible by default
  - Dry run (preview without saving)

**Template Download:**
- Download CSV template with:
  - Required columns
  - Field format examples
  - All supported property attributes

**Import Results:**
- Success count: Properties imported
- Error count: Failed records with error details
- Skipped count: Duplicate/invalid records
- Detailed error log for troubleshooting

**Supported CSV Fields:**
- reference, street_address, city, region, postal_code, country
- prop_type_key, count_bedrooms, count_bathrooms, constructed_area
- for_sale, for_rent, price_sale, price_rental_monthly, currency
- title_[locale], description_[locale]
- visible, features (comma-separated)

#### Export (`/site_admin/property_import_export?action=export`)

**CSV Export Features:**
- Export all properties or filtered sets
- Options:
  - Include inactive listings
  - Include archived listings
- File naming: `properties_[subdomain]_[date].csv`
- All property data in standardized format

---

## Content Management

### Pages (`/site_admin/pages`)

#### Page Listing & Management
- View all website pages
- Search pages by slug
- Pagination support
- Quick access to page details

#### Page Editing (`/site_admin/pages/:id/edit`)

**Page Parts Management:**
- View all page parts in page
- Drag-and-drop reordering
- Edit individual page parts inline
- Toggle part visibility/visibility states
- Preview page before publishing

**Page Structure:**
- Pages contain multiple "page parts" (content blocks)
- Each page part has:
  - Unique page_part_key (e.g., "hero_section", "faq_section")
  - Configurable content (via page part editor)
  - Visibility toggles
  - Order position within page

#### Page Settings (`/site_admin/pages/:id/settings`)
- Slug (URL path)
- Visibility toggle (show/hide from public)
- Navigation options:
  - Show in top navigation
  - Show in footer
  - Sort order in navigation
- Page title/metadata

#### Page Parts Editing (`/site_admin/pages/:id/page_parts/:page_part_id/edit`)
- Edit individual content blocks
- Page part-specific editors:
  - Text editor for text content
  - Image selector for images
  - HTML/code for custom content
- Drag-drop image selection from media library
- Real-time preview

### Properties Settings (Field Keys Management)

#### Overview (`/site_admin/properties/settings`)
Manage all property-related field keys and custom options across categories:
- Property Types
- Property States
- Property Features
- Amenities
- Property Status
- Highlights
- Listing Origin

#### Category Management (`/site_admin/properties/settings/:category`)

**For Each Category:**
- View all field keys
- Create new field key:
  - Auto-generated global key (e.g., `types.apartment`, `features.pool`)
  - Multi-language labels
  - Visible/hidden toggle
  - Sort order
  
- Edit field key:
  - Update labels for all supported locales
  - Toggle visibility (affects property editor)
  - Reorder within category
  
- Delete field key (removes from all properties)

**Global Key Format:**
- Format: `{prefix}.{snake_case_name}`
- Examples: `types.apartment`, `features.private_pool`, `amenities.air_conditioning`
- Automatically generated, but can be reviewed

**Multi-Language Support:**
- Edit labels for all website-supported locales
- Ensures consistent terminology across languages

---

## Media & Asset Management

### Media Library (`/site_admin/media_library`)

#### File Management
- **Upload Files**: Single or batch upload
- **Supported Types**: Images, documents, videos (all media types)
- **File Information**:
  - Filename and custom title
  - Alt text (for accessibility)
  - Description and captions
  - File size and dimensions (for images)
  - Usage count tracking
  - Tags for organization

#### Folder Organization
- Create folder hierarchy
- Move files between folders
- Rename folders
- Delete empty folders
- Breadcrumb navigation
- Folder-based browsing

#### Search & Filtering
- Full-text search by filename, title, description
- Filter by folder
- Recent files view
- Pagination (24 items per page)

#### Bulk Operations
- **Bulk Delete**: Select multiple files and delete
- **Bulk Move**: Move multiple files to different folder
- Batch processing with result summary

#### Statistics
- Total files count
- Image/document breakdown
- Total folders
- Storage usage tracking
- Orphan monitoring

#### Media Details
- View file metadata
- Edit title, alt text, description
- Change folder assignment
- Tag management
- View usage locations

---

## User Management

### Team Members (`/site_admin/users`)

#### User Listing
- View all website team members
- Search users by email
- Pagination support
- User roles and activation status

#### Add New User (`/site_admin/users/new`)

**Adding Existing User:**
- Search by email
- Add to website with role assignment
- Auto-activate

**Creating New User:**
- Email address
- First and last names
- Role assignment (owner, admin, member)
- Auto-generate temporary password
- Send invitation email with reset link

#### User Management Actions

**Edit User (`/site_admin/users/:id/edit`):**
- Update first/last names
- Update phone number
- Change role (owner, admin, member)

**User Roles:**
- **Owner**: Full access, can manage all users
- **Admin**: Can manage users with lower roles
- **Member**: Limited editing, read-only access to some features

**User Status Management:**
- Deactivate user (removes access)
- Reactivate user
- Remove from team (delete membership)
- Resend invitation email

**Permissions:**
- Only admins can manage users
- Cannot downgrade/remove yourself
- Cannot remove sole owner
- Cannot manage users with equal/higher permissions

---

## Website Settings & Configuration

### General Settings (`/site_admin/website/settings?tab=general`)

**Basic Information:**
- Company display name
- Default client locale (language)
- Default currency (for pricing)
- Default area unit (square meters/feet)

**Analytics:**
- Google Analytics ID
- Analytics ID type (GA4, Universal Analytics)

**Advanced:**
- External image mode (use external URLs instead of uploads)
- Supported locales (multi-language setup)

### Appearance Settings (`/site_admin/website/settings?tab=appearance`)

**Theme Selection:**
- Choose from available themes
- Color palette/variant selection
- Real-time theme preview

**Custom Styling:**
- Custom CSS editor
- Override theme styles
- Live preview updates
- Variables for quick customization:
  - Primary color
  - Secondary color
  - Typography settings
  - Spacing adjustments

### Home Page Settings (`/site_admin/website/settings?tab=home`)

**Page Title:**
- Edit home page title
- Multi-language titles

**Display Options:**
- Hide "For Rent" section
- Hide "For Sale" section
- Hide search bar

**Carousel Management:**
- Manage carousel content blocks
- Featured properties carousel

### Navigation Settings (`/site_admin/website/settings?tab=navigation`)

**Top Navigation Links:**
- Add/edit navigation items
- Set link targets (internal pages or external URLs)
- Configure for each language
- Control visibility
- Sort order management

**Footer Links:**
- Separate footer navigation
- Same customization as top nav
- Organize into columns

**Navigation Editing:**
- Multi-language link titles
- URL/path configuration
- Show/hide toggles per language
- Drag-drop reordering

### SEO Settings (`/site_admin/website/settings?tab=seo`)

**Global SEO:**
- Default page title
- Default meta description
- Favicon URL
- Main logo URL

**Social Media Integration:**
- Facebook URL
- Instagram handle
- LinkedIn profile
- Twitter handle
- Social sharing metadata

### Social Media Settings (`/site_admin/website/settings?tab=social`)

**Social Media Links:**
- Facebook page URL
- Instagram profile
- LinkedIn company
- Twitter/X account
- YouTube channel
- Pinterest profile
- Links appear in website footer/header

### Notification Settings (`/site_admin/website/settings?tab=notifications`)

**Ntfy.sh Integration:** (Push notifications)
- Enable/disable notifications
- Server URL configuration
- Topic prefix setup
- Access token management

**Notification Types:**
- Property inquiries notifications
- New listings notifications
- User activity notifications
- Security alerts

**Testing:**
- Send test notification
- Verify configuration
- Debug notification issues

---

## Agency/Company Profile

### Agency Settings (`/site_admin/agency/edit`)

**Company Information:**
- Display name (shown on website)
- Legal company name
- Primary email
- Mobile phone number
- Additional phone number
- Website URL

**Contact Email Configuration:**
- Email for general contact form submissions
- Email for property inquiry form submissions
- Separate emails for different contact types

---

## Billing & Subscription

### Subscription Management (`/site_admin/billing`)

**Current Plan:**
- Plan name and pricing
- Features included
- Trial status (if applicable)
- Trial days remaining
- Subscription status

**Usage Limits:**
- Current property count vs. limit
- Current user count vs. limit
- Unlimited indicators

**Billing Period:**
- Current period end date
- Subscription start date

---

## Activity & Security

### Activity Logs (`/site_admin/activity_logs`)

**View Security Activity:**
- Authentication logs
- User login/logout events
- Failed login attempts
- Account changes
- Sensitive actions

**Log Details:**
- Event type
- User who performed action
- IP address
- Timestamp
- Event description

**Filtering:**
- Filter by event type (logins, failures, etc.)
- Filter by user
- Filter by date range (1h, 24h, 7d, 30d)

**Statistics:**
- Total events today
- Successful logins today
- Failed login attempts today
- Unique IPs accessing today

**Log Viewing:**
- Paginated list (50 per page)
- Individual log detail view
- Searchable and sortable

---

## Email Template Customization

### Email Templates (`/site_admin/email_templates`)

**Available Templates (Site Admin):**
- General inquiry email template
- Property inquiry email template
- (Additional templates managed in tenant admin)

**Template Customization:**
- Email subject line
- HTML body
- Plain text body
- Multi-language support

**Default Templates:**
- Start with professional default
- See all variables available
- Preview with sample data

**Template Features:**
- Variable support ({{visitor_name}}, {{property_title}}, etc.)
- HTML editor with preview
- Rich text formatting
- Inline CSS support

**Template Variables Available:**
- Visitor information (name, email, phone)
- Message content
- Property details (title, reference, price, URL)
- Inquiry context
- Company information

**Preview & Testing:**
- Live preview with sample data
- Test email rendering
- Mobile responsive preview

---

## Custom Domain Management

### Domain Configuration (`/site_admin/domain`)

**Current Domain:**
- Display current subdomain
- Display platform domains available

**Custom Domain Setup:**
- Enter custom domain
- Auto-generate verification token
- Display DNS verification instructions

**DNS Verification:**
- TXT record verification
- Step-by-step instructions
- Verify button to check DNS
- Status indicator (verified/pending)

**Domain Management:**
- Change domain
- Remove custom domain
- View verification history

---

## Storage Management

### Storage Statistics (`/site_admin/storage_stats`)

**Storage Overview:**
- Total blobs (files)
- Total attachments
- Total storage used (human-readable)

**Orphan Management:**
- Orphaned blobs count (unreferenced files)
- Orphaned blobs total size
- Recent orphans (< 24h)
- Old orphans (> 24h)

**Cleanup Operations:**
- Queue cleanup job
- Remove orphaned files
- Batch cleanup support

---

## Analytics & Reporting

### Analytics Dashboard (`/site_admin/analytics`)

#### Overview (`analytics#show`)
- Total visits chart
- Traffic sources breakdown
- Device type distribution
- Key metrics summary

#### Traffic Analytics (`analytics#traffic`)
- Visits by day chart
- Unique visitors by day
- Traffic source breakdown (direct, organic, referral, social, etc.)
- UTM campaign tracking
- Geographic visitor distribution by country

#### Property Analytics (`analytics#properties`)
- Top performing properties
- Property view trends
- Most searched property features
- Property-specific performance metrics

#### Conversion Analytics (`analytics#conversions`)
- Inquiry funnel visualization
- Conversion rate tracking
- Inquiries by day
- Lead source attribution

#### Real-Time Analytics (`analytics#realtime`)
- Current active visitors count
- Recent page views (live updating)
- Visitor activity stream
- JSON endpoint for integrations

**Period Selection:**
- 7 days
- 14 days
- 30 days (default)
- 60 days
- 90 days

**Feature Availability:**
- Requires active subscription with analytics feature
- Paid plan feature
- Upgrade prompt for free accounts

---

## Onboarding & Setup

### Onboarding Wizard (`/site_admin/onboarding`)

**Purpose:** Guided setup for new users

**Steps:**

1. **Welcome** (Step 1)
   - Introduction
   - Overview of setup process
   - What to expect

2. **Profile Setup** (Step 2)
   - Agency/company details
   - Contact information
   - Primary email and phone

3. **First Property** (Step 3)
   - Add initial property listing
   - Optional (can skip)
   - Quick property creation

4. **Theme Selection** (Step 4)
   - Browse available themes
   - Select theme preference
   - Preview themes

5. **Completion** (Step 5)
   - Setup summary
   - Statistics overview
   - Next steps and tips

**Features:**
- Skip individual steps (property step only)
- Restart onboarding
- Progress tracking
- Auto-completion detection
- Resume from current step

---

## Tour & Learning

### Guided Tour (`/site_admin/tour`)

**Interactive Features:**
- Contextual help on pages
- Feature highlights
- Click-through tutorials
- Mark tour as complete

**Tour Tracking:**
- User can take multiple times
- Completion tracking per feature

---

## Cross-Cutting Features

### Multi-Language Support

**Supported Across:**
- Website settings (general, SEO, social)
- Navigation link titles
- Home page titles
- Property titles and descriptions
- Email templates
- Page part content

**Language Configuration:**
- Select supported locales on website
- Edit content per language
- Language-specific previews
- Fallback language handling

### Search Functionality

**Available Across:**
- Properties: search by reference, title, address, city
- Pages: search by slug
- Users: search by email
- Contacts: search by email/name
- Messages: search by content/email
- Media library: search by filename, title, description

### Pagination

**Standard Pagination:**
- Properties: 25 per page
- Users: 25 per page
- Activity logs: 50 per page
- Media: 24 per page
- Pages, messages, contacts: configurable

### Bulk Operations

**Supported:**
- Media library: bulk delete, bulk move to folder
- Properties: bulk import via CSV

---

## Security Features

### Multi-Tenancy Isolation

**All Features Scoped To:**
- Current website/tenant
- Current user's website memberships
- Automatic query scoping
- Cross-tenant data protection

### Permission Model

**Role-Based:**
- **Owner**: Full access
- **Admin**: Can manage users and most settings
- **Member**: Limited access (read-only for most features)

**Enforcement:**
- Before-action permission checks
- Can't manage users with equal/higher role
- Can't remove sole owner
- Can't modify yourself via certain actions

### Activity Auditing

- All authentication logged
- User actions tracked
- IP address logging
- Timestamp recording
- Event type categorization

---

## Integration Points

### External Services

**Configured Via Settings:**
- Google Analytics integration
- Ntfy.sh for push notifications
- Custom domains with DNS verification

### API Availability

**Admin Features Available Via:**
- Standard REST API endpoints
- JSON responses for bulk operations
- Batch import/export functionality

### Third-Party Media

**Support For:**
- External image URLs (external_image_mode)
- Media file uploads (ActiveStorage)
- Batch media operations

---

## File Format Support

### Acceptable File Types

**CSV Import/Export:**
- .csv (primary)
- .tsv (tab-separated)
- .txt (text)
- Standard MIME types: text/csv, application/csv

**Image Media:**
- JPEG, PNG, WebP, GIF
- SVG (vector)
- Animated GIFs

**Other Media:**
- PDF documents
- Video files (MP4, WebM, etc.)

---

## Browser Compatibility

**Recommended:**
- Chrome/Chromium (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

**Features:**
- Drag-drop file upload
- Drag-drop reordering
- Local storage for UI state
- JavaScript required for full functionality

---

## Performance Considerations

### Pagination & Loading

- Large datasets paginated by default
- Lazy loading for media
- Async import/export jobs
- Batch operations for bulk changes

### Optimization

- Materialized views for property listing (ListedProperty)
- Indexed searches
- Query scoping for multi-tenancy
- Caching of configuration

---

## Common Workflows

### Add New Property

1. Go to Properties → Create New
2. Enter reference, type, bedrooms, bathrooms, address
3. Click Create
4. Edit General Information (more details)
5. Edit Text & Descriptions (titles/descriptions per language)
6. Edit Sale/Rental (pricing and listing options)
7. Edit Location (GPS, detailed address)
8. Edit Labels (features and amenities)
9. Edit Photos (upload or add external URLs)

### Setup Multi-Language Site

1. Go to Website Settings → General
2. Select supported locales
3. For each page:
   - Edit titles in all languages
4. For each property listing:
   - Edit titles and descriptions in all languages
5. Configure navigation:
   - Website Settings → Navigation
   - Edit link titles per language

### Import Properties from CSV

1. Go to Property Import/Export
2. Download template CSV
3. Fill with property data
4. Upload CSV file
5. Configure options (update existing, skip duplicates, etc.)
6. Preview results (dry run)
7. Confirm import

### Configure Custom Domain

1. Go to Domain settings
2. Enter custom domain
3. Copy DNS TXT record
4. Add TXT record to domain registrar
5. Wait for DNS propagation
6. Click Verify
7. Domain is now active

### Setup Email Templates

1. Go to Email Templates
2. Choose template type (general or property inquiry)
3. Click "Create New" or edit existing
4. Edit subject, HTML, and text body
5. Use available variables
6. Preview with sample data
7. Save template
8. Template auto-sends to relevant recipients

---

## Troubleshooting Tips

### Import Issues

**CSV Not Uploading:**
- Verify file is .csv format
- Check file size limits
- Ensure proper permissions

**Import Errors:**
- Review error log for specific issues
- Check CSV for required fields
- Verify data format matches template
- Use dry run to test before final import

### Domain Verification Issues

**DNS Not Verifying:**
- Allow 24-48 hours for DNS propagation
- Double-check TXT record value
- Verify record at DNS registrar
- Check custom domain not already taken

### Storage Issues

**Upload Failing:**
- Check file size limits (per plan)
- Verify file format supported
- Check folder permissions
- Run storage cleanup if quota exceeded

---

## Summary of Key Admin Capabilities

| Feature | Purpose | Access |
|---------|---------|--------|
| Properties | CRUD operations for real estate listings | `/site_admin/props` |
| Import/Export | Bulk property management | `/site_admin/property_import_export` |
| Pages | Website content management | `/site_admin/pages` |
| Media Library | Asset management | `/site_admin/media_library` |
| Users | Team member management | `/site_admin/users` |
| Website Settings | Global site configuration | `/site_admin/website/settings` |
| Agency Profile | Company information | `/site_admin/agency` |
| Billing | Subscription management | `/site_admin/billing` |
| Analytics | Visitor and conversion tracking | `/site_admin/analytics` |
| Activity Logs | Security and audit trail | `/site_admin/activity_logs` |
| Email Templates | Contact form emails | `/site_admin/email_templates` |
| Custom Domains | Domain configuration | `/site_admin/domain` |
| Storage Stats | File management and cleanup | `/site_admin/storage_stats` |
| Properties Settings | Field keys and labels | `/site_admin/properties/settings` |
| Onboarding | New user setup wizard | `/site_admin/onboarding` |

---

## Support & Getting Help

**For Questions About:**
- Specific features → Check feature description above
- Data import → Review import template and error messages
- Account management → Contact site administrator
- Billing issues → Check subscription status in Billing section
- Technical problems → Check Activity Logs for errors

