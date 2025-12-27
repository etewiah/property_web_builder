# Test Implementation Quick Start Guide

This guide provides concrete examples for addressing the high-priority test gaps identified in `test_coverage_gap_analysis.md`.

---

## 1. EmailTemplateRenderer Tests - Template: 20 tests

**File:** `spec/services/pwb/email_template_renderer_spec.rb`

### Key Test Cases to Add

```ruby
RSpec.describe Pwb::EmailTemplateRenderer, type: :model do
  let(:website) { create(:pwb_website, company_display_name: 'Acme Realty') }
  
  describe 'default template rendering' do
    it 'renders enquiry.general with variables' do
      renderer = described_class.new(website: website, template_key: 'enquiry.general')
      result = renderer.render({
        'visitor_name' => 'John Doe',
        'visitor_email' => 'john@example.com',
        'message' => 'Interested in properties'
      })
      
      expect(result[:subject]).to include('John Doe')
      expect(result[:body_html]).to include('john@example.com')
      expect(result[:body_html]).to include('Interested in properties')
    end
    
    # Add 19 more tests covering:
    # - enquiry.property with property_title, property_reference, property_url
    # - enquiry.auto_reply with website_name substitution
    # - alert.new_property with property_price, subscriber_name
    # - alert.price_change with old_price, new_price
    # - user.welcome template
    # - user.password_reset with reset_url
    # - All templates with missing variables (nil handling)
    # - Liquid syntax error handling
    # - HTML to text conversion (entities, nested tags)
    # - Custom template fallback when available
  end
  
  describe 'custom template fallback' do
    # Test that custom EmailTemplate.find_for_website works
    # Test rendering with custom template instead of default
  end
  
  describe 'html_to_text conversion' do
    # <br/> → newline
    # </p> → double newline
    # <a href="url">text</a> → text (url)
    # Nested <h1><strong>Title</strong></h1>
    # HTML entities: &nbsp;, &amp;, &lt;, &gt;
  end
  
  describe 'variable substitution with locale' do
    # I18n.locale changes website_name display?
    # Ensure BASE_LOCALES covered
  end
end
```

**Test Count:** 20 (covers all template types, error cases, conversions)

---

## 2. Seeding Edge Cases - Template: 15 tests

**File:** Add to `spec/libraries/pwb/seeder_spec.rb`

### Key Test Cases to Add

```ruby
RSpec.describe 'Seeder property normalization' do
  let(:website) { create(:pwb_website, subdomain: 'seed-test') }
  
  describe 'creating normalized property records' do
    it 'creates RealtyAsset + SaleListing with translations' do
      prop_data = {
        'reference' => 'TEST-001',
        'city' => 'Barcelona',
        'title' => 'Beautiful Villa',
        'title_es' => 'Villa Hermosa',
        'description' => 'Amazing property',
        'description_es' => 'Propiedad increíble',
        'for_sale' => true,
        'price_sale_current_cents' => 500_000_00,
        'currency' => 'EUR'
      }
      
      asset = Pwb::Seeder.send(:create_normalized_property_records, prop_data)
      
      expect(asset).to be_persisted
      expect(asset.reference).to eq('TEST-001')
      expect(asset.sale_listings.count).to eq(1)
      
      listing = asset.sale_listings.first
      expect(listing.title_en).to eq('Beautiful Villa')
      expect(listing.title_es).to eq('Villa Hermosa')
    end
    
    # Add 14 more tests:
    # - RentalListing creation with for_rent_long_term + for_rent_short_term
    # - Both SaleListing AND RentalListing for same asset
    # - Photos attached to asset post-creation
    # - Materialized view refresh triggered
    # - Graceful error handling if RealtyAsset creation fails
    # - Duplicate reference handling (skip if exists)
    # - Locale filtering (future language keys removed)
    # - Nil/empty field handling
    # - Price currency consistency
    # - Listing visibility/archival flags
  end
  
  describe 'photo handling' do
    it 'handles external URLs in test environment' do
      # In test, photos should NOT be created, skip gracefully
      # Verify Rails.env.test? check prevents HTTP requests
    end
    
    it 'handles photo attachment failures gracefully' do
      # Photo creation fails; property creation should continue
      # or rollback cleanly (no orphaned photos)
    end
  end
  
  describe 'locale filtering' do
    it 'removes unsupported locale attributes' do
      # Input: title_en, title_es, title_ja (ja not in available_locales)
      # Output: only title_en and title_es set
      
      filtered = Pwb::Seeder.send(:filter_supported_locale_attrs, {
        name: 'Test',
        title_en: 'English',
        title_es: 'Spanish',
        title_ja: 'Japanese'
      })
      
      expect(filtered).to have_key(:name)
      expect(filtered).to have_key(:title_en)
      expect(filtered).not_to have_key(:title_ja)
    end
  end
end
```

