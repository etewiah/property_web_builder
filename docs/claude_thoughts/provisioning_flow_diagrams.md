# PropertyWebBuilder Provisioning Flow Diagrams

## 1. Current Website Creation Flow

```
Admin User
    ↓
Tenant Admin UI → /websites/new
    ↓
WebsitesController#new
    ↓
Render form with fields:
  - subdomain
  - company_display_name
  - theme_name
  - supported_locales[]
  - default_currency
  - default_area_unit
  - default_client_locale
  - [CHECKBOX] seed_data
  - [CHECKBOX] skip_properties
    ↓
Admin submits
    ↓
WebsitesController#create
    ↓
Pwb::Website.create!(params)
    ↓
Website saved ✓
    ↓
if params[:seed_data] == "1" ?
    ├─ YES → seed_website_content(website, skip_properties)
    │          ├─ Pwb::Seeder.seed!(website: website)
    │          ├─ Pwb::PagesSeeder.seed_page_parts!
    │          └─ Pwb::ContentsSeeder.seed_page_content_translations!
    │
    └─ NO → Skip seeding
    ↓
Redirect to show page
```

## 2. Request Routing & Tenant Resolution

```
HTTP Request Arrives
    ↓
extract host from request.host
    │
    ├─ "costa-luxury.propertywebbuilder.com" ?
    │       ↓ YES
    │   Extract subdomain "costa-luxury"
    │       ↓
    │   Website.find_by_subdomain('costa-luxury')
    │
    ├─ "costaluxury.es" ?
    │       ↓ YES
    │   Website.find_by_custom_domain('costaluxury.es')
    │       ↓
    │   Domain verified?
    │       ├─ YES → Load website
    │       ├─ NO (dev/test) → Load website
    │       └─ NO (prod) → 404
    │
    └─ No match?
            ↓
        Use first website or 404
    ↓
Set Pwb::Current.website = website
    ↓
Continue request with website context
```

## 3. Seed Pack Application Flow

```
rails pwb:seed_packs:apply[spain_luxury, website_id]
    ↓
SeedPacksController#apply
    ↓
Pwb::SeedPack.find('spain_luxury')
    ↓
Load pack.yml configuration
    ↓
Validate pack (display_name, website config)
    ↓
pack.apply!(website: website)
    ↓
Check parent pack: inherits_from: base?
    ├─ YES → Apply parent pack first
    │          (with skip_website: true, skip_agency: true)
    │
    └─ NO → Continue to child pack
    ↓
Seed sections in order:
    │
    ├─ seed_website()
    │   └─ Update theme_name, currency, locales, etc.
    │
    ├─ seed_agency()
    │   ├─ Create/update Agency
    │   ├─ Create primary Address
    │   └─ Associate with website
    │
    ├─ seed_field_keys()
    │   └─ Load field_keys.yml
    │   └─ Create FieldKey records for types, features, amenities
    │
    ├─ seed_links()
    │   └─ Load links.yml
    │   └─ Create Link records for navigation
    │
    ├─ seed_pages()
    │   └─ Create Page records (home, about-us, contact-us, etc.)
    │
    ├─ seed_page_parts()
    │   └─ Create PagePart records (components on pages)
    │
    ├─ seed_properties()
    │   ├─ Load properties/*.yml files
    │   ├─ For each property:
    │   │   ├─ Create RealtyAsset record
    │   │   ├─ Create SaleListing/RentalListing
    │   │   └─ Add photos from images/
    │   └─ Refresh ListedProperty materialized view
    │
    ├─ seed_content()
    │   ├─ Load content/*.yml files
    │   └─ Create Content records with translations
    │
    ├─ seed_users()
    │   ├─ Load users config from pack.yml
    │   ├─ For each user:
    │   │   ├─ Create/find Pwb::User
    │   │   └─ Create UserMembership
    │   └─ Set role (admin, member, etc.)
    │
    └─ seed_translations()
        ├─ Load translations/*.yml files
        └─ Create I18n translation records
    ↓
Refresh ListedProperty materialized view
    ↓
Output: Seed pack applied successfully ✓
```

## 4. User Authentication & Multi-Website Access

```
User submits login form
    ↓
email: "agent@costaluxury.es"
password: "****"
    ↓
Devise authenticates (Pwb::User#find_or_create_for_oauth)
    ↓
Check: user.active_for_authentication?
    ├─ No current website context?
    │   └─ Allow authentication ✓
    │
    └─ Current website exists?
        ├─ user.website_id == current_website.id?
        │   └─ Allow ✓
        │
        ├─ user has active UserMembership for current_website?
        │   └─ Allow ✓
        │
        ├─ user.firebase_uid present?
        │   └─ Allow ✓
        │
        └─ No match?
            └─ Deny (wrong website context)
    ↓
User signed in
    ↓
user.accessible_websites
    │
    ├─ If single website → Only that site
    ├─ If multiple memberships → All active memberships
    └─ Can switch between websites in UI
```

