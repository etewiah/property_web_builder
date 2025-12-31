# PropertyWebBuilder Admin - Real-World Use Cases

## Use Case 1: Setting Up a New Real Estate Agency Website

### Scenario
A real estate agency signs up for PropertyWebBuilder and needs to launch their website with properties and branding.

### Steps

#### 1. Complete Onboarding Wizard
1. Visit `/site_admin/onboarding`
2. **Step 1 - Welcome**: Review what's coming
3. **Step 2 - Profile**: Enter agency details
   - Display name
   - Company email
   - Phone number
4. **Step 3 - Property**: (Optional) Add first sample property
5. **Step 4 - Theme**: Select company theme/colors
6. **Step 5 - Complete**: Review and finish

#### 2. Configure Website Settings
1. Go to `/site_admin/website/settings?tab=general`
2. Set company display name
3. Choose default language and currency
4. Set analytics ID (Google Analytics)

#### 3. Customize Appearance
1. Go to `/site_admin/website/settings?tab=appearance`
2. Select theme that matches brand
3. Choose color palette
4. Add custom CSS if needed
5. Save

#### 4. Setup Agency Profile
1. Go to `/site_admin/agency/edit`
2. Enter complete company details:
   - Company name
   - Emails (general inquiries, property inquiries)
   - Phone numbers
   - Website URL
3. Save

#### 5. Configure Navigation
1. Go to `/site_admin/website/settings?tab=navigation`
2. Edit top navigation links:
   - About Us
   - Properties
   - Contact
3. Configure footer links
4. Set visibility and sort order

#### 6. Setup Property Labels
1. Go to `/site_admin/properties/settings`
2. Review default categories (types, features, amenities)
3. Add custom labels:
   - Property types specific to your market
   - Features/amenities you want to highlight
4. Organize by category

#### 7. Add First Properties
1. Go to `/site_admin/props`
2. Click "New Property"
3. Enter reference and basic info
4. Click "Create"
5. Complete all tabs:
   - General info
   - Text & descriptions (titles, descriptions)
   - Sale/rental pricing
   - Location
   - Labels/features
   - Photos
6. Repeat for additional properties

#### 8. Configure Email Templates
1. Go to `/site_admin/email_templates`
2. Review available templates:
   - General inquiry
   - Property inquiry
3. Customize if needed:
   - Add company branding
   - Customize message
   - Preview

#### 9. Setup Domain
1. Go to `/site_admin/domain`
2. Enter custom domain name
3. Copy DNS TXT record
4. Add to domain registrar
5. Click "Verify" when DNS propagates

**Result**: Fully functional real estate website ready for visitors

---

## Use Case 2: Importing 500 Properties from Spreadsheet

### Scenario
Agency has 500 properties in Excel and wants to import them all at once instead of manually entering each one.

### Steps

#### 1. Prepare CSV File
1. Go to `/site_admin/property_import_export`
2. Click "Download Template"
3. Open template in Excel
4. Review column headers
5. Map your data to template columns:
   ```
   Reference    → unique property ID
   Address      → street address
   City         → city name
   Price        → sale or rental price
   Bedrooms     → number
   Type         → property type key
   etc...
   ```

#### 2. Export Data to CSV
1. Export your 500 properties from current system
2. Match columns to template format
3. Save as CSV file
4. Verify required columns present:
   - reference (unique ID)
   - street_address
   - city
   - country
   - bedrooms/bathrooms count
   - prop_type_key (must match field keys)

#### 3. Configure Import Options
1. Back to `/site_admin/property_import_export`
2. Upload CSV file
3. Set options:
   - **Update Existing**: Check if importing updates of existing properties
   - **Skip Duplicates**: Check to skip properties with same reference
   - **Default Currency**: Set to EUR, USD, etc.
   - **Create Visible**: Check if should be visible immediately
   - **Dry Run**: RECOMMENDED - check to test without saving

#### 4. Run Test Import (Dry Run)
1. Check the "Dry Run" checkbox
2. Click "Import"
3. Review results:
   - How many would import
   - How many would skip (duplicates)
   - What errors found
4. Fix errors in CSV if needed
5. Review sample errors to understand issues

