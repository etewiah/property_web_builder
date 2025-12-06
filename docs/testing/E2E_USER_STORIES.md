# E2E User Stories for PropertyWebBuilder

This document contains user stories organized by persona and feature area, designed to drive end-to-end testing.

---

## Personas

| Persona | Description | Access Level |
|---------|-------------|--------------|
| **Public Visitor** | Unauthenticated user browsing properties | Public pages only |
| **Registered User** | Authenticated user with no admin rights | Public + saved searches |
| **Site Admin** | Website administrator | `/site_admin/*` routes |
| **Tenant Admin** | Super admin managing multiple websites | `/tenant_admin/*` routes |

---

## Epic 1: Public Property Browsing

### US-1.1: View Property Listings
**As a** public visitor
**I want to** browse available properties
**So that** I can find properties that interest me

**Acceptance Criteria:**
- [ ] Property listing page displays all active properties
- [ ] Each property card shows: photo, title, price, location, key features
- [ ] Properties are paginated (default 12 per page)
- [ ] Sale and rental properties are clearly distinguished

**Test Scenarios:**
```gherkin
Scenario: View property listing page
  Given I am on the homepage
  When I navigate to the properties page
  Then I should see a grid of property cards
  And each card should display the property image, title, and price

Scenario: Pagination works correctly
  Given there are 25 properties in the database
  When I view the property listing page
  Then I should see 12 properties
  And I should see pagination controls
  When I click "Next"
  Then I should see the next set of properties
```

---

### US-1.2: Search Properties with Filters
**As a** public visitor
**I want to** filter properties by various criteria
**So that** I can narrow down my search to relevant listings

**Acceptance Criteria:**
- [ ] Filter by transaction type (sale/rent)
- [ ] Filter by price range (min/max)
- [ ] Filter by location/area
- [ ] Filter by property type (apartment, house, land, etc.)
- [ ] Filter by number of bedrooms/bathrooms
- [ ] Multiple filters can be combined
- [ ] Results update dynamically or on form submission

**Test Scenarios:**
```gherkin
Scenario: Filter properties by price range
  Given there are properties priced at 100k, 200k, 300k, and 500k
  When I set minimum price to 150000
  And I set maximum price to 350000
  And I apply the filters
  Then I should see only the 200k and 300k properties

Scenario: Filter properties for sale only
  Given there are 5 sale listings and 3 rental listings
  When I select "For Sale" filter
  Then I should see only 5 properties
  And all displayed properties should be for sale

Scenario: Combine multiple filters
  Given there are various properties in the database
  When I filter by "For Rent"
  And I filter by "2+ bedrooms"
  And I filter by location "Downtown"
  Then I should see only rental properties with 2+ bedrooms in Downtown
```

---

### US-1.3: View Property Details
**As a** public visitor
**I want to** view detailed information about a property
**So that** I can decide if I want to inquire about it

**Acceptance Criteria:**
- [ ] Full property description is displayed
- [ ] Photo gallery with multiple images
- [ ] Property features list (bedrooms, bathrooms, area, etc.)
- [ ] Price and transaction type clearly shown
- [ ] Location map with property marker
- [ ] Contact/inquiry form is accessible
- [ ] Similar properties are suggested

**Test Scenarios:**
```gherkin
Scenario: View complete property details
  Given a property exists with full details and 5 photos
  When I click on the property card
  Then I should see the property detail page
  And I should see all 5 photos in a gallery
  And I should see the full description
  And I should see a location map
  And I should see an inquiry form

Scenario: Photo gallery navigation
  Given I am on a property detail page with multiple photos
  When I click on a thumbnail
  Then the main image should update to that photo
  When I click the next arrow
  Then I should see the next photo
```

---

### US-1.4: Submit Property Inquiry
**As a** public visitor
**I want to** send an inquiry about a property
**So that** the agency can contact me with more information

**Acceptance Criteria:**
- [ ] Inquiry form requires name, email, phone (optional), message
- [ ] Form validates required fields
- [ ] Submission creates a contact record linked to the property
- [ ] User sees confirmation message after submission
- [ ] Agency receives notification (if configured)

**Test Scenarios:**
```gherkin
Scenario: Submit valid property inquiry
  Given I am on a property detail page
  When I fill in the inquiry form with valid details
  And I submit the form
  Then I should see a success message
  And a contact record should be created in the database
  And the contact should be linked to this property

Scenario: Inquiry form validation
  Given I am on a property detail page
  When I submit the inquiry form without filling required fields
  Then I should see validation error messages
  And no contact record should be created
```

---

### US-1.5: Submit General Contact Form
**As a** public visitor
**I want to** contact the agency without referencing a specific property
**So that** I can ask general questions