## 5. Property Seeding Architecture

```
Seed Pack includes: properties/
    │
    ├─ villa_marbella.yml
    │       ↓
    │   Property YAML parsed
    │       ↓
    │   Create Pwb::RealtyAsset
    │   ├─ address, size, features
    │   ├─ website_id (scoped to tenant)
    │   └─ reference (unique ID)
    │
    └─ apartment_fuengirola_rental.yml
            ↓
        Create Pwb::RentalListing
        ├─ realty_asset_id
        ├─ price, currency
        ├─ availability
        └─ translations (es, en, de)
    ↓
Photos referenced in pack.yml
    │
    ├─ images/villa_marbella_1.jpg → Create ContentPhoto
    ├─ images/villa_marbella_2.jpg → Create ContentPhoto
    └─ ...
    ↓
Pwb::ListedProperty.refresh
    │
    └─ Materialized view updated
        ├─ Optimized read-only property view
        ├─ Combines RealtyAsset + Listings + translations
        └─ Used for search & display
```

## 6. Multi-Tenancy Data Isolation

```
Pwb::Website (Tenant)
    │
    ├─ id: 1
    ├─ subdomain: "costa-luxury"
    └─ company_display_name: "Costa Luxury"
    
    ↓ relationships
    
    ├─ Pages (website_id scoped)
    │   ├─ /home
    │   ├─ /about-us
    │   └─ /contact-us
    │   
    ├─ Content (website_id + key scoped)
    │   ├─ footer_text
    │   └─ company_info
    │
    ├─ Links (website_id + slug scoped)
    │   ├─ top_nav_home
    │   ├─ footer_about
    │   └─ social_facebook
    │
    ├─ RealtyAssets (Properties - website_id scoped)
    │   ├─ Villa Marbella
    │   ├─ Penthouse Barcelona
    │   └─ Apartment Malaga
    │
    ├─ FieldKeys (website_id scoped)
    │   ├─ villa, apartment, townhouse (types)
    │   ├─ pool, garden, garage (features)
    │   └─ furnished, renovated (amenities)
    │
    ├─ Agency (one per website)
    │   ├─ display_name: "Costa Luxury Properties"
    │   ├─ email, phone
    │   └─ addresses
    │
    └─ UserMemberships (users with access to this site)
        ├─ User#1 (owner) → admin
        ├─ User#2 (agent) → member
        └─ User#3 (viewer) → viewer


Another Website:
    │
    ├─ id: 2
    ├─ subdomain: "amsterdam-homes"
    └─ company_display_name: "Amsterdam Realty"
    
    ↓ relationships
    
    ├─ Pages (can have SAME slug, different website_id)
    │   ├─ /home (website_id: 2)  ← Different from website 1!
    │   ├─ /about-us
    │   └─ /contact-us
    │
    ├─ RealtyAssets
    │   ├─ Canal House Amsterdam
    │   ├─ Townhouse Utrecht
    │   └─ Apartment Rotterdam
    │
    ├─ FieldKeys (can have SAME key, different website_id)
    │   ├─ apartment (website_id: 2)  ← Different translations
    │   └─ ...
    │
    └─ UserMemberships
        ├─ User#2 (agent) → admin  ← Same user, different role!
        └─ User#4 → member
```

## 7. Domain Routing Priority

```
Request arrives with host: "costaluxury.es"
    ↓
Is this a custom domain?
    │
    ├─ YES → Website.find_by_custom_domain('costaluxury.es')
    │            ↓
    │        Custom domain found?
    │            ├─ YES → Is verified?
    │            │           ├─ YES → Load website ✓
    │            │           ├─ NO (prod) → 404 ❌
    │            │           └─ NO (dev/test) → Load website ✓
    │            └─ NO → Continue to subdomain check
    │
    └─ NO → Check if matches platform domain
                ├─ Extract subdomain part
                └─ Website.find_by_subdomain(subdomain)
                    ├─ Found → Load website ✓
                    └─ Not found → Use first website or 404


Example flows:

1. costa-luxury.propertywebbuilder.com
   → Platform domain ✓
   → Extract: costa-luxury
   → Website.find_by_subdomain('costa-luxury')
   → Load website ✓

2. costaluxury.es
   → Custom domain check
   → Website.find_by_custom_domain('costaluxury.es')
   → Is verified? YES → Load website ✓

3. example.com (no match)
   → Not platform domain
   → Not found in custom domains
   → 404 or use default website
```

## 8. Seed Pack Inheritance Diagram

