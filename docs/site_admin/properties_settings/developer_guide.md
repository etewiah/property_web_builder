# Properties Settings - Developer Documentation

Technical reference for the Properties Settings feature implementation in PropertyWebBuilder.

## Architecture Overview

The Properties Settings feature follows a standard Rails MVC pattern with tenant scoping:

```
┌─────────────────────────────────────────────────────────┐
│                     User (Browser)                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              SettingsController                          │
│  (site_admin/properties/settings_controller.rb)         │
│  - index, show, create, update, destroy                  │
│  - Tenant scoped via SubdomainTenant concern             │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                  FieldKey Model                          │
│  (app/models/pwb/field_key.rb)                          │
│  - belongs_to :website                                   │
│  - Scopes: visible, for_website, by_tag                  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Database (PostgreSQL)                       │
│  Table: pwb_field_keys                                   │
└─────────────────────────────────────────────────────────┘
```

## Database Schema

### Table: `pwb_field_keys`

```ruby
create_table "pwb_field_keys", primary_key: "global_key", force: :cascade do |t|
  t.string   "tag"                           # Category identifier
  t.boolean  "visible"                       # Show in dropdowns
  t.integer  "props_count", default: 0      # Counter cache
  t.boolean  "show_in_search_form"          # Include in search
  t.datetime "created_at"
  t.datetime "updated_at"
  t.bigint   "pwb_website_id"               # Tenant association
  t.integer  "sort_order", default: 0       # Display order
  
  t.index ["pwb_website_id"], name: "index_pwb_field_keys_on_pwb_website_id"
  t.index ["pwb_website_id", "tag"], name: "index_field_keys_on_website_and_tag"
  t.foreign_key "pwb_websites", column: "pwb_website_id"
end
```

### Tag Values

| Tag | Description | Example Keys |
|-----|-------------|--------------|
| `property-types` | Property categories | `prop_type.apartment` |
| `extras` | Property features/amenities | `extras.pool` |
| `property-states` | Property conditions | `prop_state.new` |
| `property-labels` | Special tags/badges | `prop_label.featured` |

### Global Key Format

Pattern: `{tag}.{parameterized_name}_{timestamp}`

Example: `property-types.warehouse_1733324552`

## API Endpoints

### Routes

```ruby
namespace :site_admin do
  namespace :properties do
    get    'settings'                    => 'settings#index'
    get    'settings/:category'          => 'settings#show'
    post   'settings/:category'          => 'settings#create'
    patch  'settings/:category/:id'      => 'settings#update'
    delete 'settings/:category/:id'      => 'settings#destroy'
  end
end
```

### Endpoint Details

#### GET /site_admin/properties/settings

**Purpose**: Landing page with tab navigation

**Response**: HTML page with category tabs

#### GET /site_admin/properties/settings/:category

**Purpose**: Show all field keys for a category

**Parameters**:
- `category` (string): One of `property_types`, `features`, `property_states`, `property_labels`

**Response**: HTML table with existing entries

**Example**:
```
GET /site_admin/properties/settings/property_types
```

#### POST /site_admin/properties/settings/:category

**Purpose**: Create a new field key

**Parameters**:
```ruby
{
  category: 'property_types',
  field_key: {
    translations: {
      en: 'Warehouse',
      es: 'Almacén',
      fr: 'Entrepôt'
    },
    visible: true,
    sort_order: 10
  }
}
```

**Response**: Redirect to show page with flash notice

**Side Effects**:
- Creates `FieldKey` record
- Generates unique `global_key`
- Stores I18n translations
- Associates with current website

#### PATCH /site_admin/properties/settings/:category/:id

**Purpose**: Update an existing field key

**Parameters**:
```ruby
{
  category: 'property_types',
  id: 'property-types.warehouse_1733324552',
  field_key: {
    translations: { en: 'Updated Name' },
    visible: false,
    sort_order: 5
  }
}
```

**Response**: Redirect to show page

#### DELETE /site_admin/properties/settings/:category/:id

**Purpose**: Delete a field key

