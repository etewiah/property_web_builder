# PropertyWebBuilder Admin - Quick Reference

## Navigation Map

```
/site_admin/                          Dashboard & Home
├── props/                            Property Management
│   ├── (index)                       List all properties
│   ├── new                           Create property
│   ├── :id/
│   │   ├── edit_general              Edit property details
│   │   ├── edit_text                 Edit titles/descriptions
│   │   ├── edit_sale_rental          Edit pricing
│   │   ├── edit_location             Edit address/GPS
│   │   ├── edit_labels               Edit features
│   │   └── edit_photos               Edit photos
│   └── property_import_export/
│       ├── (index)                   Import/export interface
│       ├── import                    Upload CSV
│       ├── export                    Download CSV
│       ├── download_template         Get CSV template
│       └── clear_results             Clear import results
├── pages/                            Content Management
│   ├── (index)                       List pages
│   ├── :id/
│   │   ├── edit                      Edit page parts
│   │   ├── settings                  Edit page meta
│   │   └── page_parts/:part_id/edit  Edit content block
│   └── page_parts/                   View all page parts
├── properties/                       Property Settings
│   └── settings/
│       ├── (index)                   Field keys overview
│       └── :category                 Manage category
├── website/                          Website Settings
│   └── settings/
│       ├── (show)                    General settings
│       ├── ?tab=appearance           Theme & styling
│       ├── ?tab=navigation           Nav links
│       ├── ?tab=home                 Home page
│       ├── ?tab=notifications        Ntfy config
│       ├── ?tab=seo                  SEO settings
│       └── ?tab=social               Social media
├── agency/                           Company Profile
│   └── edit                          Edit agency details
├── users/                            Team Management
│   ├── (index)                       List team members
│   ├── new                           Add team member
│   └── :id/                          Manage user
├── media_library/                    Asset Management
│   ├── (index)                       Browse media
│   ├── new                           Upload files
│   ├── :id/                          View/edit media
│   ├── folders/                      View folder structure
│   └── create_folder                 Add folder
├── messages/                         Contact Messages
│   ├── (index)                       View all messages
│   └── :id/                          View message details
├── contacts/                         Contacts List
│   ├── (index)                       View all contacts
│   └── :id/                          View contact details
├── email_templates/                  Email Customization
│   ├── (index)                       List templates
│   ├── new                           Create template
│   ├── :id/
│   │   ├── (show)                    View template
│   │   ├── edit                      Edit template
│   │   └── preview                   Preview template
│   └── preview_default               Preview default
├── activity_logs/                    Audit Trail
│   ├── (index)                       View logs
│   └── :id/                          View log details
├── analytics/                        Visitor Analytics
│   ├── (show)                        Overview
│   ├── traffic                       Traffic details
│   ├── properties                    Property stats
│   ├── conversions                   Funnel data
│   └── realtime                      Live visitors
├── billing/                          Subscription
│   └── (show)                        Billing info
├── domain/                           Domain Management
│   ├── (show)                        View domain
│   └── verify                        Verify custom domain
├── storage_stats/                    Storage Management
│   └── (show)                        Storage info
├── onboarding/                       New User Setup
│   ├── (show)                        Current step
│   ├── :step                         Go to step
│   ├── :step/skip                    Skip step
│   ├── complete                      Complete wizard
│   └── restart                       Start over
└── tour/complete                     Mark tour done
```

---

## Quick Actions

### Add Property
```
1. /site_admin/props/new
2. Enter reference + basic info
3. Click "Create"
4. Fill in details through tabs:
   - edit_general (details)
   - edit_text (titles/descriptions)
   - edit_sale_rental (pricing)
   - edit_location (address)
   - edit_labels (features)
   - edit_photos (images)
```

### Bulk Import Properties
```
1. /site_admin/property_import_export
2. Click "Download Template"
3. Fill in CSV with property data
4. Upload file
5. Set options (update existing, etc.)
6. Check dry run results
7. Confirm import
```

### Export Properties
```
1. /site_admin/property_import_export
2. Set options (include inactive, etc.)
3. Click "Export CSV"
4. Opens download
```

### Create Page
```
- Pages are auto-created from theme
- Edit via /site_admin/pages/:id/edit
- Customize page parts
- Set visibility and nav options via settings
```

### Add Team Member
```
1. /site_admin/users/new
2. Enter email
3. Select role
4. Submit
5. System sends invitation
```

### Configure Website
```
1. /site_admin/website/settings
2. Select tab (general, appearance, etc.)
3. Edit settings
4. Save changes
```

### Upload Media
```
1. /site_admin/media_library
2. Click "Upload" or "New"
3. Select files to upload
4. Choose folder (optional)
5. Files auto-organize in library
```

### Create Email Template
```
1. /site_admin/email_templates
2. Click template type
3. Edit subject and body
4. Use {{variables}} for dynamic content
5. Preview and save
```

### Setup Custom Domain
```
1. /site_admin/domain
2. Enter custom domain
3. Copy DNS TXT record
4. Add to domain registrar
5. Click "Verify Domain"
```

---

## Role Permissions

### Owner
- Full access to all features
- Manage users (all roles)
- Access to billing
- Delete website data

### Admin
- Manage properties, pages, media
- Manage users with lower roles
- Access website settings
- View analytics

### Member
- View properties, pages, media
- Limited editing capabilities
- No user management
- Read-only analytics

---

## Common Field Lists

### Property Types (Examples)
- apartment, house, villa, penthouse
- townhouse, cottage, studio
- commercial, office, retail

### Property States (Examples)
- available, sold, rented
- archived, draft, pending

