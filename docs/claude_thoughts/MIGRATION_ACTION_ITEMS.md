# Migration Action Items: Pwb::Prop to RealtyAsset/Listings

**Priority**: HIGH  
**Effort Estimate**: 16-24 hours  
**Complexity**: MEDIUM  

---

## Phase 1: Low-Risk Changes (2-3 hours)

### Task 1.1: Fix Tenant Admin Statistics

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/websites_controller.rb`

**Current (Line 30)**:
```ruby
@props_count = Pwb::Prop.unscoped.where(website_id: @website.id).count rescue 0
```

**Update To**:
```ruby
@props_count = Pwb::RealtyAsset.where(website_id: @website.id).count rescue 0
```

**Testing**:
```bash
# Check tenant admin website page displays count
bin/rspec spec/controllers/tenant_admin/websites_controller_spec.rb -v
```

**Why**: RealtyAsset is the source of truth for properties, not Pwb::Prop

---

### Task 1.2: Fix Website Index View

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/views/tenant_admin/websites/index.html.erb`

**Current (Line 60)**:
```erb
<% props_count = Pwb::Prop.unscoped.where(pwb_website_id: website.id).count rescue 0 %>
```

**Update To**:
```erb
<% props_count = Pwb::RealtyAsset.where(website_id: website.id).count rescue 0 %>
```

**Note**: Also check the column name - might be `website_id` not `pwb_website_id`

**Testing**:
```bash
# Navigate to tenant admin websites index page
# Verify property counts are correct
```

---

### Task 1.3: Fix Tenant Admin Search

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/props_controller.rb`

**Current (Lines 7-14)**:
```ruby
def index
  @props = Pwb::RealtyAsset.includes(:website).order(created_at: :desc).limit(100)
  
  # Search by reference or title
  if params[:search].present?
    @props = @props.where(
      "reference ILIKE ? OR title ILIKE ?",
      "%#{params[:search]}%",
      "%#{params[:search]}%"
    )
  end
```

**Problem**: `title` is not a RealtyAsset field - it's on SaleListing/RentalListing

**Update To**:
```ruby
def index
  @props = Pwb::RealtyAsset.includes(:website).order(created_at: :desc).limit(100)
  
  # Search by reference, street address, city, or region
  if params[:search].present?
    search_term = "%#{params[:search]}%"
    @props = @props.where(
      "reference ILIKE ? OR street_address ILIKE ? OR city ILIKE ? OR region ILIKE ?",
      search_term,
      search_term,
      search_term,
      search_term
    )
  end
  
  # Filter by website
  if params[:website_id].present?
    @props = @props.where(website_id: params[:website_id])
  end
end
```

**Testing**:
```bash
bin/rspec spec/controllers/tenant_admin/props_controller_spec.rb -v
# Test search by reference
# Test search by location (city/region/address)
```

---

### Task 1.4: Fix Image Controller Photo Joins

**Files**:
1. `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/editor/images_controller.rb` (Line 53)
2. `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/images_controller.rb` (Line 52)

**Current Pattern**:
```ruby
prop_photos = Pwb::PropPhoto.joins(:prop)
```

**Update To**:
```ruby
prop_photos = Pwb::PropPhoto.joins(:realty_asset)
```

**OR** Support both (better for backwards compatibility):
```ruby
prop_photos = Pwb::PropPhoto.where.not(realty_asset_id: nil).order(:sort_order)
# or for legacy:
prop_photos_legacy = Pwb::PropPhoto.where.not(prop_id: nil).order(:sort_order)
```

**Testing**:
```bash
bin/rspec spec/controllers/pwb/editor/images_controller_spec.rb -v
bin/rspec spec/controllers/site_admin/images_controller_spec.rb -v
# Upload image and verify it's associated correctly
```

**Context**: The full implementation depends on how these controllers are used

---

## Phase 2: Medium-Risk Changes (2-4 hours)

### Task 2.1: Investigate api_ext Endpoint Usage

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/api_ext/v1/props_controller.rb`

**Current Status**: Routes are commented out in config/routes.rb