**Test Count:** 15 (covers property normalization, photos, locale handling)

---

## 3. SiteAdminIndexable Cross-Tenant Tests - Template: 10 tests

**File:** `spec/controllers/concerns/site_admin_indexable_spec.rb` (add to existing)

### Key Test Cases to Add

```ruby
RSpec.describe 'SiteAdminIndexable cross-tenant isolation', type: :request do
  let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a') }
  let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b') }
  
  let!(:admin_a) { create(:pwb_user, :admin, email: 'admin-a@test.local', website: website_a) }
  let!(:contact_a1) { create(:pwb_contact, website: website_a, primary_email: 'contact-a1@test.local') }
  let!(:contact_a2) { create(:pwb_contact, website: website_a, primary_email: 'contact-a2@test.local') }
  let!(:contact_b1) { create(:pwb_contact, website: website_b, primary_email: 'contact-b1@test.local') }
  
  describe 'index isolation' do
    it 'tenant A cannot see tenant B contacts' do
      sign_in admin_a
      Pwb::Current.website = website_a
      
      get site_admin_contacts_path(host: 'tenant-a.e2e.localhost')
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('contact-a1@test.local')
      expect(response.body).to include('contact-a2@test.local')
      expect(response.body).not_to include('contact-b1@test.local')
    end
    
    # Add 9 more tests:
    # - Search within tenant scope (search=contact shows only this tenant's)
    # - Limit parameter respects scope
    # - Order parameter respects scope
    # - Includes/join queries don't leak data
    # - Pagination across multiple tenants
    # - Empty result set for other tenant
  end
  
  describe 'show isolation' do
    it 'cannot access contact from different tenant' do
      sign_in admin_a
      Pwb::Current.website = website_a
      
      expect {
        get site_admin_contact_path(contact_b1, host: 'tenant-a.e2e.localhost')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

**Test Count:** 10 (covers index, search, show isolation across tenants)

---

## 4. ListingStateable Edge Cases - Template: 8 tests

**File:** Add to `spec/models/pwb/sale_listing_spec.rb` and `rental_listing_spec.rb`

### Key Test Cases to Add

```ruby
RSpec.describe 'ListingStateable edge cases' do
  let(:website) { create(:pwb_website) }
  let(:asset) { create(:pwb_realty_asset, website: website) }
  
  describe 'activate! with concurrent requests' do
    it 'handles transaction safely when two listings activate simultaneously' do
      listing1 = create(:pwb_sale_listing, realty_asset: asset, active: true)
      listing2 = create(:pwb_sale_listing, realty_asset: asset, active: false)
      
      # Simulate near-concurrent activations
      allow(listing2).to receive(:update!).and_call_original
      listing2.activate!
      
      listing1.reload
      listing2.reload
      
      expect(listing1.active?).to be false
      expect(listing2.active?).to be true
    end
  end
  
  describe 'validation ordering with active? callbacks' do
    it 'validates before deactivating other listings' do
      listing1 = create(:pwb_sale_listing, realty_asset: asset, active: true)
      listing2 = create(:pwb_sale_listing, realty_asset: asset, active: false)
      
      # Direct assignment should trigger validation
      listing2.active = true
      expect(listing2.valid?).to be false
      expect(listing2.errors[:active]).to be_present
    end
  end
  
  describe 'archive and unarchive state' do
    it 'prevents archiving active listing via validation' do
      listing = create(:pwb_sale_listing, realty_asset: asset, active: true)
      
      expect { listing.archive! }.to raise_error(ActiveRecord::RecordInvalid)
    end
    
    it 'unarchives listing correctly' do
      listing = create(:pwb_sale_listing, realty_asset: asset, archived: true, active: false)
      
      listing.unarchive!
      
      expect(listing.reload.archived?).to be false
    end
  end
  
  describe 'materialized view refresh' do
    it 'handles view refresh failure gracefully' do
      allow(Pwb::ListedProperty).to receive(:refresh).and_raise(StandardError.new('DB error'))
      
      listing = create(:pwb_rental_listing, realty_asset: asset)
      # Should not raise, error should be logged
      
      expect(listing).to be_persisted
    end
  end
  
  describe 'scope chaining' do
    it 'chains .active_listing.visible.not_archived correctly' do
      l1 = create(:pwb_rental_listing, realty_asset: asset, active: true, visible: true, archived: false)
      l2 = create(:pwb_rental_listing, realty_asset: create(:pwb_realty_asset, website: website), 
                                       active: true, visible: false, archived: false)
      l3 = create(:pwb_rental_listing, realty_asset: create(:pwb_realty_asset, website: website),
                                       active: true, visible: true, archived: true)
      
      results = Pwb::RentalListing.active_listing.visible.not_archived
      
      expect(results).to include(l1)
      expect(results).not_to include(l2, l3)
    end
  end
