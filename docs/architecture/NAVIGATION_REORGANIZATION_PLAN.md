# Site Admin Navigation Reorganization Plan

## Overview

This document outlines the implementation plan for reorganizing the site_admin navigation from its current organic structure to a principled, outcome-focused architecture.

**Guiding Principle**: Navigation should reflect outcomes, not models.

**Scope**: This plan excludes role-based visibility (to be implemented later).

---

## Current State Summary

### Existing Navigation Structure

```
Quick Access:
  - Dashboard
  - Properties
  - Inbox (with badge)
  - Pages

Content Management (collapsible):
  - Properties (duplicate)
  - Import/Export
  - Labels
  - Pages (duplicate)
  - Media Library

Communication (collapsible):
  - Inbox (duplicate)
  - All Messages
  - All Contacts
  - Email Templates
  - Support

Insights (collapsible):
  - Analytics

User Management (collapsible):
  - Users
  - Activity Logs

Website (collapsible):
  - Appearance
  - SEO
  - Settings
  - Agency Profile
  - Billing
  - Domain
  - Embed Widgets
  - Setup Wizard
  - View Site
```

### Problems Identified

1. **Duplicate entries**: Properties (3x), Pages (2x), Inbox (2x)
2. **Mixed mental models**: Content, operations, platform, and meta tasks at same level
3. **Poor naming**: "Props", "Messages" vs "Inbox" distinction unclear
4. **Missing groupings**: External feeds, integrations have no clear home

---

## Target State

### New Navigation Structure

```
Dashboard
  - Overview (existing)
  - Quick actions

Listings                          [renamed from "Content Management"]
  - All Listings                  [renamed from "Properties"]
  - Add Listing                   [new quick action]
  - Import / Export
  - External Feeds                [moved from Website > Settings]
  - Labels & Categories           [renamed from "Labels"]

Leads & Messages                  [renamed from "Communication"]
  - Inbox                         [primary, with badge]
  - Contacts
  - Message History               [renamed from "All Messages"]
  - Email Templates
  - Support Tickets               [clarified name]

Site Design                       [renamed from "Website"]
  - Theme & Appearance
  - Pages
  - Media Library
  - Navigation & Menus            [future]
  - SEO
  - Embed Widgets
  - Domain
  - Setup Wizard                  [contextual, hide when complete]

Insights
  - Analytics
  - Activity Logs                 [moved from User Management]
  - SEO Audit                     [surface existing feature]
  - Storage Stats                 [surface existing feature]

Settings                          [renamed from "User Management" + parts of "Website"]
  - Team & Users                  [renamed from "Users"]
  - Agency Profile
  - Billing & Subscription
  - Integrations                  [future home for API keys, webhooks]
```

---

## Implementation Phases

### Phase 1: Naming & Terminology Updates
**Estimated effort**: 2-3 hours
**Risk**: Low

Update labels without changing structure or routes.

| Current | New |
|---------|-----|
| Properties | Listings |
| Props | Listings |
| Messages | Message History |
| All Contacts | Contacts |
| Labels | Labels & Categories |
| Appearance | Theme & Appearance |
| Users | Team & Users |
| Support | Support Tickets |

**Files to modify**:
- `app/views/layouts/site_admin/_navigation.html.erb`
- `config/locales/en.yml` (if using i18n)
- Shepherd.js tour steps

### Phase 2: Remove Duplicates & Reorganize
**Estimated effort**: 3-4 hours
**Risk**: Medium

1. Remove "Quick Access" section entirely
2. Create new section groupings
3. Move items to correct sections
4. Update Alpine.js state keys for new sections

**New section keys**:
```javascript
{
  listingsOpen: true,      // was: contentOpen
  leadsOpen: true,         // was: communicationOpen
  siteDesignOpen: true,    // was: websiteOpen
  insightsOpen: true,      // unchanged
  settingsOpen: false      // was: usersOpen (default closed)
}
```

### Phase 3: Move External Feeds to Listings
**Estimated effort**: 1-2 hours
**Risk**: Low