**Actions**:
1. Check if this endpoint is still referenced anywhere
2. Search for clients using this API
3. Check commit history for when it was deprecated

```bash
# Search for references to this endpoint
grep -r "api_ext/v1/props" /Users/etewiah/dev/sites-older/property_web_builder/ --exclude-dir=.git

# Check git history
git log --all --oneline | grep -i "api_ext\|props.*api"
```

**Decision Tree**:
- **If NOT used**: Remove or mark as deprecated
- **If used**: Requires full migration (Phase 3)

---

## Phase 3: High-Risk Changes (8-12 hours)

### Task 3.1: Migrate Internal Properties API

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/api/v1/properties_controller.rb`

**Lines Requiring Updates**: 28-96 (write operations)

#### 3.1.1: bulk_create Action

**Current (Lines 28-54)**:
```ruby
def bulk_create
  propertiesJSON = params["propertiesJSON"]
  unless propertiesJSON.is_a? Array
    propertiesJSON = JSON.parse propertiesJSON
  end
  new_props = []
  existing_props = []
  errors = []
  properties_params(propertiesJSON).each_with_index do |property_params, index|
    propertyJSON = propertiesJSON[index]
    if Pwb::Current.website.props.where(reference: propertyJSON["reference"]).exists?
      existing_props.push Pwb::Current.website.props.find_by_reference propertyJSON["reference"]
    else
      begin
        new_prop = Pwb::Current.website.props.create(property_params)

        if propertyJSON["currency"]
          new_prop.currency = propertyJSON["currency"]
          new_prop.save!
        end
        if propertyJSON["area_unit"]
          new_prop.area_unit = propertyJSON["area_unit"]
          new_prop.save!
        end

        if propertyJSON["property_photos"]
          max_photos_to_process = 20
          propertyJSON["property_photos"].each_with_index do |property_photo, photo_index|
            if photo_index > max_photos_to_process
              break
            end
            photo = PropPhoto.create
            photo.sort_order = property_photo["sort_order"] || nil
            photo.remote_image_url = property_photo["url"]
            photo.save!
            new_prop.prop_photos.push photo
          end
        end

        new_props.push new_prop
      rescue => err
        errors.push err.message
      end
    end
  end

  render json: {
    new_props: new_props,
    existing_props: existing_props,
    errors: errors
  }
end
```

**Refactor To**:
```ruby
def bulk_create
  propertiesJSON = params["propertiesJSON"]
  unless propertiesJSON.is_a? Array
    propertiesJSON = JSON.parse propertiesJSON
  end
  
  new_props = []
  existing_props = []
  errors = []
  
  ActiveRecord::Base.transaction do
    properties_params(propertiesJSON).each_with_index do |property_params, index|
      propertyJSON = propertiesJSON[index]
      reference = propertyJSON["reference"]
      
      # Check if property already exists
      existing_asset = Pwb::Current.website.realty_assets.find_by(reference: reference)
      if existing_asset
        existing_props.push(serialize_property_for_response(existing_asset))
        next
      end
      
      begin
        # Create RealtyAsset (physical property)
        realty_asset = Pwb::Current.website.realty_assets.create!(
          reference: reference,
          street_address: property_params[:street_address],
          city: property_params[:city],
          postal_code: property_params[:postal_code],
          count_bedrooms: property_params[:count_bedrooms],
          count_bathrooms: property_params[:count_bathrooms],
          # ... other asset fields
        )
        
        # Determine if property is for sale, rent, or both
        if property_params[:for_rent_short_term]
          create_rental_listing(realty_asset, property_params, propertyJSON)
        end
        
        if property_params[:for_sale]
          create_sale_listing(realty_asset, property_params, propertyJSON)
        end
        
        # Handle photos
        if propertyJSON["property_photos"]
          attach_photos_to_asset(realty_asset, propertyJSON["property_photos"])
        end
        
        new_props.push(serialize_property_for_response(realty_asset))
      rescue => err
        errors.push "Property #{reference}: #{err.message}"
      end
    end
  end
  
  # Refresh materialized view after all properties created
  Pwb::ListedProperty.refresh
  
  render json: {
    new_props: new_props,
    existing_props: existing_props,
    errors: errors
  }