#### 5. Run Final Import
1. Uncheck "Dry Run"
2. Click "Import"
3. Monitor progress
4. Wait for completion message
5. Review results summary

#### 6. Verify Imported Data
1. Go to `/site_admin/props`
2. Verify property count increased
3. Search for specific properties
4. Click to verify details correct:
   - Prices in correct currency
   - Addresses accurate
   - Photos/media uploaded if included
5. Edit any properties that need adjustment

**Tips**:
- Test with 50-100 properties first
- Use dry run to find format issues
- Review error log for specific problems
- Update existing is useful for regular data syncs

---

## Use Case 3: Managing Multi-Language Website (English & Spanish)

### Scenario
Agency wants to serve both English and Spanish-speaking clients with fully translated website.

### Steps

#### 1. Configure Supported Languages
1. Go to `/site_admin/website/settings?tab=general`
2. Select supported locales:
   - English (en) - primary
   - Spanish (es) - secondary
3. Save

#### 2. Translate Navigation
1. Go to `/site_admin/website/settings?tab=navigation`
2. For each navigation link:
   - Click Edit
   - Enter title in English
   - Enter title in Spanish
   - Save
3. Navigation now shows in visitor's language

#### 3. Add Properties with Translations
1. Go to `/site_admin/props/new`
2. Create property with basic info
3. Go to `edit_text` tab
4. For each sale/rental listing:
   - Enter English title
   - Enter English description
   - Enter Spanish title (title_es)
   - Enter Spanish description (description_es)
5. Set SEO fields in both languages
6. Save

#### 4. Configure Home Page Text
1. Go to `/site_admin/website/settings?tab=home`
2. Edit page title:
   - English: "Home" or "Welcome"
   - Spanish: "Inicio" or "Bienvenido"
3. Save

#### 5. Configure Footer Links
1. Go to `/site_admin/website/settings?tab=navigation`
2. Translate footer links to Spanish
3. Same as top navigation

#### 6. Setup Email Templates
1. Go to `/site_admin/email_templates`
2. Create/edit template
3. Add Spanish content:
   - Spanish subject line
   - Spanish email body
4. Use localization variables
5. Save

#### 7. Configure SEO per Language
1. Go to `/site_admin/website/settings?tab=seo`
2. Set titles and descriptions in both languages
3. Each language has own meta tags
4. Search engines crawl each version

**Result**: 
- Website auto-detects visitor language
- Property descriptions appear in their language
- Navigation, emails, and metadata all translated
- Each property available in English and Spanish

---

## Use Case 4: Adding New Team Member with Specific Permissions

### Scenario
Agency hires property manager who should be able to edit properties but not delete them or manage billing.

### Steps

#### 1. Add User to Team
1. Go to `/site_admin/users`
2. Click "Add Team Member"
3. Choose "Create New User"
4. Enter:
   - Email address
   - First and last names
5. Set role: **Member**
6. Click "Create"
7. System sends invitation email with password setup link

#### 2. User Accepts Invitation
1. User receives email
2. Clicks "Set Password" link
3. Creates account password
4. First login redirects to onboarding

#### 3. Assign Permissions
1. Back in admin, go to `/site_admin/users`
2. Find the new user
3. Click to edit
4. Current permissions show as **Member**
5. New member can:
   - View all properties
   - Edit property details
   - View analytics
   - NOT create/delete properties (depending on role)
   - NOT access billing
   - NOT manage users

#### 4. Upgrade to Admin if Needed
1. Go to `/site_admin/users/:id`
2. Change role from Member to **Admin**
3. Admin can:
   - Create/edit properties
   - Manage some users (not owners)
   - Access website settings
   - See analytics

**Note**: Only Owners can manage other Owners or delete accounts

---

## Use Case 5: Managing Property Photos at Scale

### Scenario
Agency has 200 properties with multiple photos each. They want to organize and optimize.

### Steps

#### 1. Create Folder Structure for Media
1. Go to `/site_admin/media_library`
2. Create folder structure:
   - `properties/`
     - `2024-listings/`
     - `2023-listings/`
     - `archived/`
   - `marketing/`
   - `team/`

