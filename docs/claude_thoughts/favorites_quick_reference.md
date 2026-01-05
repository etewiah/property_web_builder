# Favorites & Saved Searches - Quick Reference Guide

## Files at a Glance

### Models
| File | Purpose |
|------|---------|
| `app/models/pwb/saved_property.rb` | Base SavedProperty model with all logic |
| `app/models/pwb_tenant/saved_property.rb` | Tenant-scoped wrapper (2 lines) |
| `app/models/pwb/saved_search.rb` | Base SavedSearch model with all logic |
| `app/models/pwb_tenant/saved_search.rb` | Tenant-scoped wrapper (2 lines) |

### Controllers
| File | Purpose |
|------|---------|
| `app/controllers/pwb/site/my/saved_properties_controller.rb` | Favorites CRUD + check endpoint |
| `app/controllers/pwb/site/my/saved_searches_controller.rb` | Searches CRUD + verify/unsubscribe |

### Views
| Path | Purpose |
|------|---------|
| `app/views/pwb/site/my/saved_properties/index.html.erb` | Favorites listing page |
| `app/views/pwb/site/my/saved_properties/no_favorites.html.erb` | Empty state |
| `app/views/pwb/site/my/saved_searches/index.html.erb` | Searches listing page |
| `app/views/pwb/site/my/saved_searches/show.html.erb` | Single search details |
| `app/views/pwb/site/my/saved_searches/no_searches.html.erb` | Empty state |
| `app/views/pwb/site/my/saved_searches/unsubscribe.html.erb` | Unsubscribe confirmation |

### Frontend
| File | Contains |
|------|----------|
| `app/views/pwb/site/external_listings/index.html.erb` | Save Search & Favorite modals (lines 207-356) + JS (lines 357-424) |
| `app/views/pwb/site/external_listings/_property_card.html.erb` | Heart icon favorite button (lines 36-58) |
| `app/themes/default/views/pwb/props/show.html.erb` | Duplicate favorite modal for property detail page |

### Database
| File | Purpose |
|------|---------|
| `db/migrate/20260101225644_create_pwb_saved_properties.rb` | Properties table |
| `db/migrate/20260101225640_create_pwb_saved_searches.rb` | Searches table |

## Key Code Snippets

### Favorite a Property (From JavaScript)
```javascript
toggleFavorite(event, reference, title, propertyData) {
  event.preventDefault();
  
  // Prefill from localStorage
  var savedEmail = localStorage.getItem('pwb_favorites_email');
  
  // Populate modal
  document.getElementById('favorite-reference').value = reference;
  document.getElementById('favorite-property-name').textContent = title;
  document.getElementById('favorite-property-data').value = JSON.stringify(propertyData);
  document.getElementById('favorite_email').value = savedEmail || '';
  
  // Show modal
  document.getElementById('favorite-modal').classList.remove('hidden');
}
```

### Save Property (From Controller)
```ruby
def create
  @saved_property = PwbTenant::SavedProperty.new(saved_property_params)
  @saved_property.website = current_website
  
  if @saved_property.property_data.blank?
    fetch_and_cache_property_data
  end
  
  if @saved_property.save
    render json: {
      success: true,
      message: "Property saved to favorites",
      manage_url: my_favorites_url(token: @saved_property.manage_token)
    }, status: :created
  end
end
```

### Get Favorites List (Token-Based Access)
```ruby
def index
  property = PwbTenant::SavedProperty.find_by(manage_token: params[:token])
  
  if property
    @saved_properties = PwbTenant::SavedProperty.for_email(property.email).recent
  else
    @saved_properties = []
  end
end
```

### SavedProperty Model Essentials
```ruby
class SavedProperty < ApplicationRecord
  # Scopes
  scope :for_email, ->(email) { where(email: email.to_s.downcase.strip) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Class method to save
  def self.save_property!(website:, email:, provider:, reference:, property_data:)
    find_or_create_by!(
      website: website,
      email: email.to_s.downcase.strip,
      provider: provider,
      external_reference: reference
    ) do |sp|
      sp.property_data = property_data
      sp.original_price_cents = extract_price_cents(property_data)
      sp.current_price_cents = sp.original_price_cents
    end
  end
  
  # Instance methods
  def property_data_hash; (property_data || {}).deep_symbolize_keys; end
  def title; property_data_hash[:title] || "Property #{external_reference}"; end
  def price; extract from property_data_hash[:price]; end
  def price_changed?; price_changed_at.present? && original_price_cents != current_price_cents; end
  def manage_url(host:); "#{host}/my/favorites?token=#{manage_token}"; end
end
```

### SavedSearch Model Essentials
```ruby
class SavedSearch < ApplicationRecord
  enum :alert_frequency, { none: 0, daily: 1, weekly: 2 }, prefix: :frequency
  
  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :daily_alerts, -> { enabled.where(alert_frequency: :daily) }
  scope :weekly_alerts, -> { enabled.where(alert_frequency: :weekly) }
  scope :for_email, ->(email) { where(email: email.to_s.downcase.strip) }
  
  # Instance methods
  def search_criteria_hash; (search_criteria || {}).deep_symbolize_keys; end
  def criteria_summary; "#{listing_type}, #{location}, #{price_range}, #{bedrooms_range}"; end
  def find_new_properties(current_refs); (current_refs - (seen_property_refs || [])); end
  def record_new_properties!(property_refs); update!(seen_property_refs: new_refs); end
  def verify_email!; update!(email_verified: true, verified_at: Time.current); end
  def unsubscribe!; update!(enabled: false, alert_frequency: :none); end
end
```

