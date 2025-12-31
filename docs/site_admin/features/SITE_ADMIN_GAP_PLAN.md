# Site Admin Functionality Gap Plan

This document outlines missing functionality in the Site Admin interface and provides implementation plans for each gap.

---

## Executive Summary

| Priority | Gap | Effort | Impact |
|----------|-----|--------|--------|
| **P1** | Add New Property button | 30 min | High |
| **P1** | User Management (CRUD) | 4-6 hrs | High |
| **P2** | Enable Analytics in Navigation | 30 min | Medium |
| **P2** | Agency Profile Editor | 2-3 hrs | Medium |
| **P2** | Link Onboarding from Dashboard | 30 min | Medium |
| **P3** | Bulk Property Import/Export | 8-12 hrs | Medium |
| **P3** | Media Library | 6-8 hrs | Medium |
| **P3** | SEO Settings Tab | 3-4 hrs | Medium |
| **P4** | Billing/Subscription Management | 4-6 hrs | Low |
| **P4** | API Keys Management | 4-6 hrs | Low |
| **P4** | Activity Logs | 6-8 hrs | Low |

**Total Estimated Effort**: 40-60 hours

---

## Priority 1: Critical Gaps

### P1.1: Add New Property Button

**Problem**: No obvious way to create new properties from the admin interface.

**Current State**:
- Properties list exists at `/site_admin/props`
- No "Add Property" or "New" button visible
- Users must know the URL or find workaround

**Solution**: Add "New Property" button to properties list page and navigation.

**Files to Modify**:
```
app/views/site_admin/props/index.html.erb
app/views/layouts/site_admin/_navigation.html.erb
app/controllers/site_admin/props_controller.rb
config/routes.rb (if needed)
```

**Implementation**:

1. **Add route for new property** (if not exists):
```ruby
# config/routes.rb - site_admin namespace
resources :props do
  # ... existing routes
end
# Change to include :new and :create
resources :props, only: %i[index show new create] do
```

2. **Add controller actions**:
```ruby
# app/controllers/site_admin/props_controller.rb
def new
  @prop = current_website.props.build
end

def create
  @prop = current_website.props.build(prop_params)
  if @prop.save
    redirect_to edit_general_site_admin_prop_path(@prop),
                notice: 'Property created. Now add details.'
  else
    render :new
  end
end
```

3. **Add button to properties list**:
```erb
<%# app/views/site_admin/props/index.html.erb %>
<div class="flex justify-between items-center mb-6">
  <h1>Properties</h1>
  <%= link_to new_site_admin_prop_path,
              class: "btn btn-primary" do %>
    <svg>...</svg> Add Property
  <% end %>
</div>
```

4. **Create new property form**:
```erb
<%# app/views/site_admin/props/new.html.erb %>
<h1>Add New Property</h1>
<%= form_with model: @prop, url: site_admin_props_path do |f| %>
  <!-- Basic fields: reference, type, bedrooms, etc. -->
<% end %>
```

**Effort**: 30 minutes - 1 hour
**Risk**: Low

---

### P1.2: User Management (Full CRUD)

**Problem**: Users section is read-only. Cannot add team members or manage permissions.

**Current State**:
- Routes: `resources :users, only: %i[index show]`
- No invite, edit, or delete functionality
- No role/permission management

**Solution**: Implement full user management with role-based access.

**Files to Create/Modify**:
```
config/routes.rb
app/controllers/site_admin/users_controller.rb
app/views/site_admin/users/new.html.erb
app/views/site_admin/users/edit.html.erb
app/views/site_admin/users/_form.html.erb
app/models/concerns/user_roles.rb (if needed)
```

**Implementation**:

1. **Expand routes**:
```ruby
# config/routes.rb
resources :users do
  member do
    post :resend_invitation
    patch :update_role
  end
end
```

2. **Add controller actions**:
```ruby
# app/controllers/site_admin/users_controller.rb
def new
  @user = User.new
end

def create
  @user = User.new(user_params)
  @user.website = current_website

  if @user.save
    # Send invitation email
    UserMailer.invitation(@user).deliver_later
    redirect_to site_admin_users_path, notice: 'User invited successfully.'
  else
    render :new
  end
end

def edit
  @user = current_website.users.find(params[:id])
end

def update
  @user = current_website.users.find(params[:id])
  if @user.update(user_params)
    redirect_to site_admin_users_path, notice: 'User updated.'
  else
    render :edit
  end
end

def destroy
  @user = current_website.users.find(params[:id])

  if @user == current_user
    redirect_to site_admin_users_path, alert: 'Cannot delete yourself.'
  else
    @user.destroy
    redirect_to site_admin_users_path, notice: 'User removed.'
  end
end

private

def user_params
  params.require(:user).permit(:email, :first_names, :last_names, :role)
end
```