#### 2. Upload Batch of Photos
1. Go to `/site_admin/media_library`
2. Click "Upload"
3. Select multiple photos (100+)
4. Choose destination folder
5. Drag-drop to upload
6. Monitor progress

#### 3. Organize Uploaded Files
1. Select photos in media library
2. Bulk move to appropriate folder:
   - Select files
   - Click "Move"
   - Choose destination folder
3. Or individually:
   - Click photo
   - Edit folder assignment
   - Save

#### 4. Add Metadata
1. For each photo:
   - Click to open
   - Add title: "Modern Kitchen - PROP-001"
   - Add alt text: "Modern fitted kitchen with island"
   - Add description: "Kitchen renovation 2024"
   - Add tags: "kitchen, renovation, modern"
2. Save

#### 5. Link Photos to Properties
1. Go to property (`/site_admin/props/:id/edit_photos`)
2. Click "Add From Media Library"
3. Search/browse to find photos
4. Click to add to property
5. Drag to reorder
6. Save

#### 6. Monitor Storage Usage
1. Go to `/site_admin/storage_stats`
2. View:
   - Total files uploaded
   - Total storage used
   - Orphaned files (unused)
3. If storage low:
   - Clean up old photos
   - Archive unneeded files
   - Delete orphans

#### 7. Batch Delete Old Photos
1. Go to `/site_admin/media_library`
2. Navigate to old property folder
3. Select multiple photos
4. Bulk Delete
5. Confirm deletion

**Result**: Organized media library, properties with proper photos, storage optimized

---

## Use Case 6: Analyzing Visitor Behavior to Improve Listings

### Scenario
Agency wants to understand which properties get most interest and optimize listings accordingly.

### Steps

#### 1. Access Analytics Dashboard
1. Go to `/site_admin/analytics`
2. Default shows overview for past 30 days
3. View key metrics:
   - Total visits
   - Unique visitors
   - Common traffic sources

#### 2. Analyze Property Performance
1. Go to `/site_admin/analytics` → Properties
2. View top performing properties:
   - Which get most views
   - Where visitors come from
   - Top search terms used
3. Example insights:
   - "Downtown apartment" gets 500 views/month
   - "Suburban house" gets only 50 views/month

#### 3. Check Traffic Sources
1. Go to `/site_admin/analytics` → Traffic
2. View traffic breakdown:
   - Direct (visitors typing URL)
   - Organic (search engine)
   - Referral (other websites)
   - Social (social media)
3. Example: 70% from Google organic search

#### 4. Review Conversion Funnel
1. Go to `/site_admin/analytics` → Conversions
2. View inquiry funnel:
   - Property views
   - Inquiry form starts
   - Inquiries submitted
   - Conversion rate
3. Example: 2% of property views convert to inquiries

#### 5. Monitor Real-Time Activity
1. Go to `/site_admin/analytics` → Real-Time
2. See active visitors right now
3. View their recent page views
4. Understand current engagement

#### 6. Optimize Based on Data
1. Low-performing properties:
   - Improve photos
   - Update descriptions
   - Lower price
   - Add missing details
2. High-performing properties:
   - Use as template
   - Highlight in marketing
   - Use photos as examples
3. Top search terms:
   - Use in property titles
   - Update descriptions
   - Create marketing campaigns

**Result**: Data-driven property improvements, better conversion rates

---

## Use Case 7: Processing Property Inquiries and Leads

### Scenario
Agency receives inquiries about properties and wants to manage leads effectively.

### Steps

#### 1. View Incoming Messages
1. Go to `/site_admin/messages`
2. List shows recent inquiries from:
   - General contact form
   - Property inquiry form
3. Search by email or content
4. Click to view full message

#### 2. Review Message Details
1. Click on message
2. View:
   - Sender name/email
   - Phone number (if provided)
   - Message content
   - Property inquired about (if applicable)
   - Timestamp
3. Determine follow-up action

#### 3. View Contact Profile
1. Go to `/site_admin/contacts`
2. See all contacts who've submitted forms
3. Find returning visitors
4. View contact history

#### 4. Track Patterns
1. Filter messages by:
   - Date range
   - Property type
   - Sender location (if available)
2. Identify trends:
   - Most inquired properties
   - Best performing regions
   - Peak inquiry times