end

private

def create_sale_listing(realty_asset, property_params, propertyJSON)
  realty_asset.sale_listings.create!(
    visible: property_params[:visible] || false,
    price_sale_current_cents: property_params[:price_sale_current_cents],
    price_sale_current_currency: propertyJSON["currency"] || "USD",
    title_en: property_params[:title],
    description_en: property_params[:description]
  )
end

def create_rental_listing(realty_asset, property_params, propertyJSON)
  realty_asset.rental_listings.create!(
    visible: property_params[:visible] || false,
    for_rent_short_term: true,
    price_rental_monthly_current_cents: property_params[:price_rental_monthly_current_cents],
    price_rental_monthly_current_currency: propertyJSON["currency"] || "USD",
    title_en: property_params[:title],
    description_en: property_params[:description]
  )
end

def attach_photos_to_asset(realty_asset, property_photos)
  max_photos = 20
  property_photos.first(max_photos).each_with_index do |photo_data, index|
    photo = Pwb::PropPhoto.create!(
      realty_asset_id: realty_asset.id,
      sort_order: photo_data["sort_order"] || index + 1
    )
    photo.remote_image_url = photo_data["url"]
    photo.save!
  end
end

def serialize_property_for_response(realty_asset)
  # Return representation compatible with existing API clients
  {
    id: realty_asset.id,
    reference: realty_asset.reference,
    # ... other fields
  }
end
```

**Testing**:
```bash
bin/rspec spec/controllers/pwb/api/v1/properties_controller_spec.rb -v
bin/rspec spec/requests/pwb/api/v1/properties_spec.rb -v

# Test scenarios:
# 1. Create single property (rental)
# 2. Create single property (sale)
# 3. Create multiple properties
# 4. Update existing property (via reference)
# 5. Handle duplicate references
# 6. Photo attachment during creation
```

---

#### 3.1.2: update_extras Action

**Current (Lines 65-68)**:
```ruby
def update_extras
  property = Pwb::Current.website.props.find(params[:id])
  property.set_features = params[:extras].to_unsafe_hash
  property.save!
  render json: property.features
end
```

**Update To**:
```ruby
def update_extras
  realty_asset = Pwb::Current.website.realty_assets.find(params[:id])
  
  features_hash = params[:extras].to_unsafe_hash
  features_hash.each do |feature_key, enabled|
    if enabled == "true" || enabled == true
      realty_asset.features.find_or_create_by(feature_key: feature_key)
    else
      realty_asset.features.where(feature_key: feature_key).delete_all
    end
  end
  
  # Refresh materialized view
  Pwb::ListedProperty.refresh
  
  render json: realty_asset.features.pluck(:feature_key)
end
```

---

#### 3.1.3: Photo Management Actions

**Current Photo Actions**:
- `order_photos` (Lines 74-82)
- `add_photo_from_url` (Lines 84-97)
- `add_photo` (Lines 99-116)
- `remove_photo` (Lines 118-121)

**All need similar refactoring**:
- Find `RealtyAsset` instead of `Prop`
- Attach photos to `RealtyAsset`
- Refresh materialized view after changes

**Example - add_photo**:
```ruby
def add_photo
  realty_asset = Pwb::Current.website.realty_assets.find(params[:id])
  files_array = params[:file]
  
  if files_array.class.to_s == "ActionDispatch::Http::UploadedFile"
    files_array = [files_array]
  end
  
  photos_array = []
  max_sort_order = realty_asset.prop_photos.maximum(:sort_order) || 0
  
  files_array.each_with_index do |file, index|
    photo = Pwb::PropPhoto.create!(
      realty_asset_id: realty_asset.id,
      sort_order: max_sort_order + index + 1
    )
    photo.image.attach(file)
    photo.save!
    photos_array.push photo
  end
  
  # Refresh materialized view
  Pwb::ListedProperty.refresh
  
  render json: photos_array.to_json