3. **Create invite form**:
```erb
<%# app/views/site_admin/users/new.html.erb %>
<h1>Invite Team Member</h1>
<%= form_with model: @user, url: site_admin_users_path do |f| %>
  <div class="mb-4">
    <%= f.label :email %>
    <%= f.email_field :email, class: "input" %>
  </div>
  <div class="mb-4">
    <%= f.label :role %>
    <%= f.select :role, [['Admin', 'admin'], ['Editor', 'editor'], ['Viewer', 'viewer']] %>
  </div>
  <%= f.submit 'Send Invitation', class: "btn btn-primary" %>
<% end %>
```

4. **Add user roles** (if not exists):
```ruby
# app/models/user.rb
enum role: { viewer: 0, editor: 1, admin: 2 }
```

**Effort**: 4-6 hours
**Risk**: Medium (affects authorization)

**Dependencies**:
- May need to add `role` column to users table
- Need to implement authorization checks throughout site_admin

---

## Priority 2: Important Gaps

### P2.1: Enable Analytics in Navigation

**Problem**: Analytics link is disabled in navigation despite routes existing.

**Current State**:
- Routes exist: `/site_admin/analytics`, `/traffic`, `/properties`, `/conversions`, `/realtime`
- Controller exists: `site_admin/analytics_controller.rb`
- Navigation link wrapped in `<% if false %>`

**Solution**: Enable analytics link conditionally based on subscription.

**Files to Modify**:
```
app/views/layouts/site_admin/_navigation.html.erb
```

**Implementation**:

```erb
<%# Replace the `if false` block with subscription check %>
<% if current_website.subscription&.analytics_enabled? %>
<div class="px-4 mb-4">
  <h3 class="px-4 text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">
    Insights
  </h3>

  <%= link_to site_admin_analytics_path,
              id: "tour-analytics",
              class: "flex items-center px-4 py-2 rounded-lg hover:bg-gray-700 #{request.path.start_with?('/site_admin/analytics') ? 'bg-gray-700' : ''}" do %>
    <svg class="w-5 h-5 mr-3" fill="currentColor" viewBox="0 0 20 20">
      <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5z..."></path>
    </svg>
    <span>Analytics</span>
  <% end %>
</div>
<% end %>
```

**Alternative**: Show link to all but display upgrade prompt on the page itself (current behavior).

**Effort**: 30 minutes
**Risk**: Low

---

### P2.2: Agency Profile Editor

**Problem**: No direct way to edit company/agency information.

**Current State**:
- Agency model exists (`Pwb::Agency`)
- Company name editable in website settings
- No dedicated agency profile page with logo, contact info, etc.

**Solution**: Add Agency Profile section to site admin.

**Files to Create/Modify**:
```
config/routes.rb
app/controllers/site_admin/agency_controller.rb
app/views/site_admin/agency/edit.html.erb
app/views/layouts/site_admin/_navigation.html.erb
```

**Implementation**:

1. **Add route**:
```ruby
# config/routes.rb - site_admin namespace
resource :agency, only: %i[edit update]
```

2. **Create controller**:
```ruby
# app/controllers/site_admin/agency_controller.rb
module SiteAdmin
  class AgencyController < BaseController
    def edit
      @agency = current_website.agency || current_website.build_agency
    end

    def update
      @agency = current_website.agency || current_website.build_agency
      if @agency.update(agency_params)
        redirect_to edit_site_admin_agency_path, notice: 'Agency profile updated.'
      else
        render :edit
      end
    end

    private

    def agency_params
      params.require(:agency).permit(
        :display_name, :company_name, :email_primary, :phone_number_primary,
        :address_line_1, :address_line_2, :city, :region, :postal_code, :country,
        :logo, :website_url, :description
      )
    end
  end
end
```

3. **Add to navigation**:
```erb
<%# In Website section %>
<%= link_to edit_site_admin_agency_path,
            id: "tour-agency",
            class: "flex items-center px-4 py-2 rounded-lg hover:bg-gray-700" do %>
  <svg class="w-5 h-5 mr-3">...</svg>
  <span>Agency Profile</span>
<% end %>
```

**Effort**: 2-3 hours
**Risk**: Low

---

### P2.3: Link Onboarding from Dashboard

**Problem**: Onboarding wizard not accessible after initial setup.

**Current State**:
- Onboarding exists at `/site_admin/onboarding`
- 5-step wizard implemented
- No link in dashboard or navigation