#### 5. Respond to Inquiries
1. Email addresses auto-configured
2. Responses sent via configured email
3. Customize email templates:
   - Go to `/site_admin/email_templates`
   - Edit inquiry response template
   - Add company branding
   - Personalize message

#### 6. Export Lead Data
1. Go to `/site_admin/contacts`
2. Export contact list to CSV
3. Use in CRM system
4. Track follow-ups separately

**Result**: Organized lead management, response templates, lead tracking

---

## Use Case 8: Regular Maintenance & Optimization

### Scenario
Agency maintains website weekly to keep it current and optimized.

### Steps

#### 1. Weekly Tasks

**Monday - Update Listings**
- Check new properties
- Update sold/rented properties status
- Archive completed listings
- Add new photos to properties

**Wednesday - Analytics Review**
- Check top performing properties
- Review inquiry conversion rate
- Identify underperforming listings
- Plan improvements

**Friday - Content Updates**
- Update home page highlights
- Refresh featured properties
- Update SEO content if needed
- Review and respond to messages

#### 2. Monthly Tasks

**Property Audit**
- Go to `/site_admin/props`
- Review all properties
- Update prices if needed
- Remove expired listings
- Add new photos

**Analytics Report**
- Go to `/site_admin/analytics`
- Export traffic report
- Review conversion trends
- Identify seasonal patterns
- Plan next month's strategy

**Team Updates**
- Check `/site_admin/users`
- Verify all active users
- Update roles if needed
- Remove inactive users

**Cleanliness Check**
- Go to `/site_admin/media_library`
- Review storage usage
- Delete unused media
- Archive old photos
- Organize folders

#### 3. Quarterly Tasks

**Website Redesign?**
- Go to `/site_admin/website/settings?tab=appearance`
- Consider theme update
- Refresh color scheme
- Update CSS if needed

**Analytics Deep Dive**
- Export 90-day analytics
- Analyze trends
- Identify top/bottom performers
- Plan content improvements

**SEO Review**
- Go to `/site_admin/website/settings?tab=seo`
- Update meta descriptions
- Check social media links
- Refresh open graph data

**Team Planning**
- Review activity logs
- Check user engagement
- Plan training if needed
- Update permissions as roles change

---

## Use Case 9: Crisis Management - Website Issue Response

### Scenario
Website is slow or unresponsive. Admin needs to diagnose and fix.

### Steps

#### 1. Check System Status
1. Go to `/site_admin/storage_stats`
2. Check if storage quota exceeded
3. View orphaned files count
4. Run cleanup if needed

#### 2. Review Activity Logs
1. Go to `/site_admin/activity_logs`
2. Filter recent activities
3. Look for error patterns
4. Check failed login attempts
5. Identify potential security issues

#### 3. Check Media Library
1. Go to `/site_admin/media_library`
2. Review file sizes
3. Check for oversized files
4. Check for duplicate files
5. Consider cleanup

#### 4. Review Subscription
1. Go to `/site_admin/billing`
2. Verify plan allows current usage
3. Check property limit not exceeded
4. Check user limit not exceeded
5. Upgrade if needed

#### 5. Check Configuration
1. Go to `/site_admin/website/settings`
2. Review analytics integration
3. Check external image mode settings
4. Verify API keys/tokens valid

#### 6. Contact Support
If still having issues:
1. Gather diagnostics:
   - Activity logs
   - Storage stats
   - Recent changes
   - Error messages
2. Document issue:
   - When it started
   - What changed recently
   - Error messages seen
3. Submit to support with details

---

## Use Case 10: Preparing for Seasonal Campaign

### Scenario
Agency wants to run summer property promotion campaign during peak season.

### Steps

#### 1. Identify Target Properties
1. Go to `/site_admin/analytics`
2. Filter last year's data (same season)
3. Find most popular properties
4. Note seasonal trends
5. Identify properties with "summer potential"

#### 2. Update Listings
1. Go to `/site_admin/props`
2. For campaign properties:
   - Refresh photos (add summer images)
   - Update descriptions (highlight seasonal appeal)
   - Add "summer special" label/feature
   - Consider price adjustments
   - Ensure high visibility