External feeds are about property import - they belong with Listings, not Website settings.

**Route change**: None needed (already exists as `site_admin_external_feed_path`)
**Navigation change**: Move link from Website section to Listings section

### Phase 4: Consolidate Insights Section
**Estimated effort**: 1-2 hours
**Risk**: Low

Move Activity Logs from "User Management" to "Insights".
Surface SEO Audit and Storage Stats in navigation (currently hidden).

### Phase 5: Create Settings Section
**Estimated effort**: 2-3 hours
**Risk**: Medium

New "Settings" section combining:
- Team & Users (from User Management)
- Agency Profile (from Website)
- Billing & Subscription (from Website)

### Phase 6: Update Guided Tour
**Estimated effort**: 2-3 hours
**Risk**: Low

Update Shepherd.js tour to reflect new navigation structure.

---

## Detailed Implementation

### Phase 1: Naming Updates

#### File: `app/views/layouts/site_admin/_navigation.html.erb`

```erb
<!-- BEFORE -->
<span class="nav-text">Properties</span>

<!-- AFTER -->
<span class="nav-text">Listings</span>
```

#### Changes Required

```diff
- Properties → Listings (all occurrences)
- All Messages → Message History
- All Contacts → Contacts
- Labels → Labels & Categories
- Appearance → Theme & Appearance
- Users → Team & Users
- Support → Support Tickets
- Content Management → Listings
- Communication → Leads & Messages
- User Management → Settings
- Website → Site Design
```

### Phase 2: Structure Reorganization

#### New Navigation Template Structure

```erb
<nav x-data="{
  listingsOpen: localStorage.getItem('nav_listingsOpen') !== 'false',
  leadsOpen: localStorage.getItem('nav_leadsOpen') !== 'false',
  siteDesignOpen: localStorage.getItem('nav_siteDesignOpen') !== 'false',
  insightsOpen: localStorage.getItem('nav_insightsOpen') !== 'false',
  settingsOpen: localStorage.getItem('nav_settingsOpen') === 'true',
  toggle(key) {
    this[key] = !this[key];
    localStorage.setItem('nav_' + key, this[key]);
  }
}">

  <!-- Dashboard (always visible, not collapsible) -->
  <a href="<%= site_admin_root_path %>">Dashboard</a>

  <!-- Listings Section -->
  <div>
    <button @click="toggle('listingsOpen')">Listings</button>
    <div x-show="listingsOpen">
      <a href="<%= site_admin_props_path %>">All Listings</a>
      <a href="<%= new_site_admin_prop_path %>">Add Listing</a>
      <a href="<%= site_admin_property_import_export_path %>">Import / Export</a>
      <a href="<%= site_admin_external_feed_path %>">External Feeds</a>
      <a href="<%= site_admin_properties_settings_path %>">Labels & Categories</a>
    </div>
  </div>

  <!-- Leads & Messages Section -->
  <div>
    <button @click="toggle('leadsOpen')">Leads & Messages</button>
    <div x-show="leadsOpen">
      <a href="<%= site_admin_inbox_index_path %>">Inbox</a>
      <a href="<%= site_admin_contacts_path %>">Contacts</a>
      <a href="<%= site_admin_messages_path %>">Message History</a>
      <a href="<%= site_admin_email_templates_path %>">Email Templates</a>
      <a href="<%= site_admin_support_tickets_path %>">Support Tickets</a>
    </div>
  </div>

  <!-- Site Design Section -->
  <div>
    <button @click="toggle('siteDesignOpen')">Site Design</button>
    <div x-show="siteDesignOpen">
      <a href="<%= site_admin_website_settings_tab_path('appearance') %>">Theme & Appearance</a>
      <a href="<%= site_admin_pages_path %>">Pages</a>
      <a href="<%= site_admin_media_library_index_path %>">Media Library</a>
      <a href="<%= site_admin_website_settings_tab_path('seo') %>">SEO</a>
      <a href="<%= site_admin_widgets_path %>">Embed Widgets</a>
      <a href="<%= site_admin_domain_path %>">Domain</a>
      <a href="<%= site_admin_onboarding_path %>">Setup Wizard</a>
    </div>
  </div>

  <!-- Insights Section -->
  <div>
    <button @click="toggle('insightsOpen')">Insights</button>
    <div x-show="insightsOpen">
      <a href="<%= site_admin_analytics_path %>">Analytics</a>
      <a href="<%= site_admin_activity_logs_path %>">Activity Logs</a>
      <a href="<%= site_admin_seo_audit_path %>">SEO Audit</a>
      <a href="<%= site_admin_storage_stats_path %>">Storage Stats</a>
    </div>
  </div>

  <!-- Settings Section -->
  <div>
    <button @click="toggle('settingsOpen')">Settings</button>
    <div x-show="settingsOpen">
      <a href="<%= site_admin_users_path %>">Team & Users</a>
      <a href="<%= edit_site_admin_agency_path %>">Agency Profile</a>
      <a href="<%= site_admin_billing_path %>">Billing & Subscription</a>
      <a href="<%= site_admin_website_settings_path %>">Website Settings</a>
    </div>
  </div>

  <!-- External Links -->
  <a href="<%= root_path %>" target="_blank">View Site</a>

</nav>
```