**Parameters**:
- `category`: Category name
- `id`: `global_key` of field key to delete

**Response**: Redirect to show page

**Validation**: Checks field key belongs to current website

## Controller Methods

### SiteAdmin::Properties::SettingsController

```ruby
class SettingsController < ::SiteAdminController
  before_action :set_category
  before_action :set_field_key, only: [:update, :destroy]
  
  VALID_CATEGORIES = {
    'property_types' => 'property-types',
    'features' => 'extras',
    'property_states' => 'property-states',
    'property_labels' => 'property-labels'
  }.freeze
  
  private
  
  def category_tag
    VALID_CATEGORIES[@category]
  end
  
  def generate_global_key
    base_name = params[:field_key][:translations].values.first.parameterize
    "#{category_tag}.#{base_name}_#{Time.current.to_i}"
  end
  
  def save_translations(field_key, translations_hash)
    translations_hash.each do |locale, text|
      I18n.backend.store_translations(
        locale.to_sym,
        { field_key.global_key => text }
      )
    end
  end
end
```

## Model Methods

### Pwb::FieldKey

```ruby
# Associations
belongs_to :website, optional: true, foreign_key: :pwb_website_id

# Scopes
scope :visible, -> { where visible: true }
scope :for_website, ->(website_id) { where(pwb_website_id: website_id) }
scope :by_tag, ->(tag) { where(tag: tag) }

# Class Methods
def self.get_options_by_tag(tag)
  # Returns array of OpenStruct with :value and :label
  # Sorted alphabetically by translated label
end

# Validations
validates :global_key, presence: true, uniqueness: { scope: :pwb_website_id }
validates :tag, presence: true
```

## Frontend Components

### Views

**Directory**: `app/views/site_admin/properties/settings/`

1. **index.html.erb** - Landing page with tabs
2. **show.html.erb** - Data table for category
3. **_form.html.erb** - Create/edit form partial
4. **_tab_navigation.html.erb** - Category tabs

### JavaScript

**Inline Functions** (in show.html.erb):

```javascript
function toggleEditForm(id) {
  // Hides all edit forms
  // Shows/hides the specified edit form
}
```

**Future Enhancement**: Extract to Stimulus controllers for better organization.

### Styling

Uses **Tailwind CSS** utility classes:

- Tables: `min-w-full divide-y divide-gray-200`
- Forms: `space-y-4 grid grid-cols-*`
- Buttons: `px-4 py-2 bg-blue-600 text-white rounded-lg`
- Tabs: `border-b-2 border-blue-500` (active)

## Internationalization (I18n)

### Storage

Translations are stored via `I18n.backend.store_translations`:

```ruby
I18n.backend.store_translations(
  :en,
  { 'property-types.warehouse_1733324552' => 'Warehouse' }
)
```

### Retrieval

```ruby
I18n.t('property-types.warehouse_1733324552', locale: :en)
# => "Warehouse"
```

### Best Practices

1. **Persistent Backend**: For production, use `i18n-active_record` gem for database-backed translations
2. **Fallbacks**: Always provide English translation as fallback
3. **Cache**: Consider caching frequently-accessed translations

## Tenant Scoping

### SubdomainTenant Concern

```ruby
module SubdomainTenant
  included do
    before_action :set_current_website_from_subdomain
  end
  
  def current_website
    Pwb::Current.website
  end
end
```

### How It Works

1. User visits `http://site-a.localhost:3000/site_admin/properties/settings`
2. `SubdomainTenant` extracts subdomain: `site-a`
3. Sets `Pwb::Current.website` to corresponding `Pwb::Website`
4. Controller queries: `.for_website(current_website.id)`
5. User only sees/manages their own website's settings

## Testing

### Model Specs

**File**: `spec/models/pwb/field_key_spec.rb`

```ruby
describe 'scopes' do
  it 'chains for_website and by_tag' do
    result = Pwb::FieldKey.for_website(website.id).by_tag('property-types')
    expect(result).to include(visible_key)
  end
end
```

### Controller Specs

**File**: `spec/controllers/site_admin/properties/settings_controller_spec.rb`