end
```

**Test Count:** 8 (covers concurrency, validation, state transitions, view refresh, scopes)

---

## 5. MLS Connector Tests - Template: 15 tests

**File:** `spec/services/pwb/mls_connector_spec.rb`

### Key Test Cases to Add

```ruby
RSpec.describe Pwb::MlsConnector do
  let(:rets_source) do
    Pwb::ImportSource.where(unique_name: 'mris').first ||
    Pwb::ImportSource.new(
      source_type: 'rets',
      unique_name: 'test_rets',
      details: {
        login_url: 'http://test.rets.local/login',
        username: 'testuser',
        password: 'testpass'
      }
    )
  end
  
  describe 'retrieve with RETS source' do
    it 'initializes RETS client correctly' do
      allow(Rets::Client).to receive(:new).and_return(double(:client))
      
      connector = described_class.new(rets_source)
      expect { connector.retrieve('(Status=Active)', 10) }.not_to raise_error
    end
    
    # Add 14 more tests:
    # - Query with various DMQL syntaxes
    # - Limit parameter passed correctly
    # - Response parsing (Property objects returned)
    # - Photo retrieval (commented code)
    # - Error handling: Auth failures
    # - Error handling: Timeout
    # - Error handling: Malformed response
    # - Unsupported source type (non-RETS)
    # - Multiple connector instances
    # - Query caching (if implemented)
  end
end
```

**Test Count:** 15 (covers initialization, queries, error handling, response parsing)

---

## 6. Cross-Tenant Isolation Negative Tests - Template: 10 tests

**File:** `spec/integration/cross_tenant_isolation_spec.rb` (new file)

### Key Test Cases

```ruby
RSpec.describe 'Cross-tenant isolation', type: :integration do
  let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a') }
  let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b') }
  
  let!(:user_a) { create(:pwb_user, email: 'user-a@test.local', website: website_a) }
  let!(:user_b) { create(:pwb_user, email: 'user-b@test.local', website: website_b) }
  
  describe 'property queries' do
    before do
      @prop_a = create(:pwb_realty_asset, website: website_a, reference: 'PROP-A')
      @prop_b = create(:pwb_realty_asset, website: website_b, reference: 'PROP-B')
    end
    
    it 'tenant A cannot query properties from tenant B' do
      Pwb::Current.website = website_a
      
      # Direct query should not find B's property
      result = website_a.realty_assets.find_by(reference: 'PROP-B')
      expect(result).to be_nil
    end
    
    # Add 9 more:
    # - API endpoint for properties scoped correctly
    # - Search results don't leak between tenants
    # - Listing visibility filters don't leak
  end