---

## Test Plan

### Unit Tests

#### File: `spec/helpers/site_admin_navigation_helper_spec.rb` (new)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdminNavigationHelper, type: :helper do
  describe '#navigation_sections' do
    it 'returns all navigation sections' do
      sections = helper.navigation_sections
      expect(sections.keys).to contain_exactly(
        :dashboard, :listings, :leads, :site_design, :insights, :settings
      )
    end
  end

  describe '#section_items' do
    context 'for listings section' do
      it 'includes all listing-related items' do
        items = helper.section_items(:listings)
        expect(items.map { |i| i[:key] }).to include(
          :all_listings, :add_listing, :import_export, :external_feeds, :labels
        )
      end
    end

    context 'for leads section' do
      it 'includes all communication items' do
        items = helper.section_items(:leads)
        expect(items.map { |i| i[:key] }).to include(
          :inbox, :contacts, :message_history, :email_templates, :support_tickets
        )
      end
    end
  end

  describe '#nav_item_label' do
    it 'returns correct label for listings' do
      expect(helper.nav_item_label(:all_listings)).to eq('All Listings')
    end

    it 'returns correct label for message_history' do
      expect(helper.nav_item_label(:message_history)).to eq('Message History')
    end
  end
end
```

### Feature/Request Tests

#### File: `spec/requests/site_admin/navigation_spec.rb` (new)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Navigation', type: :request do
  let(:website) { create(:website) }
  let(:admin_user) { create(:user, :admin, website: website) }

  before do
    sign_in admin_user
    allow_any_instance_of(ApplicationController).to receive(:current_website).and_return(website)
  end

  describe 'navigation structure' do
    it 'renders the dashboard link' do
      get site_admin_root_path
      expect(response.body).to include('Dashboard')
    end

    it 'renders the Listings section' do
      get site_admin_root_path
      expect(response.body).to include('Listings')
      expect(response.body).to include('All Listings')
      expect(response.body).to include('Import / Export')
      expect(response.body).to include('Labels &amp; Categories')
    end

    it 'renders the Leads & Messages section' do
      get site_admin_root_path
      expect(response.body).to include('Leads &amp; Messages')
      expect(response.body).to include('Inbox')
      expect(response.body).to include('Contacts')
      expect(response.body).to include('Message History')
    end

    it 'renders the Site Design section' do
      get site_admin_root_path
      expect(response.body).to include('Site Design')
      expect(response.body).to include('Theme &amp; Appearance')
      expect(response.body).to include('Pages')
      expect(response.body).to include('Media Library')
    end

    it 'renders the Insights section' do
      get site_admin_root_path
      expect(response.body).to include('Insights')
      expect(response.body).to include('Analytics')
      expect(response.body).to include('Activity Logs')
    end

    it 'renders the Settings section' do
      get site_admin_root_path
      expect(response.body).to include('Settings')
      expect(response.body).to include('Team &amp; Users')
      expect(response.body).to include('Agency Profile')
      expect(response.body).to include('Billing')
    end
  end

  describe 'navigation does not contain duplicates' do
    it 'shows Listings only once in section headers' do
      get site_admin_root_path
      # Count occurrences of section header (not individual links)
      section_headers = response.body.scan(/data-section="listings"/).count
      expect(section_headers).to eq(1)
    end

    it 'shows Inbox only once' do
      get site_admin_root_path
      inbox_links = response.body.scan(/href="#{Regexp.escape(site_admin_inbox_index_path)}"/).count
      expect(inbox_links).to eq(1)
    end
  end

  describe 'navigation accessibility' do
    it 'includes tour IDs for guided tour' do
      get site_admin_root_path
      expect(response.body).to include('id="tour-dashboard"')
      expect(response.body).to include('id="tour-listings"')
      expect(response.body).to include('id="tour-inbox"')
    end
  end
end
```