**Acceptance Criteria:**
- [ ] Contact page is accessible from navigation
- [ ] Form requires name, email, message
- [ ] Submission creates a contact record (not linked to property)
- [ ] User sees confirmation message

**Test Scenarios:**
```gherkin
Scenario: Submit general contact form
  Given I am on the contact page
  When I fill in my name, email, and message
  And I submit the form
  Then I should see a success message
  And a general contact record should be created
```

---

## Epic 2: Content Pages

### US-2.1: View CMS Pages
**As a** public visitor
**I want to** view informational pages (About, Services, etc.)
**So that** I can learn more about the agency

**Acceptance Criteria:**
- [ ] Pages render their content blocks correctly
- [ ] Navigation links to published pages
- [ ] Unpublished pages return 404
- [ ] Multi-language content displays based on locale

**Test Scenarios:**
```gherkin
Scenario: View About page
  Given an "About Us" page exists and is published
  When I click "About Us" in the navigation
  Then I should see the About page content
  And the page title should be correct

Scenario: Cannot view unpublished page
  Given a page exists but is not published
  When I try to access the page URL directly
  Then I should see a 404 error
```

---

### US-2.2: Navigate Website
**As a** public visitor
**I want to** use the navigation menu
**So that** I can find different sections of the website

**Acceptance Criteria:**
- [ ] Top navigation displays configured menu items
- [ ] Footer navigation displays configured links
- [ ] Active page is highlighted in navigation
- [ ] Mobile navigation works (hamburger menu)

**Test Scenarios:**
```gherkin
Scenario: Use top navigation
  Given the website has configured navigation items
  When I view any page
  Then I should see the navigation menu
  And clicking a nav item should take me to that page

Scenario: Mobile navigation
  Given I am viewing the site on a mobile device
  When I click the hamburger menu icon
  Then I should see the navigation menu
  When I click a menu item
  Then I should navigate to that page
```

---

## Epic 3: Site Administration - Properties

### US-3.1: Admin Login
**As a** site admin
**I want to** log into the admin panel
**So that** I can manage my website

**Acceptance Criteria:**
- [ ] Login page is accessible at `/site_admin/login`
- [ ] Valid credentials grant access to admin panel
- [ ] Invalid credentials show error message
- [ ] Session persists across page refreshes
- [ ] Logout functionality works

**Test Scenarios:**
```gherkin
Scenario: Successful admin login
  Given I am a registered admin user
  When I navigate to the admin login page
  And I enter valid credentials
  And I submit the login form
  Then I should be redirected to the admin dashboard
  And I should see admin navigation options

Scenario: Failed login with invalid credentials
  Given I am on the admin login page
  When I enter invalid credentials
  And I submit the login form
  Then I should see an error message
  And I should remain on the login page

Scenario: Admin logout
  Given I am logged into the admin panel
  When I click the logout button
  Then I should be logged out
  And I should be redirected to the public site
```

---

### US-3.2: Create New Property
**As a** site admin
**I want to** add a new property listing
**So that** it appears on the public website

**Acceptance Criteria:**
- [ ] Property form includes all required fields
- [ ] Can upload multiple photos
- [ ] Can set as sale or rental (or both)
- [ ] Can set price and currency
- [ ] Can add location/address with geocoding
- [ ] Property is visible on public site after creation

**Test Scenarios:**
```gherkin
Scenario: Create a sale property
  Given I am logged into the admin panel
  When I navigate to "Properties" > "New Property"
  And I fill in the property title and description
  And I set the property type to "Apartment"
  And I add a sale listing with price 250000
  And I upload 3 photos
  And I save the property
  Then I should see a success message
  And the property should appear in the admin property list
  And the property should be visible on the public site

Scenario: Create a rental property with monthly price
  Given I am logged into the admin panel
  When I create a new property
  And I add a rental listing with price 1500 per month
  And I save the property
  Then the property should display as "For Rent - $1,500/month"
```

---

### US-3.3: Edit Existing Property
**As a** site admin
**I want to** modify property details
**So that** I can keep listings accurate and up-to-date

**Acceptance Criteria:**
- [ ] Can edit all property fields
- [ ] Can add/remove photos
- [ ] Can reorder photos
- [ ] Can change price
- [ ] Changes reflect on public site immediately

**Test Scenarios:**
```gherkin
Scenario: Update property price
  Given a property exists with price 200000
  When I edit the property
  And I change the price to 220000
  And I save the changes
  Then the property should display the new price on the public site

Scenario: Add photos to existing property
  Given a property exists with 2 photos
  When I edit the property
  And I upload 2 additional photos
  And I save the changes
  Then the property should have 4 photos

Scenario: Reorder property photos
  Given a property exists with 3 photos
  When I edit the property
  And I drag photo 3 to position 1
  And I save the changes
  Then photo 3 should now be the primary photo
```