```ruby
describe 'POST #create' do
  it 'creates a new field key' do
    expect {
      post :create, params: valid_params
    }.to change(Pwb::FieldKey, :count).by(1)
  end
end
```

### System Specs

**File**: `spec/system/site_admin/properties_settings_spec.rb`

```ruby
it 'allows admin to add a new property type' do
  visit site_admin_properties_settings_category_path('property_types')
  click_button 'Add New Entry'
  fill_in 'field_key[translations][en]', with: 'Townhouse'
  click_button 'Create'
  expect(page).to have_content('Townhouse')
end
```

### Running Tests

```bash
# All properties settings tests
rspec spec/controllers/site_admin/properties/settings_controller_spec.rb
rspec spec/system/site_admin/properties_settings_spec.rb

# Model tests
rspec spec/models/pwb/field_key_spec.rb
```

## Integration Examples

### Using Settings in Property Forms

```ruby
# In property form view
<%= f.select :prop_type_key,
    options_from_collection_for_select(
      Pwb::FieldKey.by_tag('property-types').visible,
      :global_key,
      :label
    ),
    {}, { class: 'form-select' } %>
```

### Search Filter Integration

```ruby
# In search controller
@property_types = Pwb::FieldKey
  .by_tag('property-types')
  .for_website(current_website.id)
  .visible
  .order(:sort_order)
```

## Performance Considerations

### Database Indexes

Composite index on `[pwb_website_id, tag]` ensures fast queries:

```sql
SELECT * FROM pwb_field_keys 
WHERE pwb_website_id = 1 AND tag = 'property-types'
ORDER BY sort_order;
-- Uses index_field_keys_on_website_and_tag
```

### N+1 Prevention

Use eager loading when appropriate:

```ruby
@field_keys = Pwb::FieldKey
  .for_website(current_website.id)
  .by_tag(tag)
  .includes(:website)  # If displaying website info
```

### Caching

Consider caching dropdown options:

```ruby
Rails.cache.fetch("field_keys/#{website.id}/property-types", expires_in: 1.hour) do
  Pwb::FieldKey.get_options_by_tag('property-types')
end
```

## Extension Points

### Adding a New Category

1. Add to `VALID_CATEGORIES` hash in controller
2. Add database tag value
3. Add tab in `_tab_navigation.html.erb`
4. No other changes needed!

### Custom Validation

Add to model:

```ruby
validate :custom_validation_method

def custom_validation_method
  if tag == 'property-types' && global_key.length > 50
    errors.add(:global_key, 'too long for property types')
  end
end
```

### Bulk Import

Example rake task:

```ruby
namespace :settings do
  desc "Import property types from CSV"
  task :import_types, [:csv_path, :website_id] => :environment do |t, args|
    website = Pwb::Website.find(args[:website_id])
    
    CSV.foreach(args[:csv_path], headers: true) do |row|
      Pwb::FieldKey.create!(
        global_key: "property-types.#{row['key']}",
        tag: 'property-types',
        website: website,
        visible: true
      )
      # Store translations...
    end
  end
end
```

## Security

### Authorization

Currently uses Devise authentication:
- `before_action :authenticate_user!` in `SiteAdminController`

**TODO**: Add role-based authorization to restrict to admin users only.

### CSRF Protection

Rails CSRF tokens protect all POST/PATCH/DELETE requests automatically.

### SQL Injection

ActiveRecord sanitizes all inputs. Using `.where(tag: tag)` is safe.

## Troubleshooting

### "Translations Not Persisting"

**Issue**: Translations lost after server restart

**Solution**: Use database-backed I18n:

```ruby
# Gemfile
gem 'i18n-active_record'

# config/initializers/i18n.rb
I18n.backend = I18n::Backend::ActiveRecord.new
```

### "Can't Find FieldKey"

**Issue**: `ActiveRecord::RecordNotFound` when updating/deleting

**Cause**: Trying to access field key from another website

**Solution**: Ensure tenant scoping is working correctly

---

*Last Updated: December 2024*