end
```

---

### Task 3.2: Update API Response Serialization

**Current Issues**:
- API returns `Pwb::Prop` JSON representation
- Client code expects specific fields
- Backwards compatibility needed

**Action**:
1. Create migration for response format
2. Support both old and new response formats during transition
3. Update documentation

```ruby
# In api/v1/properties_controller.rb

def serialize_property(property)
  # property is now Pwb::ListedProperty (read-only view)
  # Already compatible with old API format
  {
    data: {
      id: property.id.to_s,
      type: "properties",
      attributes: {
        # ... existing attributes (already mapped in ListedProperty)
      }
    }
  }
end
```

---

## Phase 4: Testing & Validation (3-4 hours)

### Task 4.1: Create Migration Test Suite

**Create**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/migrations/prop_to_realty_asset_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Prop to RealtyAsset Migration", type: :model do
  describe "API bulk_create" do
    let(:website) { create(:pwb_website) }
    let(:properties_json) do
      [
        {
          reference: "TEST-001",
          title: "Test Property 1",
          description: "A test property",
          street_address: "123 Main St",
          city: "Boston",
          postal_code: "02101",
          count_bedrooms: 3,
          count_bathrooms: 2,
          for_rent_short_term: true,
          visible: true,
          currency: "USD",
          price_rental_monthly_current: 2000,
          property_photos: [
            { url: "https://example.com/photo1.jpg", sort_order: 1 }
          ]
        }
      ]
    end
    
    it "creates realty asset with rental listing" do
      Pwb::Current.website = website
      
      expect {
        post '/api/v1/properties/bulk_create',
             params: { propertiesJSON: properties_json }
      }.to change { Pwb::RealtyAsset.count }.by(1)
             .and change { Pwb::RentalListing.count }.by(1)
      
      asset = website.realty_assets.first
      expect(asset.reference).to eq("TEST-001")
      expect(asset.rental_listings.count).to eq(1)
    end
    
    it "skips duplicate references" do
      Pwb::Current.website = website
      
      # Create first
      post '/api/v1/properties/bulk_create',
           params: { propertiesJSON: properties_json }
      
      # Try to create duplicate
      response = post '/api/v1/properties/bulk_create',
                      params: { propertiesJSON: properties_json }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['existing_props'].count).to eq(1)
      expect(json['new_props'].count).to eq(0)
    end
  end
  
  describe "API photo operations" do
    let(:website) { create(:pwb_website) }
    let(:realty_asset) { create(:pwb_realty_asset, website: website) }
    
    it "adds photos to realty asset" do
      Pwb::Current.website = website
      
      file = fixture_file_upload('test_image.jpg')
      expect {
        post "/api/v1/properties/#{realty_asset.id}/add_photo",
             params: { file: file }
      }.to change { realty_asset.prop_photos.count }.by(1)
    end
  end
  
  describe "Data consistency after migration" do
    it "all realty assets have proper listings" do
      # Verify migration completed successfully
      Pwb::RealtyAsset.find_each do |asset|
        has_sale = asset.sale_listings.any?
        has_rental = asset.rental_listings.any?
        
        expect(has_sale || has_rental)
          .to be_true, "Asset #{asset.id} has no listings"
      end
    end
    
    it "all photos are linked to realty assets" do
      orphaned = Pwb::PropPhoto.where(realty_asset_id: nil)
      expect(orphaned.count).to eq(0), 
        "Found #{orphaned.count} orphaned photos"
    end
  end
end
```

---

### Task 4.2: Test Old vs. New API Format

Create `/spec/requests/api/v1/backward_compatibility_spec.rb`:

```ruby
RSpec.describe "API Backwards Compatibility", type: :request do
  let(:website) { create(:pwb_website) }
  
  describe "GET /api/v1/properties/:id" do
    it "returns same fields regardless of old/new model" do
      # Create via old API
      old_prop = create(:pwb_prop, website: website)
      
      # Create via new API
      asset = create(:pwb_realty_asset, website: website)
      listing = create(:pwb_rental_listing, realty_asset: asset)
      
      # Both should return same fields
      get "/api/v1/properties/#{old_prop.id}"
      old_response = JSON.parse(response.body)
      
      get "/api/v1/properties/#{asset.id}"
      new_response = JSON.parse(response.body)
      
      expect(old_response['data']['attributes'].keys)
        .to match_array(new_response['data']['attributes'].keys)
    end
  end
end
```

---

### Task 4.3: Regression Testing

```bash
# Before any changes:
bin/rspec spec/

# After Phase 1 changes:
bin/rspec spec/ -t "not migration"

# After Phase 2 changes:
bin/rspec spec/controllers/site_admin/
bin/rspec spec/controllers/tenant_admin/

# After Phase 3 changes:
bin/rspec spec/requests/pwb/api/
bin/rspec spec/controllers/pwb/api/v1/

# Run specific test suite
bin/rspec spec/models/pwb/deprecated_props_usage_spec.rb -v
```

---

## Phase 5: Deployment & Monitoring (2 hours)

### Task 5.1: Pre-Deployment Checklist

- [ ] All Phase 1 tests passing
- [ ] All Phase 2 tests passing
- [ ] All Phase 3 tests passing
- [ ] No new deprecation warnings
- [ ] Updated API documentation
- [ ] Client notification (if external APIs affected)
- [ ] Database backup created

### Task 5.2: Post-Deployment Monitoring

Create `/lib/migration_monitor.rb`:

```ruby
class MigrationMonitor
  # Track any Prop.create calls in production
  def self.log_prop_usage
    if Rails.env.production?
      # Log all Pwb::Prop.create calls
      # Alert if used more than threshold
    end
  end
  
  # Monitor API response times
  def self.check_api_performance
    # Compare bulk_create response times
    # Alert if degradation > 10%
  end
end
```

---

## Task Summary Table

| Phase | Task | File | Effort | Risk | Priority |
|-------|------|------|--------|------|----------|
| 1 | Fix Statistics | websites_controller.rb | 5m | VERY LOW | HIGH |
| 1 | Fix View Count | websites/index.html.erb | 5m | VERY LOW | HIGH |
| 1 | Fix Search | props_controller.rb (tenant) | 10m | LOW | HIGH |
| 1 | Fix Photo Joins | editor/images_controller.rb | 15m | LOW | MEDIUM |
| 2 | Investigate api_ext | Check usage | 30m | MEDIUM | MEDIUM |
| 3 | Migrate bulk_create | api/v1/properties.rb | 3h | HIGH | HIGH |
| 3 | Migrate update_extras | api/v1/properties.rb | 1h | HIGH | HIGH |
| 3 | Migrate photo actions | api/v1/properties.rb | 2h | HIGH | HIGH |
| 3 | Update serialization | api/v1/properties.rb | 1h | HIGH | HIGH |
| 4 | Create test suite | migration test | 2h | NONE | HIGH |
| 4 | Test backwards compat | api spec | 1h | NONE | HIGH |
| 5 | Deploy & monitor | monitoring | 2h | NONE | MEDIUM |

**Total Estimated Effort**: 16-24 hours

---

## Risk Mitigation

### High-Risk Areas
1. **API Changes** → Create comprehensive test suite FIRST
2. **Photo Management** → Test all file types and sizes
3. **Feature Updates** → Verify relationship management
4. **External Clients** → Create fallback API endpoint during transition

### Rollback Plan
```bash
# If critical issues after Phase 3:
git revert <commit-hash>
# Restore from pre-deployment backup
# Notify API clients of temporary unavailability
```

---

## Success Criteria

- [ ] All existing tests passing
- [ ] Zero deprecation warnings for new code
- [ ] API response times within 10% of baseline
- [ ] No data loss or inconsistency
- [ ] External API clients unaffected (or migrated)
- [ ] Phase 1-2 deployed within 1 week
- [ ] Phase 3 deployed within 2 weeks
- [ ] All legacy Pwb::Prop writes eliminated