---

### US-3.4: Delete Property
**As a** site admin
**I want to** remove a property listing
**So that** sold/rented properties don't clutter the site

**Acceptance Criteria:**
- [ ] Confirmation required before deletion
- [ ] Property is removed from public site
- [ ] Associated photos are cleaned up
- [ ] Related inquiries are preserved (soft delete consideration)

**Test Scenarios:**
```gherkin
Scenario: Delete a property
  Given a property exists
  When I click delete on the property
  Then I should see a confirmation dialog
  When I confirm the deletion
  Then the property should be removed from the list
  And the property should not appear on the public site
```

---

### US-3.5: Manage Property Photos
**As a** site admin
**I want to** manage property images effectively
**So that** listings look professional

**Acceptance Criteria:**
- [ ] Upload multiple images at once
- [ ] Set primary/featured image
- [ ] Delete individual images
- [ ] Images are resized/optimized automatically

**Test Scenarios:**
```gherkin
Scenario: Set featured image
  Given a property has 5 photos
  When I set photo 3 as the featured image
  Then photo 3 should appear as the main image on property cards
```

---

## Epic 4: Site Administration - Content

### US-4.1: Manage Pages
**As a** site admin
**I want to** create and edit website pages
**So that** I can customize the site content

**Acceptance Criteria:**
- [ ] Create new pages with title and slug
- [ ] Add content blocks (page parts) to pages
- [ ] Edit existing page content
- [ ] Publish/unpublish pages
- [ ] Delete pages

**Test Scenarios:**
```gherkin
Scenario: Create a new page
  Given I am in the admin panel
  When I navigate to "Pages" > "New Page"
  And I enter title "Our Services"
  And I add a text content block
  And I publish the page
  Then the page should be accessible at "/our-services"

Scenario: Edit page content
  Given a page "About Us" exists
  When I edit the page
  And I modify the content
  And I save changes
  Then the public page should show updated content
```

---

### US-4.2: Manage Navigation
**As a** site admin
**I want to** configure site navigation
**So that** visitors can find pages easily

**Acceptance Criteria:**
- [ ] Add items to top navigation
- [ ] Add items to footer navigation
- [ ] Reorder navigation items
- [ ] Link to internal pages or external URLs
- [ ] Remove navigation items

**Test Scenarios:**
```gherkin
Scenario: Add page to navigation
  Given a page "Services" exists
  When I go to navigation settings
  And I add "Services" to the top navigation
  And I save changes
  Then "Services" should appear in the public site navigation
```

---

### US-4.3: Configure Website Settings
**As a** site admin
**I want to** configure general website settings
**So that** the site reflects my agency's brand

**Acceptance Criteria:**
- [ ] Set website name/title
- [ ] Upload logo
- [ ] Configure contact information
- [ ] Set default currency
- [ ] Configure SEO settings (meta description, etc.)

**Test Scenarios:**
```gherkin
Scenario: Update website name
  Given I am in website settings
  When I change the website name to "Premier Properties"
  And I save changes
  Then the public site should display "Premier Properties" in the header

Scenario: Upload agency logo
  Given I am in website settings
  When I upload a new logo image
  And I save changes
  Then the new logo should appear on the public site
```

---

## Epic 5: Site Administration - Contacts

### US-5.1: View Contact Inquiries
**As a** site admin
**I want to** see all contact form submissions
**So that** I can follow up with potential clients

**Acceptance Criteria:**
- [ ] List all contacts with date, name, email
- [ ] Show which property (if any) the inquiry relates to
- [ ] Mark contacts as read/unread
- [ ] Filter by date range or property

**Test Scenarios:**
```gherkin
Scenario: View contact list
  Given there are 5 contact inquiries
  When I navigate to the Contacts section
  Then I should see all 5 contacts
  And each contact should show name, email, and date

Scenario: View property-specific inquiry
  Given a contact inquiry exists for property "Beach House"
  When I view the contact details
  Then I should see a link to "Beach House" property
```

---

### US-5.2: Respond to Inquiries
**As a** site admin
**I want to** track my responses to inquiries
**So that** I don't miss any leads

**Acceptance Criteria:**
- [ ] View full message content
- [ ] Add internal notes to contacts
- [ ] Mark contact status (new, in progress, closed)

**Test Scenarios:**
```gherkin
Scenario: Mark inquiry as handled
  Given a new contact inquiry exists
  When I view the contact
  And I mark it as "closed"
  Then the contact should show as closed in the list
```

---

## Epic 6: Multi-Tenancy

### US-6.1: Tenant Data Isolation
**As a** site admin
**I want** my data to be completely isolated from other tenants
**So that** my business information is secure