### System/Integration Tests

#### File: `spec/system/site_admin/navigation_spec.rb` (new)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Navigation', type: :system do
  let(:website) { create(:website) }
  let(:admin_user) { create(:user, :admin, website: website) }

  before do
    driven_by(:rack_test)
    sign_in admin_user
    allow_any_instance_of(ApplicationController).to receive(:current_website).and_return(website)
  end

  describe 'section navigation' do
    it 'navigates to All Listings from Listings section' do
      visit site_admin_root_path
      click_link 'All Listings'
      expect(page).to have_current_path(site_admin_props_path)
    end

    it 'navigates to Inbox from Leads & Messages section' do
      visit site_admin_root_path
      click_link 'Inbox'
      expect(page).to have_current_path(site_admin_inbox_index_path)
    end

    it 'navigates to Pages from Site Design section' do
      visit site_admin_root_path
      click_link 'Pages'
      expect(page).to have_current_path(site_admin_pages_path)
    end

    it 'navigates to Analytics from Insights section' do
      visit site_admin_root_path
      click_link 'Analytics'
      expect(page).to have_current_path(site_admin_analytics_path)
    end

    it 'navigates to Team & Users from Settings section' do
      visit site_admin_root_path
      click_link 'Team & Users'
      expect(page).to have_current_path(site_admin_users_path)
    end
  end

  describe 'unread message badge' do
    context 'with unread messages' do
      before do
        create_list(:message, 3, website: website, read: false)
      end

      it 'displays the unread count on Inbox' do
        visit site_admin_root_path
        within('#tour-inbox') do
          expect(page).to have_content('3')
        end
      end
    end

    context 'without unread messages' do
      it 'does not display a badge' do
        visit site_admin_root_path
        within('#tour-inbox') do
          expect(page).not_to have_css('.badge')
        end
      end
    end
  end
end
```

### Regression Tests

#### File: `spec/requests/site_admin/navigation_regression_spec.rb` (new)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Navigation Regression', type: :request do
  let(:website) { create(:website) }
  let(:admin_user) { create(:user, :admin, website: website) }

  before do
    sign_in admin_user
    allow_any_instance_of(ApplicationController).to receive(:current_website).and_return(website)
  end

  describe 'all navigation links are valid routes' do
    let(:expected_paths) do
      [
        :site_admin_root_path,
        :site_admin_props_path,
        :new_site_admin_prop_path,
        :site_admin_property_import_export_path,
        :site_admin_external_feed_path,
        :site_admin_properties_settings_path,
        :site_admin_inbox_index_path,
        :site_admin_contacts_path,
        :site_admin_messages_path,
        :site_admin_email_templates_path,
        :site_admin_support_tickets_path,
        :site_admin_pages_path,
        :site_admin_media_library_index_path,
        :site_admin_widgets_path,
        :site_admin_domain_path,
        :site_admin_onboarding_path,
        :site_admin_analytics_path,
        :site_admin_activity_logs_path,
        :site_admin_seo_audit_path,
        :site_admin_storage_stats_path,
        :site_admin_users_path,
        :edit_site_admin_agency_path,
        :site_admin_billing_path,
        :site_admin_website_settings_path
      ]
    end

    it 'all paths respond with success or redirect' do
      expected_paths.each do |path_helper|
        path = send(path_helper)
        get path
        expect(response.status).to be_in([200, 302, 303]),
          "Expected #{path_helper} (#{path}) to respond with 200/302/303, got #{response.status}"
      end
    end
  end

  describe 'backward compatibility' do
    it 'site_admin_props_path still works' do
      get site_admin_props_path
      expect(response).to have_http_status(:success)
    end

    it 'site_admin_messages_path still works' do
      get site_admin_messages_path
      expect(response).to have_http_status(:success)
    end

    it 'site_admin_users_path still works' do
      get site_admin_users_path
      expect(response).to have_http_status(:success)
    end
  end
end
```