#### 3. Create Promotional Content
1. Go to `/site_admin/pages`
2. Create or update "Summer Specials" page
3. Add seasonal messaging
4. Feature top properties
5. Update home page carousel

#### 4. Setup Email Campaign
1. Go to `/site_admin/email_templates`
2. Create summer campaign template:
   - Seasonal greeting
   - Featured properties
   - Special offer (if applicable)
   - Call to action

#### 5. Configure Navigation
1. Go to `/site_admin/website/settings?tab=navigation`
2. Add "Summer Specials" link
3. Make prominent in navigation
4. Set sort order high

#### 6. Monitor Campaign Performance
1. Go to `/site_admin/analytics`
2. Check daily metrics
3. Track top properties views
4. Monitor conversion rate
5. Compare to historical summer data

#### 7. Adjust Based on Performance
1. Properties getting views?
   - Keep visibility high
   - Add more photos
   - Improve descriptions
2. Properties not performing?
   - Lower price
   - Add features
   - Highlight benefits
   - Consider delisting

#### 8. Campaign End
1. Remove seasonal pages
2. Archive campaign properties if sold/rented
3. Update navigation
4. Prepare next season's content
5. Export campaign analytics for review

**Result**: Successful seasonal campaign, increased inquiries, data for next year

---

## Use Case 11: Disaster Recovery - Restoring Backup

### Scenario
Data loss occurs and need to restore properties from backup CSV.

### Steps

#### 1. Obtain Backup File
1. Retrieve CSV backup from:
   - Previous export
   - External storage
   - Email archive
2. Verify file integrity
3. Open and review contents

#### 2. Prepare for Restore
1. Go to `/site_admin/property_import_export`
2. Download current template to compare
3. Verify backup CSV format matches
4. Make note of differences

#### 3. Test with Dry Run
1. Upload backup CSV
2. Check "Dry Run"
3. Set options:
   - Update Existing: **YES** (to restore deleted)
   - Skip Duplicates: NO
   - Create Visible: YES
4. Run import
5. Review results

#### 4. Fix Any Issues
1. Review error log
2. Edit CSV for issues found:
   - Format errors
   - Invalid field keys
   - Missing required data
3. Re-test with dry run

#### 5. Run Final Restore
1. Uncheck "Dry Run"
2. Run import
3. Monitor completion
4. Verify all properties restored

#### 5. Verify Data Integrity
1. Go to `/site_admin/props`
2. Check property count matches backup
3. Search for specific properties
4. Verify prices and details
5. Check photos if backed up separately

#### 6. Restore Photos Separately
1. Go to `/site_admin/media_library`
2. Upload photos from backup:
   - Batch upload if many
   - Organize in folders
   - Link to properties
3. Go to each property
4. Add photos from library
5. Verify all restored

**Result**: Data restored, website back online, losses minimized

---

## Use Case 12: Compliance & Security Audit

### Scenario
Regular security audit requires documentation of access and changes.

### Steps

#### 1. Review User Access
1. Go to `/site_admin/users`
2. Document:
   - All active users
   - User roles
   - Active status
3. Identify inactive users
4. Remove if no longer needed

#### 2. Check Activity Logs
1. Go to `/site_admin/activity_logs`
2. Filter by date range (last 90 days)
3. Review:
   - All login attempts
   - Failed logins
   - User actions
   - Configuration changes
4. Look for suspicious activity
5. Document findings

#### 3. Export Audit Report
1. Navigate activity logs
2. Filter by period
3. Export/download results
4. Create audit trail document

#### 4. Review Permissions
1. For each user:
   - Go to `/site_admin/users`
   - Check assigned role
   - Verify appropriate for job
   - Note any changes needed
2. Document permission audit

#### 5. Check Data Security
1. Go to `/site_admin/domain`
2. Verify custom domain using HTTPS
3. Check custom domain verified
4. Review DNS records are correct

#### 6. Review Access Controls
1. Check notification settings
2. Verify email configurations
3. Check API access if enabled
4. Review third-party integrations

#### 7. Create Audit Report
Document:
- Users and roles
- Access history
- Changes made
- Anomalies found
- Recommendations
- Sign-off date

**Result**: Complete security audit documentation, compliance ready