**Solution**: Add "Setup Wizard" link and progress indicator.

**Implementation**:

1. **Add to navigation** (in Website section):
```erb
<%= link_to site_admin_onboarding_path,
            class: "flex items-center px-4 py-2 rounded-lg hover:bg-gray-700" do %>
  <svg class="w-5 h-5 mr-3">...</svg>
  <span>Setup Wizard</span>
  <% unless current_website.onboarding_completed? %>
    <span class="ml-auto bg-yellow-500 text-xs px-2 py-0.5 rounded">Incomplete</span>
  <% end %>
<% end %>
```

2. **Add progress card to dashboard** (if incomplete):
```erb
<%# app/views/site_admin/dashboard/index.html.erb %>
<% unless current_website.onboarding_completed? %>
<div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
  <h3 class="font-semibold text-blue-800">Complete Your Setup</h3>
  <p class="text-blue-600 text-sm mb-2">Finish setting up your website to unlock all features.</p>
  <%= link_to 'Continue Setup', site_admin_onboarding_path, class: "btn btn-primary btn-sm" %>
</div>
<% end %>
```

**Effort**: 30 minutes
**Risk**: Low

---

## Priority 3: Enhancement Gaps

### P3.1: Bulk Property Import/Export

**Problem**: No way to import properties from CSV/XML or export for backup.

**Solution**: Add import/export functionality.

**Files to Create**:
```
app/controllers/site_admin/props/imports_controller.rb
app/controllers/site_admin/props/exports_controller.rb
app/services/property_importer.rb
app/services/property_exporter.rb
app/views/site_admin/props/imports/new.html.erb
app/jobs/property_import_job.rb
```

**Features**:
- CSV template download
- CSV upload with validation
- Progress tracking for large imports
- Export to CSV/JSON
- Field mapping UI

**Effort**: 8-12 hours
**Risk**: Medium

---

### P3.2: Media Library

**Problem**: No centralized image management.

**Current State**:
- Images uploaded per-property
- `/site_admin/images` endpoint exists but not in UI
- No way to browse/reuse images

**Solution**: Add Media Library section.

**Features**:
- Grid view of all uploaded images
- Upload new images
- Search/filter images
- Select images for properties
- Delete unused images

**Effort**: 6-8 hours
**Risk**: Low

---

### P3.3: SEO Settings Tab

**Problem**: No visible SEO configuration.

**Solution**: Add SEO tab to Website Settings.

**Fields**:
- Default meta title template
- Default meta description template
- Open Graph defaults
- Twitter Card settings
- Google Search Console verification
- Sitemap configuration
- Robots.txt customization

**Effort**: 3-4 hours
**Risk**: Low

---

## Priority 4: Nice-to-Have Gaps

### P4.1: Billing/Subscription Management

**Problem**: Can view subscription but not manage it.

**Solution**: Link to billing portal or show inline management.

**Effort**: 4-6 hours (depends on payment provider integration)

---

### P4.2: API Keys Management

**Problem**: No way to generate API keys for integrations.

**Solution**: Add API Keys section for developers.

**Effort**: 4-6 hours

---

### P4.3: Activity Logs

**Problem**: No audit trail of admin actions.

**Solution**: Track and display admin activity.

**Effort**: 6-8 hours

---

## Implementation Roadmap

### Phase 1: Quick Wins (Week 1)
- [x] P1.1: Add New Property button
- [ ] P2.1: Enable Analytics in navigation
- [ ] P2.3: Link Onboarding from Dashboard

**Effort**: ~2 hours

### Phase 2: User Management (Week 2)
- [ ] P1.2: Full User CRUD
- [ ] Add role-based permissions

**Effort**: ~6 hours

### Phase 3: Profile & Settings (Week 3)
- [ ] P2.2: Agency Profile Editor
- [ ] P3.3: SEO Settings Tab

**Effort**: ~6 hours

### Phase 4: Advanced Features (Week 4+)
- [ ] P3.1: Bulk Import/Export
- [ ] P3.2: Media Library

**Effort**: ~16 hours

---

## Testing Checklist

For each feature:
- [ ] Unit tests for new controller actions
- [ ] Integration tests for workflows
- [ ] Authorization tests (only website owner can access)
- [ ] Multi-tenant isolation tests
- [ ] UI/UX review

---

## Related Documentation

- [Admin Pages Inventory](./PAGES_INVENTORY.md)
- [Screenshots Plan](./SCREENSHOTS_PLAN.md)
- [Tenant Admin Structure](./TENANT_ADMIN_STRUCTURE.md)

---

## Changelog

| Date | Changes |
|------|---------|
| 2024-12-25 | Initial plan created |