### Features (Examples)
- parking, pool, terrace, balcony
- garden, garage, elevator
- air_conditioning, heating

### Amenities (Examples)
- dishwasher, washing_machine
- internet, tv_cable, furnished

---

## Keyboard Shortcuts & Tips

### General
- `Ctrl/Cmd + S` - Save on most forms
- `Tab` - Navigate between fields
- `Drag & drop` - Reorder items, upload files

### Media Library
- Click photo - Select for bulk operations
- `Ctrl/Cmd + Click` - Multi-select

### Property Editing
- Tab through sections
- Use autocomplete on location fields
- Drag to reorder photos

### Navigation
- Click breadcrumbs for quick navigation
- Sidebar collapses on mobile
- Search filters real-time

---

## CSV Import Template Fields

```
reference           - Unique property ID
street_address      - Full address or street
city                - City name
region              - State/province
postal_code         - ZIP/postal code
country             - Country name
prop_type_key       - Property type (types.apartment)
count_bedrooms      - Number of bedrooms
count_bathrooms     - Number of bathrooms
constructed_area    - Building size in sq meters/ft
for_sale            - "true" or "false"
for_rent            - "true" or "false"
price_sale          - Sale price (numbers only)
price_rental_monthly - Monthly rent (numbers only)
currency            - EUR, USD, GBP, etc.
title_en            - English property title
description_en      - English description
visible             - "true" or "false"
features            - Comma-separated feature keys
```

---

## Supported Locales (Examples)

- English (en)
- Spanish (es)
- French (fr)
- German (de)
- Portuguese (pt)
- Italian (it)
- Dutch (nl)
- Russian (ru)
- Turkish (tr)
- Catalan (ca)
- And more...

---

## Email Template Variables

**Available in inquiries:**
- `{{visitor_name}}` - Inquiry sender name
- `{{visitor_email}}` - Sender email
- `{{visitor_phone}}` - Sender phone
- `{{message}}` - Inquiry message
- `{{property_title}}` - Property name
- `{{property_reference}}` - Property ID
- `{{property_url}}` - Link to property
- `{{property_price}}` - Price
- `{{website_name}}` - Your company name

---

## File Upload Limits

**Per File:**
- Images: typically 20-50 MB
- Documents: typically 50-100 MB
- Videos: varies by plan

**Total Storage:**
- Based on subscription plan
- View in Storage Stats
- Free plan: limited
- Paid plans: higher limits

---

## Search Tips

### Properties
- Search by reference: "PROP-001"
- Search by address: "Main Street"
- Search by city: "Barcelona"
- Search by title: "Beautiful Apartment"

### Media
- Filename search: "sunset.jpg"
- Title search: "Hero Image"
- Description search: "Homepage"

### Users
- Email search: "john@example.com"

---

## Troubleshooting

### Property Won't Save
- Check all required fields filled
- Verify address/city/country valid
- Check for duplicate reference
- View error message for details

### Import Failing
- Verify CSV format correct
- Check required columns present
- Match property type keys exactly
- Review error log details

### Photos Not Uploading
- Check file size under limit
- Verify image format supported
- Check internet connection
- Try different file

### Domain Verification Stuck
- Wait 24-48 hours for DNS propagation
- Check TXT record exactly matches
- Verify at DNS registrar directly
- Check domain not already in use

### Email Not Sending
- Verify recipient email configured
- Check template active
- Test notification in settings
- Review system logs

---

## Performance Tips

### When Managing Large Property Lists
- Use search to narrow results
- Import via CSV instead of manual entry
- Paginate through results (25 per page)
- Use export for backup

### For Media Library
- Organize with folders
- Use meaningful filenames
- Tag files for easy finding
- Archive unused media

### For Reports
- Generate for specific date ranges
- Export data for analysis
- Use analytics period selector
- Cache results locally

---

## Help Resources

**In-App Help:**
- Hover over field labels for tooltips
- Look for `?` icons for explanations
- Tour guides available in onboarding
- Links to templates and examples

**Common Issues:**
- Check Activity Logs for errors
- Review import error logs
- Test notifications before relying
- Verify domain DNS separately

**Contact Support:**
- Check account email
- Review FAQ documentation
- Submit error details with screenshots
- Check subscription limits

---

## Updates & Changes Tracking

All changes logged in Activity Logs with:
- What changed (event type)
- When it changed (timestamp)
- Who changed it (user email)
- From what IP (security tracking)

Access: `/site_admin/activity_logs`

---

## Settings Summary

| Setting | Location | Effects |
|---------|----------|---------|
| Theme | Website → Appearance | Site design |
| Language | Website → General | Default content language |
| Currency | Website → General | Price display format |
| Domain | Domain Settings | Custom domain routing |
| Analytics ID | Website → General | Visitor tracking |
| Email | Agency Profile | Contact form receipient |
| Templates | Email Templates | Inquiry email format |
| Locales | Website → General | Multi-language support |

---

## Common Workflows At A Glance

**Get Started:**
→ Visit `/site_admin/onboarding` (automatic first login)

**Add Properties:**
→ Props → New → Fill tabs → Save

**Configure Site:**
→ Website Settings → Choose tab → Edit → Save

**Manage Team:**
→ Users → New → Email → Select role → Send invite

**Upload Assets:**
→ Media Library → Upload → Organize in folders

**Customize Emails:**
→ Email Templates → Create/Edit → Use variables → Preview

**Check Analytics:**
→ Analytics → Select period → View reports

**Fix Issues:**
→ Activity Logs → Review errors → Check details