## Routing Summary

```ruby
# In config/routes.rb (simplified)
namespace :pwb do
  namespace :site do
    namespace :my do
      # Favorites
      resources :saved_properties, only: [:create, :index, :show, :update, :destroy] do
        collection do
          post :check  # POST /my/favorites/check
        end
      end
      
      # Searches
      resources :saved_searches, only: [:create, :index, :show, :update, :destroy] do
        member do
          get :verify        # GET /my/saved_searches/:id/verify?token=...
          get :unsubscribe   # GET /my/saved_searches/:id/unsubscribe?token=...
        end
      end
    end
  end
end
```

## Common Patterns

### Prefilling Forms from localStorage
```javascript
// Pattern used in both modals
var savedEmail = localStorage.getItem('pwb_favorites_email');
if (savedEmail && emailInput) {
  emailInput.value = savedEmail;
}
```

### Saving Email to localStorage on Submit
```javascript
// Pattern used in both forms
favoriteForm.addEventListener('submit', function() {
  var emailInput = document.getElementById('favorite_email');
  if (emailInput && emailInput.value) {
    localStorage.setItem('pwb_favorites_email', emailInput.value);
  }
});
```

### Token-Based Access Without Login
```ruby
# Pattern in both controllers
before_action :set_saved_property_by_token, only: [:show, :update, :destroy]
before_action :set_properties_by_manage_token, only: [:index]

def set_saved_property_by_token
  @saved_property = PwbTenant::SavedProperty.find_by(manage_token: params[:token])
  unless @saved_property
    flash[:alert] = "Invalid or expired link"
    redirect_to root_path
  end
end
```

### Price Tracking
```ruby
# In SavedProperty model
def track_price_change
  return unless property_data_changed?
  return unless persisted?
  
  new_price = self.class.extract_price_cents(property_data)
  return unless new_price && current_price_cents && new_price != current_price_cents
  
  self.current_price_cents = new_price
  self.price_changed_at = Time.current
end
```

### Multi-Tenancy Enforcement
```ruby
# Both models use acts_as_tenant
class SavedProperty < ApplicationRecord
  acts_as_tenant :website, class_name: "Pwb::Website"
end

# Controller automatically scopes by current_website
@saved_property.website = current_website
```

## localStorage Keys Used

| Key | Value Type | Set By | Used By |
|-----|-----------|--------|---------|
| `pwb_favorites_email` | String (email) | Form submit handlers | Modal prefill functions |
| `nav_contentOpen` | Boolean | Admin nav | Sidebar state |
| `nav_communicationOpen` | Boolean | Admin nav | Sidebar state |
| `nav_insightsOpen` | Boolean | Admin nav | Sidebar state |
| `nav_usersOpen` | Boolean | Admin nav | Sidebar state |
| `nav_websiteOpen` | Boolean | Admin nav | Sidebar state |
| `pwb-editor-panel-height` | CSS value | Page editor | Editor restoration |
| `siteAdminTourCompleted` | Boolean | Tour system | Tour tracking |

## Email Templates Generated

The system sends emails with:
1. **Favorite confirmation** - Link to `/my/favorites?token=MANAGE_TOKEN`
2. **Saved search confirmation** - Link to `/my/saved_searches?token=MANAGE_TOKEN`
3. **Daily/weekly alerts** - New matching properties with unsubscribe link
4. **Unsubscribe link** - `/my/saved_searches/unsubscribe?token=UNSUB_TOKEN`
5. **Verification link** - `/my/saved_searches/verify?token=VERIFY_TOKEN`

Email templates location likely in:
- `app/views/mailers/` or
- `app/views/pwb/mailers/`

## Common Issues & Solutions

### Problem: Email not prefilling in modal
**Solution:** Check that localStorage key is exactly `pwb_favorites_email`

### Problem: Token-based access fails
**Cause:** Token parameter name mismatch
**Solution:** Use `?token=XXX` (lowercase) in URLs

### Problem: Can't save same property twice
**This is intentional:** Database has unique constraint on `(email, provider, external_reference)`

### Problem: Price tracking not working
**Check:**
1. Is `property_data` being updated?
2. Is record already persisted before tracking?
3. Are prices in cents format?

### Problem: Email verification always passes
**Note:** Currently `verify_email!` is called immediately in create (line 22 of controller)
**To change:** Implement optional email verification flow

## Testing Tips

### Test Saving a Property
```ruby
post my_favorites_path, params: {
  saved_property: {
    email: 'user@example.com',
    external_reference: 'prop-123',
    provider: 'external_feed',
    property_data: { title: 'Test', price: 500000 }
  }
}
```

### Test Token Access
```ruby
saved = SavedProperty.first
get my_favorites_path(token: saved.manage_token)
expect(response).to have_http_status(:ok)
```

### Test Price Tracking
```ruby
saved = SavedProperty.create!(
  email: 'test@example.com',
  external_reference: 'ref',
  provider: 'feed',
  property_data: { price: 500000 },
  original_price_cents: 50000000,
  current_price_cents: 50000000
)

saved.update!(property_data: { price: 550000 })
expect(saved.current_price_cents).to eq(55000000)
expect(saved.price_changed_at).to be_present
```

## See Also

For detailed information, see:
- `/docs/claude_thoughts/favorites_and_saved_searches_exploration.md` - Full implementation details
- `/docs/claude_thoughts/favorites_architecture_diagram.md` - System diagrams and flows