**Acceptance Criteria:**
- [ ] Cannot see other tenants' properties
- [ ] Cannot see other tenants' contacts
- [ ] Cannot access other tenants' admin panels
- [ ] API responses only include current tenant data

**Test Scenarios:**
```gherkin
Scenario: Data isolation between tenants
  Given tenant A has 5 properties
  And tenant B has 3 properties
  When I am logged into tenant A's admin
  Then I should only see 5 properties
  And I should not see tenant B's properties

Scenario: Cannot access other tenant by direct URL
  Given I am logged into tenant A
  And tenant B has a property with ID 123
  When I try to access "/site_admin/properties/123"
  Then I should see an error or 404
  And I should not see tenant B's property data

Scenario: Public site shows only tenant's properties
  Given tenant A has properties on subdomain "agencyA"
  And tenant B has properties on subdomain "agencyB"
  When I visit agencyA.example.com
  Then I should only see tenant A's properties
```

---

### US-6.2: Subdomain Routing
**As a** public visitor
**I want to** access different agencies via subdomains
**So that** each agency has their own branded site

**Acceptance Criteria:**
- [ ] Each tenant accessible via unique subdomain
- [ ] Correct content loads for each subdomain
- [ ] Invalid subdomain shows appropriate error

**Test Scenarios:**
```gherkin
Scenario: Access tenant via subdomain
  Given tenant "premier" exists
  When I visit premier.example.com
  Then I should see Premier's website content
  And I should see Premier's properties

Scenario: Invalid subdomain handling
  Given no tenant exists with subdomain "nonexistent"
  When I visit nonexistent.example.com
  Then I should see an appropriate error page
```

---

## Epic 7: Multi-Language Support

### US-7.1: View Content in Different Languages
**As a** public visitor
**I want to** view the website in my preferred language
**So that** I can understand the content

**Acceptance Criteria:**
- [ ] Language switcher available
- [ ] Content displays in selected language
- [ ] Property descriptions translated
- [ ] Navigation labels translated
- [ ] Fallback to default language if translation missing

**Test Scenarios:**
```gherkin
Scenario: Switch website language
  Given the website supports English and Spanish
  When I select Spanish from the language switcher
  Then the interface should display in Spanish
  And property descriptions should show Spanish versions

Scenario: Fallback for missing translation
  Given a property has English description but no Spanish
  When I view the site in Spanish
  Then I should see the English description as fallback
```

---

## Epic 8: User Management

### US-8.1: Manage Team Members
**As a** site admin
**I want to** add team members to help manage the site
**So that** workload can be distributed

**Acceptance Criteria:**
- [ ] Invite new users by email
- [ ] Assign roles (admin, editor, viewer)
- [ ] Remove users from website
- [ ] Users can belong to multiple websites

**Test Scenarios:**
```gherkin
Scenario: Invite team member
  Given I am a site admin
  When I invite user@example.com as an editor
  Then the user should receive an invitation
  And upon accepting, they should have editor access

Scenario: Role-based access
  Given a user has "viewer" role
  When they access the admin panel
  Then they should be able to view content
  But they should not be able to edit or delete
```

---

## Test Data Requirements

### Seed Data for E2E Tests

1. **Tenants/Websites**
   - Tenant A: "Premier Properties" (subdomain: premier)
   - Tenant B: "City Realty" (subdomain: cityrealty)

2. **Users**
   - Admin for Tenant A
   - Editor for Tenant A
   - Admin for Tenant B
   - User with access to both tenants

3. **Properties** (per tenant)
   - 5 sale properties (various types, prices)
   - 3 rental properties
   - 1 property with both sale and rental
   - Properties with varying photo counts (0, 1, 5, 10)

4. **Pages** (per tenant)
   - Home page
   - About page
   - Contact page
   - 1 unpublished page

5. **Contacts** (per tenant)
   - 3 general inquiries
   - 2 property-specific inquiries

---

## Priority Matrix

| Priority | User Stories | Rationale |
|----------|-------------|-----------|
| P0 (Critical) | US-1.1, US-1.3, US-3.1, US-3.2, US-6.1 | Core functionality and security |
| P1 (High) | US-1.2, US-1.4, US-3.3, US-5.1, US-6.2 | Important user journeys |
| P2 (Medium) | US-2.1, US-4.1, US-4.3, US-7.1 | Content and customization |
| P3 (Low) | US-2.2, US-4.2, US-5.2, US-8.1 | Nice-to-have features |

---

## Running E2E Tests

```bash
# Run all E2E tests
RAILS_ENV=e2e bundle exec rspec spec/features

# Run specific epic
RAILS_ENV=e2e bundle exec rspec spec/features/property_browsing

# Run with browser visible (for debugging)
HEADLESS=false RAILS_ENV=e2e bundle exec rspec spec/features
```