---

## Migration Checklist

**Status: COMPLETED (January 2026)**

### Pre-Implementation

- [x] Create feature branch: `feature/navigation-reorganization`
- [x] Backup current `_navigation.html.erb`
- [x] Document current tour step IDs

### Phase 1: Naming Updates

- [x] Update section header labels
- [x] Update nav item labels
- [x] Update tour step titles
- [x] Run existing tests to ensure no breakage
- [x] Add new navigation helper specs

### Phase 2: Structure Reorganization

- [x] ~~Create `SiteAdminNavigationHelper` module~~ (not needed - kept inline)
- [x] Remove Quick Access section
- [x] Create new section groupings
- [x] Update Alpine.js state keys
- [x] ~~Migrate localStorage keys~~ (not needed - new keys used)
- [x] Add navigation structure specs

### Phase 3: Move External Feeds

- [x] Move External Feeds link to Listings section
- [x] Update tour if needed
- [x] Verify routing still works

### Phase 4: Consolidate Insights

- [x] Move Activity Logs to Insights
- [x] Add SEO Audit to navigation
- [x] Add Storage Stats to navigation
- [x] Update specs

### Phase 5: Create Settings Section

- [x] Create Settings section
- [x] Move Team & Users
- [x] Move Agency Profile
- [x] Move Billing & Subscription
- [x] Move Website Settings link
- [x] Update specs

### Phase 6: Update Guided Tour

- [x] Update tour step selectors
- [x] Update tour step content
- [x] Test tour end-to-end
- [x] Add tour regression tests

### Post-Implementation

- [x] Run full test suite
- [ ] Manual QA on all navigation paths
- [ ] Update user documentation if exists
- [ ] Create PR with before/after screenshots

---

## Rollback Plan

If issues arise:

1. Revert `_navigation.html.erb` to backup
2. Clear localStorage migration (optional)
3. Revert any helper changes

The rollback is low-risk because:
- No routes are changed
- No controllers are changed
- Only view/helper changes involved

---

## Future Considerations (Out of Scope)

These items are noted but **not included** in this implementation:

1. **Role-based visibility** - Different nav for agents vs admins
2. **Navigation & Menus** - Let users customize their site navigation
3. **Integrations section** - API keys, webhooks, third-party connections
4. **Contextual hiding** - Hide Setup Wizard when complete
5. **Search/command palette** - Quick navigation via keyboard

---

## Timeline Estimate

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1: Naming | 2-3 hours | None |
| Phase 2: Structure | 3-4 hours | Phase 1 |
| Phase 3: External Feeds | 1-2 hours | Phase 2 |
| Phase 4: Insights | 1-2 hours | Phase 2 |
| Phase 5: Settings | 2-3 hours | Phase 2 |
| Phase 6: Tour | 2-3 hours | All above |
| Testing & QA | 2-3 hours | All above |

**Total: 14-20 hours**

---

## Approval

- [x] Technical review complete
- [ ] UX review complete (optional)
- [x] Ready for implementation
- [x] **IMPLEMENTED** (January 2026)