```
base pack
├─ field_keys.yml        ← Core property taxonomy
├─ links.yml             ← Common navigation
├─ pages/
├─ page_parts/
└─ website config
   ├─ theme: bristol
   ├─ locale: en
   └─ currency: EUR
    ↑
    │ inherits_from: base
    │
    ├─────────────────────────────────────┐
    │                                     │
spain_luxury pack          netherlands_urban pack
├─ pack.yml                ├─ pack.yml
├─ agency.yml              ├─ agency.yml
├─ website config (override)
│  ├─ theme: bristol       │  ├─ theme: bristol
│  ├─ locale: es (es not en)
│  ├─ currency: EUR        │  ├─ currency: EUR
│  └─ supported: es,en,de  │  └─ supported: nl,en
├─ properties/             ├─ properties/
│  ├─ villa_marbella.yml   │  ├─ grachtenpand_amsterdam.yml
│  ├─ penthouse_barcelona  │  ├─ loft_amsterdam.yml
│  └─ ...                  │  └─ ...
├─ translations/           ├─ translations/
│  ├─ es.yml              │  ├─ nl.yml
│  ├─ en.yml              │  └─ en.yml
│  └─ de.yml
└─ users:
   ├─ admin@costaluxury.es
   └─ agent@costaluxury.es


When applying spain_luxury:

1. Apply base pack
   ├─ Seed field keys from base
   ├─ Seed links from base
   └─ Seed website config (theme, currency)

2. Apply spain_luxury pack (child)
   ├─ Seed website config again (OVERRIDES base)
   │  └─ locale: es instead of en
   ├─ Seed agency
   ├─ Seed properties from spain_luxury
   ├─ Seed users from spain_luxury
   └─ Seed translations from spain_luxury
```

## 9. Custom Domain Verification Flow

```
Website Owner
    │
    ├─ Adds custom domain in admin UI
    │   └─ website.update(custom_domain: 'costaluxury.es')
    │
    ├─ System generates verification token
    │   └─ website.generate_domain_verification_token!
    │   └─ custom_domain_verification_token = 'abc123def456...'
    │
    ├─ System displays instructions to owner:
    │   │
    │   ├─ "Add this DNS TXT record:"
    │   ├─ "Name: _pwb-verification.costaluxury.es"
    │   ├─ "Type: TXT"
    │   └─ "Value: abc123def456..."
    │
    └─ Owner configures DNS
            │
            ├─ Logs into domain registrar
            │   (GoDaddy, Namecheap, etc.)
            │
            └─ Adds TXT record:
                Name: _pwb-verification.costaluxury.es
                Type: TXT
                Value: abc123def456...
    ↓
    (DNS propagation takes 24-48 hours)
    ↓
Owner clicks "Verify Domain" in UI
    │
    └─ website.verify_custom_domain!
            │
            ├─ Queries DNS for _pwb-verification.costaluxury.es
            │   └─ require 'resolv'
            │   └─ Resolver.new.getresources(...)
            │
            ├─ TXT record found?
            │   ├─ YES → Matches verification_token?
            │   │       ├─ YES → Mark verified ✓
            │   │       │       └─ custom_domain_verified = true
            │   │       │       └─ custom_domain_verified_at = Time.now
            │   │       └─ NO → Verification failed ❌
            │   │
            │   └─ NO → Try again later (DNS propagation pending)
            │
            └─ Return result
    ↓
custom_domain_active? returns true
    │
    └─ Requests to costaluxury.es now route to website ✓
```

## 10. User Invitation & Multi-Website Assignment

```
Admin in Website A wants to invite User to Website B
    │
    ├─ Find/create User record
    │   └─ Pwb::User.create!(email, password)
    │
    ├─ Create UserMembership for Website A
    │   └─ Pwb::UserMembership.create!(
    │       user: user,
    │       website: website_a,
    │       role: 'admin',
    │       active: true
    │   )
    │
    ├─ Send invitation email (if configured)
    │   └─ User clicks link, sets password
    │
    └─ Create additional UserMembership for Website B
            └─ Pwb::UserMembership.create!(
                user: user,
                website: website_b,
                role: 'member',
                active: true
            )
    ↓
User now has access to both websites
    │
    ├─ Login on website_a.com
    │   └─ Authentication checks:
    │   ├─ user.website_id == website_a.id? YES → Allow ✓
    │   ├─ OR user.user_memberships.active.exists?(website: website_a)? YES → Allow ✓
    │
    └─ Login on website_b.com
            └─ Same checks pass
            └─ Allow ✓
    ↓
User can switch between websites
    │
    ├─ UI shows: "Switch to Website B"
    ├─ Click
    └─ Redirect to website_b.com
            └─ Current website context switches
            └─ Pwb::Current.website = website_b
```

---

## Legend

```
─→  Process flow (synchronous)
→   Data direction
├─  Branch (conditional or grouping)
✓   Success state
❌  Failure state
```