end
```

**Test Count:** 10 (covers negative test cases for data isolation)

---

## 7. Models Without Tests - Template: 5 tests each

### EmailTemplate (`spec/models/pwb/email_template_spec.rb`)
- Validates template_key present
- Validates website association
- Validates subject/body_html/body_text present
- find_for_website scope works
- Templates can be customized per website

### ImportSource (`spec/models/pwb/import_source_spec.rb`)
- Validates source_type presence
- Validates details JSON structure
- RETS source has required fields
- default_property_class used correctly

### SubscriptionEvent (`spec/models/pwb/subscription_event_spec.rb`)
- Associates with subscription
- event_type validations
- payload JSONB handling
- Timestamps recorded

**Total Tests to Add:** 50 (5 tests × 10 untested models)

---

## Implementation Priority & Effort

| Task | Priority | Effort | Impact |
|------|----------|--------|--------|
| EmailTemplateRenderer | Critical | 3-4h | High (customer emails) |
| Seeding edge cases | Critical | 4-5h | High (recent feature) |
| SiteAdminIndexable isolation | High | 2-3h | Medium (data security) |
| MlsConnector | High | 3-4h | Medium (import feature) |
| ListingStateable edges | High | 2-3h | Medium (state safety) |
| Model test files (5 each) | Medium | 4-6h | Low (domain coverage) |
| Negative isolation tests | Medium | 2-3h | High (security) |
| **TOTAL** | | **21-28h** | |

---

## Running Tests During Implementation

```bash
# Run newly added tests only
bundle exec rspec spec/services/pwb/email_template_renderer_spec.rb

# Run full suite (should be quick with :unit tag)
bundle exec rspec --tag :unit

# Run integration tests only (slower)
bundle exec rspec --tag :integration

# Check coverage for specific file
bundle exec rspec spec/models/pwb/email_template_spec.rb --format=RspecJunitFormatter

# Watch mode (if guard installed)
guard -i
```

---

## Tips for Writing Tests in This Codebase

### Multi-Tenancy Pattern
```ruby
let!(:website) { create(:pwb_website) }
let!(:user) { create(:pwb_user, website: website) }

before do
  ActsAsTenant.current_tenant = website
  Pwb::Current.website = website
end

after do
  ActsAsTenant.current_tenant = nil
end
```

### Mocking External Services
```ruby
# For email rendering
allow_any_instance_of(Liquid::Template)
  .to receive(:render)
  .and_return('rendered_html')

# For RETS/MLS client
allow(Rets::Client).to receive(:new).and_return(double(find: [property_data]))
```

### Testing Materialized View Refresh
```ruby
allow(Pwb::ListedProperty).to receive(:refresh)

# Do action that should trigger refresh
create(:pwb_rental_listing, realty_asset: asset)

# Verify refresh was called
expect(Pwb::ListedProperty).to have_received(:refresh)
```

### Testing Nested Translations (Mobility)
```ruby
listing = create(:pwb_sale_listing)
listing.title_en = 'English Title'
listing.title_es = 'Título Español'
listing.save!

I18n.with_locale(:es) { expect(listing.title).to eq('Título Español') }
```

---

## Resources

- **RSpec syntax:** https://relishapp.com/rspec
- **Factory Bot:** https://github.com/thoughtbot/factory_bot
- **VCR (HTTP recording):** https://github.com/vcr/vcr
- **Mobility (translations):** https://github.com/shioyama/mobility
- **MoneyRails:** https://github.com/spree/monetize

---

**Next Steps:**
1. Pick one module above (recommend EmailTemplateRenderer or Seeding)
2. Copy test template provided
3. Run tests as you implement
4. Cross-reference spec/factories for data patterns
5. Create PR with tests + implementation notes

