# Site Admin Improvement Plan

**Document Version:** 1.0  
**Last Updated:** 2026-01-04  
**Status:** Planning Phase

## Executive Summary

This document outlines a comprehensive plan to improve the site_admin section of PropertyWebBuilder, focusing on navigation UX, consistency, missing functionality, and code quality. The improvements are organized by priority and complexity, with clear dependencies and implementation order.

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Navigation & UX Improvements](#navigation--ux-improvements)
3. [Consistency Issues](#consistency-issues)
4. [Missing Functionality](#missing-functionality)
5. [Code Quality Improvements](#code-quality-improvements)
6. [Implementation Roadmap](#implementation-roadmap)
7. [Testing Requirements](#testing-requirements)

---

## Current State Analysis

### Key Files Examined

**Layouts:**
- `app/views/layouts/site_admin.html.erb` - Main layout with Alpine.js
- `app/views/layouts/site_admin/_navigation.html.erb` - Sidebar navigation (355 lines)
- `app/views/layouts/site_admin/_header.html.erb` - Top header bar
- `app/views/layouts/site_admin/_flash.html.erb` - Flash message component

**Controllers:**
- 24 site_admin controllers identified
- Well-structured with concerns and security scoping
- Multi-tenant isolation properly implemented

**Views:**
- 90+ view templates across various features
- Mix of consistent and inconsistent patterns
- Dashboard has good structure (485 lines with rich features)

**Helpers:**
- `app/helpers/site_admin_helper.rb` - Flash classes, formatting, badges

### Current Navigation Structure

```
Dashboard
├── Listings (collapsible)
│   ├── All Listings
│   ├── Import/Export
│   ├── External Feeds
│   ├── Labels & Categories
│   ├── Search Settings
│   └── Embed Widgets
├── Leads & Messages (collapsible)
│   ├── Inbox
│   ├── Message History
│   ├── Contacts
│   ├── Email Templates
│   └── Support Tickets
├── Insights (collapsible)  ⚠️ TO BE REORGANIZED
│   ├── Analytics
│   ├── Activity Logs
│   ├── SEO Audit  ← MOVE to Site Design
│   └── Storage Stats  ← MOVE to Settings
├── Settings (collapsible)
│   ├── Team & Users
│   ├── Agency Profile
│   ├── Billing
│   ├── General Settings
│   ├── Notifications
│   ├── Social Links
│   ├── Domain
│   └── Setup Wizard
└── Site Design (collapsible)
    ├── Theme & Appearance
    ├── Pages
    ├── Media Library
    ├── Site Navigation
    ├── SEO
    └── View Site
```

### Page Header Patterns Observed

**Consistent Pattern (Most pages):**
```erb
<div class="max-w-7xl mx-auto">
  <div class="mb-6 flex justify-between items-center">
    <div>
      <h1 class="text-3xl font-bold text-gray-900">Title</h1>
      <p class="mt-2 text-gray-600">Description</p>
    </div>
    <div><!-- Action buttons --></div>
  </div>
</div>
```

**Inconsistent Variations:**
- Dashboard: `mb-4 md:mb-6` and `text-2xl md:text-3xl` (responsive)
- Properties: `mb-4 md:mb-6` (different spacing)
- Analytics: Different structure entirely
- Settings tabs: Case statement structure

---

## 1. Navigation & UX Improvements

### 1.1 Consolidate Insights Section

**Complexity:** Medium  
**Priority:** High  
**Estimated Hours:** 4-6

#### Current Issues
- "Insights" section mixes analytics with unrelated tools
- SEO Audit belongs conceptually with Site Design
- Storage Stats is more of a Settings/maintenance function

#### Changes Required

**File: `app/views/layouts/site_admin/_navigation.html.erb`**

1. **Move SEO Audit (lines 199-204):**
   - Remove from Insights section
   - Add to Site Design section (after "SEO" link, line 328)
   - Update Alpine.js state variable (currently `insightsOpen`)

2. **Move Storage Stats (lines 206-213):**
   - Remove from Insights section
   - Add to Settings section (after "Setup Wizard", line 281)
   - Update Alpine.js state variable

3. **Rename "Insights" to "Analytics":**
   - Update section button text (line 178)
   - Keep Analytics and Activity Logs only
   - Consider if Activity Logs should also move to Settings

#### Implementation Details

```erb
<!-- NEW INSIGHTS SECTION (SIMPLIFIED) -->
<div class="px-4 mb-4">
  <button @click="toggle('analyticsOpen')" class="...">
    <span>Analytics</span>
    <!-- ... -->
  </button>
  
  <div x-show="analyticsOpen" x-collapse>
    <%= link_to site_admin_analytics_path, ... do %>
      <!-- ... -->
      <span>Analytics</span>
    <% end %>
    
    <%= link_to site_admin_activity_logs_path, ... do %>
      <!-- ... -->
      <span>Activity Logs</span>
    <% end %>
  </div>
</div>

<!-- ADD TO SITE DESIGN SECTION -->
<!-- After SEO link (line 328) -->
<%= link_to site_admin_seo_audit_path, id: "tour-seo-audit", 
    class: "flex items-center px-4 py-2 rounded-lg hover:bg-gray-700 #{request.path.start_with?('/site_admin/seo_audit') ? 'bg-gray-700' : ''}" do %>
  <svg class="w-5 h-5 mr-3" fill="currentColor" viewBox="0 0 20 20">
    <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723..." clip-rule="evenodd"></path>
  </svg>
  <span>SEO Audit</span>
<% end %>

<!-- ADD TO SETTINGS SECTION -->
<!-- After Setup Wizard (line 281) -->
<%= link_to site_admin_storage_stats_path, id: "tour-storage", 
    class: "..." do %>
  <svg class="w-5 h-5 mr-3" fill="currentColor" viewBox="0 0 20 20">
    <path d="M3 12v3c0 1.657 3.134 3 7 3s7-1.343 7-3v-3..."></path>
  </svg>
  <span>Storage Stats</span>
<% end %>
```

#### Testing Requirements
- [ ] Verify all navigation links work correctly
- [ ] Test localStorage persistence for new section states
- [ ] Update guided tour if it references moved items
- [ ] Test mobile navigation

---

### 1.2 Add Breadcrumbs for Navigation Context

**Complexity:** Medium  
**Priority:** Medium  
**Estimated Hours:** 6-8

#### Current Issues
- No breadcrumb navigation on any pages
- Users lose context when navigating deep into sections
- Difficult to navigate back to parent sections

#### Solution Design

Create a flexible breadcrumb component that:
1. Auto-generates based on controller/action
2. Supports custom breadcrumb trails
3. Works with multi-level navigation
4. Responsive on mobile (collapses to parent only)

#### Implementation

**New Partial: `app/views/layouts/site_admin/_breadcrumbs.html.erb`**

```erb
<% if @breadcrumbs.present? %>
  <nav class="flex mb-4" aria-label="Breadcrumb">
    <ol class="inline-flex items-center space-x-1 md:space-x-3">
      <li class="inline-flex items-center">
        <%= link_to site_admin_root_path, 
            class: "inline-flex items-center text-sm font-medium text-gray-700 hover:text-blue-600" do %>
          <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z"></path>
          </svg>
          <span class="hidden md:inline">Dashboard</span>
        <% end %>
      </li>
      
      <% @breadcrumbs.each_with_index do |crumb, index| %>
        <li>
          <div class="flex items-center">
            <svg class="w-6 h-6 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
            </svg>
            <% if index == @breadcrumbs.length - 1 %>
              <span class="ml-1 text-sm font-medium text-gray-500 md:ml-2">
                <%= crumb[:label] %>
              </span>
            <% else %>
              <%= link_to crumb[:url], 
                  class: "ml-1 text-sm font-medium text-gray-700 hover:text-blue-600 md:ml-2" do %>
                <%= crumb[:label] %>
              <% end %>
            <% end %>
          </div>
        </li>
      <% end %>
    </ol>
  </nav>
<% end %>
```

**Helper Method: `app/helpers/site_admin_helper.rb`**

```ruby
# Set breadcrumbs for current page
# @param breadcrumbs [Array<Hash>] Array of {label: String, url: String}
def set_breadcrumbs(*breadcrumbs)
  @breadcrumbs = breadcrumbs
end

# Auto-generate breadcrumbs based on controller/action
def auto_breadcrumbs
  return @breadcrumbs if @breadcrumbs.present?
  
  controller_name = params[:controller].split('/').last
  action_name = params[:action]
  
  crumbs = []
  
  # Add controller-level breadcrumb
  if controller_name != 'dashboard'
    crumbs << {
      label: controller_name.titleize,
      url: url_for(controller: params[:controller], action: :index, only_path: true)
    }
  end
  
  # Add action-level breadcrumb if not index
  if action_name != 'index' && %w[new edit show].include?(action_name)
    crumbs << {
      label: action_name.titleize,
      url: request.path
    }
  end
  
  @breadcrumbs = crumbs
end
```

**Update Layout: `app/views/layouts/site_admin.html.erb`**

```erb
<!-- After flash messages (line 130) -->
<%= render 'layouts/site_admin/breadcrumbs' %>
```

#### Example Usage in Controllers

```ruby
# PropsController
def show
  set_breadcrumbs(
    { label: 'Properties', url: site_admin_props_path },
    { label: @prop.reference, url: site_admin_prop_path(@prop) }
  )
end

def edit_photos
  set_breadcrumbs(
    { label: 'Properties', url: site_admin_props_path },
    { label: @prop.reference, url: site_admin_prop_path(@prop) },
    { label: 'Edit Photos', url: edit_photos_site_admin_prop_path(@prop) }
  )
end
```

#### Files to Update
- [ ] `app/views/layouts/site_admin.html.erb` - Add breadcrumb render
- [ ] `app/views/layouts/site_admin/_breadcrumbs.html.erb` - New partial
- [ ] `app/helpers/site_admin_helper.rb` - Add breadcrumb helpers
- [ ] All site_admin controllers - Add breadcrumb calls in actions

---

### 1.3 Improve Sidebar State Management

**Complexity:** Small  
**Priority:** Low  
**Estimated Hours:** 2-3

#### Current Implementation

Uses localStorage to persist sidebar section states:
```javascript
x-data="{
  listingsOpen: localStorage.getItem('nav_listingsOpen') !== 'false',
  leadsOpen: localStorage.getItem('nav_leadsOpen') !== 'false',
  siteDesignOpen: localStorage.getItem('nav_siteDesignOpen') !== 'false',
  insightsOpen: localStorage.getItem('nav_insightsOpen') !== 'false',
  settingsOpen: localStorage.getItem('nav_settingsOpen') === 'true',
  ...
}"
```

#### Issues
- Inconsistent default states (`!== 'false'` vs `=== 'true'`)
- No way to auto-expand current section
- Settings defaults to closed (should open if on settings page)

#### Improvements

**File: `app/views/layouts/site_admin/_navigation.html.erb`**

```erb
<aside id="tour-sidebar" 
       x-data="navState()"
       x-init="initNavState('<%= params[:controller] %>')">
  <!-- ... -->
</aside>

<script>
function navState() {
  return {
    listingsOpen: false,
    leadsOpen: false,
    analyticsOpen: false, // renamed from insightsOpen
    settingsOpen: false,
    siteDesignOpen: false,
    
    toggle(key) {
      this[key] = !this[key];
      localStorage.setItem('nav_' + key, this[key]);
    },
    
    initNavState(controller) {
      // Load from localStorage or use smart defaults
      const sections = ['listingsOpen', 'leadsOpen', 'analyticsOpen', 'settingsOpen', 'siteDesignOpen'];
      
      sections.forEach(section => {
        const stored = localStorage.getItem('nav_' + section);
        if (stored !== null) {
          this[section] = stored === 'true';
        } else {
          // Smart defaults based on current page
          this[section] = this.shouldOpenSection(section, controller);
        }
      });
    },
    
    shouldOpenSection(section, controller) {
      const sectionMap = {
        listingsOpen: ['site_admin/props', 'site_admin/property_import_export', 'site_admin/external_feeds', 'site_admin/properties/settings', 'site_admin/widgets'],
        leadsOpen: ['site_admin/inbox', 'site_admin/messages', 'site_admin/contacts', 'site_admin/email_templates', 'site_admin/support_tickets'],
        analyticsOpen: ['site_admin/analytics', 'site_admin/activity_logs'],
        settingsOpen: ['site_admin/users', 'site_admin/agency', 'site_admin/billing', 'site_admin/website/settings', 'site_admin/domains', 'site_admin/onboarding', 'site_admin/storage_stats'],
        siteDesignOpen: ['site_admin/pages', 'site_admin/media_library', 'site_admin/seo_audit']
      };
      
      const controllers = sectionMap[section] || [];
      return controllers.includes(controller);
    }
  }
}
</script>
```

---

## 2. Consistency Issues

### 2.1 Standardize Page Headers

**Complexity:** Small  
**Priority:** High  
**Estimated Hours:** 4-6

#### Current Inconsistencies

**Responsive spacing variations:**
- Dashboard: `mb-4 md:mb-6`, `text-2xl md:text-3xl`
- Users: `mb-6`, `text-3xl`
- Properties: `mb-4 md:mb-6`, `text-2xl md:text-3xl`
- Pages: `mb-6`, `text-3xl`

**Different structures:**
- Most pages: flex with justify-between
- Analytics: Different period selector
- Settings: Case statement with tab-specific titles

#### Standard Pattern to Implement

**New Partial: `app/views/site_admin/shared/_page_header.html.erb`**

```erb
<%
# Usage:
# <%= render 'site_admin/shared/page_header',
#     title: 'Properties',
#     description: 'Manage your property listings',
#     actions: capture { %>
#       <%= link_to ... %>
#     <% } %>
%>
<div class="mb-4 md:mb-6">
  <div class="<%= local_assigns[:container_class] || 'max-w-7xl mx-auto' %>">
    <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-4">
      <div class="flex-1">
        <h1 class="text-2xl md:text-3xl font-bold text-gray-900">
          <%= title %>
        </h1>
        <% if local_assigns[:description].present? %>
          <p class="mt-1 md:mt-2 text-sm md:text-base text-gray-600">
            <%= description %>
          </p>
        <% end %>
        <% if local_assigns[:breadcrumbs] %>
          <!-- Future: breadcrumbs integration -->
        <% end %>
      </div>
      
      <% if local_assigns[:actions].present? %>
        <div class="flex-shrink-0 flex gap-2">
          <%= actions %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

#### Files to Update (17 pages)

**Priority 1 - High Traffic Pages:**
- [ ] `app/views/site_admin/dashboard/index.html.erb`
- [ ] `app/views/site_admin/props/index.html.erb`
- [ ] `app/views/site_admin/messages/index.html.erb`
- [ ] `app/views/site_admin/pages/index.html.erb`
- [ ] `app/views/site_admin/users/index.html.erb`

**Priority 2 - Medium Traffic:**
- [ ] `app/views/site_admin/contacts/index.html.erb`
- [ ] `app/views/site_admin/analytics/show.html.erb`
- [ ] `app/views/site_admin/email_templates/index.html.erb`
- [ ] `app/views/site_admin/media_library/index.html.erb`
- [ ] `app/views/site_admin/activity_logs/index.html.erb`

**Priority 3 - Lower Traffic:**
- [ ] `app/views/site_admin/seo_audit/index.html.erb`
- [ ] `app/views/site_admin/storage_stats/show.html.erb`
- [ ] `app/views/site_admin/widgets/index.html.erb`
- [ ] `app/views/site_admin/support_tickets/index.html.erb`
- [ ] `app/views/site_admin/agency/edit.html.erb`
- [ ] `app/views/site_admin/billing/show.html.erb`
- [ ] `app/views/site_admin/domains/show.html.erb`

#### Example Migration

**Before (props/index.html.erb):**
```erb
<div class="max-w-7xl mx-auto">
  <div class="mb-4 md:mb-6 flex justify-between items-center">
    <div>
      <h1 class="text-2xl md:text-3xl font-bold text-gray-900">Properties</h1>
      <p class="mt-1 md:mt-2 text-sm md:text-base text-gray-600">
        <%= @pagy.count %> properties for <%= current_website.subdomain %>
      </p>
    </div>
    <div class="flex gap-2">
      <%= link_to ... %>
    </div>
  </div>
  <!-- ... rest of content ... -->
</div>
```

**After:**
```erb
<div class="max-w-7xl mx-auto">
  <%= render 'site_admin/shared/page_header',
      title: 'Properties',
      description: "#{@pagy.count} properties for #{current_website.subdomain}",
      actions: capture do %>
        <%= link_to site_admin_property_url_import_path, 
            class: "inline-flex items-center px-4 py-2 bg-gray-100..." do %>
          <svg class="w-5 h-5 mr-2">...</svg>
          Import URL
        <% end %>
        <%= link_to new_site_admin_prop_path, 
            class: "inline-flex items-center px-4 py-2 bg-blue-600..." do %>
          <svg class="w-5 h-5 mr-2">...</svg>
          Add Property
        <% end %>
      <% end %>
  
  <!-- ... rest of content ... -->
</div>
```

---

### 2.2 Create Consistent Flash Message Components

**Complexity:** Small  
**Priority:** Medium  
**Estimated Hours:** 2-3

#### Current Implementation

**File: `app/views/layouts/site_admin/_flash.html.erb`**

- Works well with icons
- Uses helper method `flash_class` for styling
- No dismiss button
- No auto-dismiss

#### Improvements Needed

1. **Add dismiss button with Alpine.js**
2. **Add auto-dismiss option (optional)**
3. **Support for multiple flash messages**
4. **Add animation transitions**

**Enhanced Version:**

```erb
<div x-data="{ flashMessages: [] }" 
     x-init="
       <% flash.each do |type, message| %>
         flashMessages.push({
           id: Date.now() + Math.random(),
           type: '<%= type %>',
           message: '<%= j message %>',
           autoDismiss: <%= %w[notice success].include?(type.to_s) %>
         });
       <% end %>
       
       // Auto-dismiss success/notice messages after 5 seconds
       flashMessages.forEach((flash, index) => {
         if (flash.autoDismiss) {
           setTimeout(() => {
             flashMessages.splice(index, 1);
           }, 5000);
         }
       });
     ">
  
  <template x-for="flash in flashMessages" :key="flash.id">
    <div x-show="true"
         x-transition:enter="transition ease-out duration-300"
         x-transition:enter-start="opacity-0 transform translate-y-2"
         x-transition:enter-end="opacity-100 transform translate-y-0"
         x-transition:leave="transition ease-in duration-200"
         x-transition:leave-start="opacity-100"
         x-transition:leave-end="opacity-0"
         class="mb-4 p-4 rounded-lg border-l-4"
         :class="{
           'bg-blue-100 border-blue-500 text-blue-700': flash.type === 'notice',
           'bg-green-100 border-green-500 text-green-700': flash.type === 'success',
           'bg-red-100 border-red-500 text-red-700': flash.type === 'alert' || flash.type === 'error',
           'bg-yellow-100 border-yellow-500 text-yellow-700': flash.type === 'warning'
         }"
         role="alert">
      <div class="flex items-center justify-between">
        <div class="flex items-center flex-1">
          <div class="flex-shrink-0">
            <!-- Success/Notice Icon -->
            <svg x-show="flash.type === 'success' || flash.type === 'notice'"
                 class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
            </svg>
            <!-- Error/Alert Icon -->
            <svg x-show="flash.type === 'alert' || flash.type === 'error'"
                 class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
            </svg>
            <!-- Warning Icon -->
            <svg x-show="flash.type === 'warning'"
                 class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm font-medium" x-text="flash.message"></p>
          </div>
        </div>
        <button @click="flashMessages = flashMessages.filter(f => f.id !== flash.id)"
                class="ml-4 flex-shrink-0 inline-flex text-current hover:opacity-75 focus:outline-none">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
          </svg>
        </button>
      </div>
    </div>
  </template>
</div>
```

---

### 2.3 Standardize Empty States

**Complexity:** Small  
**Priority:** Medium  
**Estimated Hours:** 3-4

#### Current Variations

Different empty state implementations across pages:
- Properties: SVG icon + message + search tip
- Users: SVG + message + CTA link
- Pages: Different SVG + message only

#### Standard Component

**New Partial: `app/views/site_admin/shared/_empty_state.html.erb`**

```erb
<%
# Usage:
# <%= render 'site_admin/shared/empty_state',
#     icon: 'property', # or 'user', 'page', 'message', etc.
#     title: 'No properties found',
#     message: 'Get started by adding your first property',
#     action: { text: 'Add Property', url: new_site_admin_prop_path, class: '...' }
%>
<div class="text-center py-12">
  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <%= render "site_admin/shared/icons/#{icon}" %>
  </svg>
  
  <h3 class="mt-2 text-sm font-medium text-gray-900">
    <%= title %>
  </h3>
  
  <% if local_assigns[:message].present? %>
    <p class="mt-1 text-sm text-gray-500">
      <%= message %>
    </p>
  <% end %>
  
  <% if local_assigns[:action].present? %>
    <div class="mt-6">
      <%= link_to action[:text], action[:url], 
          class: action[:class] || 'inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700' %>
    </div>
  <% end %>
  
  <% if local_assigns[:secondary_action].present? %>
    <div class="mt-2">
      <%= link_to secondary_action[:text], secondary_action[:url], 
          class: secondary_action[:class] || 'text-sm text-blue-600 hover:text-blue-800' %>
    </div>
  <% end %>
</div>
```

**Icon Partials: `app/views/site_admin/shared/icons/`**

Create reusable SVG icon partials:
- `_property.html.erb`
- `_user.html.erb`
- `_page.html.erb`
- `_message.html.erb`
- `_contact.html.erb`

---

## 3. Missing Functionality

### 3.1 Dashboard Quick Actions Enhancement

**Complexity:** Small  
**Priority:** Medium  
**Estimated Hours:** 2-3

#### Current State

Dashboard has 6 quick actions:
1. Add Property
2. Upload Media
3. Messages (with unread count)
4. Edit Theme
5. Edit Pages
6. View Site

#### Proposed Enhancements

**Make quick actions configurable per user role:**

```ruby
# app/models/concerns/site_admin/quick_actions.rb
module SiteAdmin
  module QuickActions
    def available_quick_actions
      actions = []
      
      # Always available
      actions << {
        id: 'view_site',
        icon: 'external_link',
        label: 'View Site',
        color: 'indigo',
        url: root_path,
        target: '_blank'
      }
      
      # Role-based actions
      if can_manage_properties?
        actions << {
          id: 'add_property',
          icon: 'plus',
          label: 'Add Property',
          color: 'blue',
          url: new_site_admin_prop_path
        }
      end
      
      if can_manage_media?
        actions << {
          id: 'upload_media',
          icon: 'image',
          label: 'Upload Media',
          color: 'green',
          url: site_admin_media_library_index_path
        }
      end
      
      # Messages (with badge)
      actions << {
        id: 'messages',
        icon: 'mail',
        label: 'Messages',
        color: 'purple',
        url: site_admin_messages_path,
        badge: unread_messages_count
      }
      
      if can_manage_design?
        actions << {
          id: 'edit_theme',
          icon: 'palette',
          label: 'Edit Theme',
          color: 'pink',
          url: site_admin_website_settings_tab_path('appearance')
        }
        
        actions << {
          id: 'edit_pages',
          icon: 'document',
          label: 'Edit Pages',
          color: 'yellow',
          url: site_admin_pages_path
        }
      end
      
      actions
    end
  end
end
```

**Enhanced View:**

```erb
<!-- Quick Actions -->
<div class="mb-6 md:mb-8">
  <div class="bg-white rounded-lg shadow p-4 md:p-6">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-sm font-semibold text-gray-500 uppercase tracking-wider">
        Quick Actions
      </h2>
      <button @click="editQuickActions = !editQuickActions" 
              class="text-xs text-gray-500 hover:text-gray-700">
        <svg class="w-4 h-4 inline"><!-- settings icon --></svg>
        Customize
      </button>
    </div>
    
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
      <% @quick_actions.each do |action| %>
        <%= link_to action[:url], 
            target: action[:target],
            class: "flex flex-col items-center justify-center p-4 rounded-lg border-2 border-dashed border-gray-200 hover:border-#{action[:color]}-400 hover:bg-#{action[:color]}-50 transition-colors group relative" do %>
          
          <% if action[:badge].to_i > 0 %>
            <span class="absolute top-2 right-2 bg-red-500 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
              <%= action[:badge] > 9 ? '9+' : action[:badge] %>
            </span>
          <% end %>
          
          <div class="w-10 h-10 rounded-full bg-<%= action[:color] %>-100 group-hover:bg-<%= action[:color] %>-200 flex items-center justify-center mb-2">
            <%= render "site_admin/shared/icons/#{action[:icon]}", 
                class: "w-5 h-5 text-#{action[:color]}-600" %>
          </div>
          <span class="text-sm font-medium text-gray-700 group-hover:text-<%= action[:color] %>-700 text-center">
            <%= action[:label] %>
          </span>
        <% end %>
      <% end %>
    </div>
  </div>
</div>
```

---

### 3.2 Global Search Within Admin

**Complexity:** Large  
**Priority:** High  
**Estimated Hours:** 12-16

#### Requirements

**Search Scope:**
- Properties (by reference, title, address)
- Pages (by slug, title)
- Users (by email, name)
- Messages (by sender email, content preview)
- Contacts (by name, email)

#### Implementation Approach

**1. Add PgSearch gem (if not already installed)**

```ruby
# Gemfile
gem 'pg_search'
```

**2. Create Global Search Concern**

```ruby
# app/models/concerns/site_admin/global_searchable.rb
module SiteAdmin
  module GlobalSearchable
    extend ActiveSupport::Concern
    
    included do
      include PgSearch::Model
      
      pg_search_scope :site_admin_search,
        against: search_attributes,
        using: {
          tsearch: { prefix: true }
        }
    end
    
    class_methods do
      def search_attributes
        raise NotImplementedError, 'Subclass must define search_attributes'
      end
      
      def search_result_type
        name.demodulize.underscore.humanize
      end
    end
    
    def search_result_title
      raise NotImplementedError, 'Subclass must implement search_result_title'
    end
    
    def search_result_url
      raise NotImplementedError, 'Subclass must implement search_result_url'
    end
  end
end
```

**3. Add to Models**

```ruby
# app/models/pwb/listed_property.rb
class Pwb::ListedProperty < ApplicationRecord
  include SiteAdmin::GlobalSearchable
  
  def self.search_attributes
    [:reference, :title, :street_address, :city]
  end
  
  def search_result_title
    title.presence || reference
  end
  
  def search_result_subtitle
    [street_address, city].compact.join(', ')
  end
  
  def search_result_url
    Rails.application.routes.url_helpers.site_admin_prop_path(self)
  end
  
  def search_result_icon
    'property'
  end
end

# Similar for Page, User, Message, Contact...
```

**4. Search Service**

```ruby
# app/services/site_admin/global_search_service.rb
module SiteAdmin
  class GlobalSearchService
    def initialize(website_id, query)
      @website_id = website_id
      @query = query.strip
    end
    
    def search
      return [] if @query.blank? || @query.length < 2
      
      results = []
      
      # Search properties
      results += search_model(Pwb::ListedProperty, limit: 5)
      
      # Search pages
      results += search_model(Pwb::Page, limit: 5)
      
      # Search users (via memberships)
      results += search_users(limit: 5)
      
      # Search messages
      results += search_model(Pwb::Message, limit: 5)
      
      # Search contacts
      results += search_model(Pwb::Contact, limit: 5)
      
      # Sort by relevance/type
      results.sort_by { |r| [r[:type], r[:title]] }
    end
    
    private
    
    def search_model(model_class, limit:)
      model_class
        .where(website_id: @website_id)
        .site_admin_search(@query)
        .limit(limit)
        .map do |record|
          {
            type: record.search_result_type,
            icon: record.search_result_icon,
            title: record.search_result_title,
            subtitle: record.search_result_subtitle,
            url: record.search_result_url
          }
        end
    end
    
    def search_users(limit:)
      # Search via user_memberships
      Pwb::User
        .joins(:user_memberships)
        .where(user_memberships: { website_id: @website_id })
        .where("email ILIKE ? OR first_names ILIKE ? OR last_names ILIKE ?", 
               "%#{@query}%", "%#{@query}%", "%#{@query}%")
        .limit(limit)
        .map do |user|
          {
            type: 'User',
            icon: 'user',
            title: user.email,
            subtitle: [user.first_names, user.last_names].compact.join(' '),
            url: Rails.application.routes.url_helpers.site_admin_user_path(user)
          }
        end
    end
  end
end
```

**5. Controller**

```ruby
# app/controllers/site_admin/search_controller.rb
module SiteAdmin
  class SearchController < SiteAdminController
    def index
      @query = params[:q].to_s
      @results = GlobalSearchService.new(current_website.id, @query).search
      
      respond_to do |format|
        format.html
        format.json { render json: @results }
      end
    end
  end
end
```

**6. UI Component in Header**

```erb
<!-- app/views/layouts/site_admin/_header.html.erb -->
<div x-data="{ 
  searchOpen: false, 
  searchQuery: '', 
  searchResults: [],
  searching: false
}"
     @keydown.window.prevent.ctrl.k="searchOpen = true; $nextTick(() => $refs.searchInput.focus())"
     @keydown.window.prevent.cmd.k="searchOpen = true; $nextTick(() => $refs.searchInput.focus())"
     @click.outside="searchOpen = false">
  
  <!-- Search Button -->
  <button @click="searchOpen = !searchOpen" 
          class="flex items-center px-3 py-2 text-sm text-gray-600 hover:text-gray-900 border border-gray-300 rounded-lg mr-4">
    <svg class="w-4 h-4 mr-2"><!-- search icon --></svg>
    Search
    <span class="ml-2 text-xs text-gray-400">⌘K</span>
  </button>
  
  <!-- Search Modal -->
  <div x-show="searchOpen"
       x-transition
       class="fixed inset-0 z-50 overflow-y-auto"
       style="display: none;">
    <div class="flex items-start justify-center min-h-screen pt-24 px-4">
      <div class="fixed inset-0 bg-gray-500 bg-opacity-75"></div>
      
      <div class="relative bg-white rounded-lg shadow-xl max-w-2xl w-full">
        <!-- Search Input -->
        <div class="p-4 border-b border-gray-200">
          <input x-ref="searchInput"
                 x-model.debounce.300ms="searchQuery"
                 @input="
                   searching = true;
                   fetch(`/site_admin/search?q=${encodeURIComponent(searchQuery)}`, {
                     headers: { 'Accept': 'application/json' }
                   })
                   .then(r => r.json())
                   .then(data => { 
                     searchResults = data;
                     searching = false;
                   })
                 "
                 type="text"
                 placeholder="Search properties, pages, users..."
                 class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        </div>
        
        <!-- Results -->
        <div class="max-h-96 overflow-y-auto">
          <template x-if="searching">
            <div class="p-8 text-center text-gray-500">Searching...</div>
          </template>
          
          <template x-if="!searching && searchResults.length === 0 && searchQuery.length > 0">
            <div class="p-8 text-center text-gray-500">No results found</div>
          </template>
          
          <template x-if="!searching && searchResults.length > 0">
            <ul class="divide-y divide-gray-100">
              <template x-for="result in searchResults" :key="result.url">
                <li>
                  <a :href="result.url" 
                     class="flex items-center p-4 hover:bg-gray-50">
                    <!-- Icon based on type -->
                    <div class="flex-shrink-0 mr-3">
                      <span x-text="result.type" 
                            class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800"></span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-900" x-text="result.title"></p>
                      <p class="text-xs text-gray-500" x-text="result.subtitle"></p>
                    </div>
                  </a>
                </li>
              </template>
            </ul>
          </template>
        </div>
        
        <!-- Footer with hints -->
        <div class="px-4 py-3 bg-gray-50 border-t border-gray-200 text-xs text-gray-500">
          <span class="font-medium">Tip:</span> Press <kbd class="px-2 py-0.5 bg-white border border-gray-300 rounded">↑</kbd> <kbd class="px-2 py-0.5 bg-white border border-gray-300 rounded">↓</kbd> to navigate, <kbd class="px-2 py-0.5 bg-white border border-gray-300 rounded">ESC</kbd> to close
        </div>
      </div>
    </div>
  </div>
</div>
```

**7. Routes**

```ruby
# config/routes.rb
namespace :site_admin do
  get 'search', to: 'search#index'
  # ...
end
```

#### Files to Create/Update
- [ ] `app/models/concerns/site_admin/global_searchable.rb`
- [ ] `app/services/site_admin/global_search_service.rb`
- [ ] `app/controllers/site_admin/search_controller.rb`
- [ ] `app/views/site_admin/search/index.html.erb`
- [ ] `app/views/layouts/site_admin/_header.html.erb` (update)
- [ ] Update models: ListedProperty, Page, User, Message, Contact
- [ ] Add routes

---

## 4. Code Quality Improvements

### 4.1 Refactor Settings Tabs Architecture

**Complexity:** Medium  
**Priority:** Medium  
**Estimated Hours:** 6-8

#### Current Issues

**File: `app/views/site_admin/website/settings/show.html.erb`**

Uses a case statement to render different partials:
```erb
<% case @tab %>
<% when 'general' %>
  <%= render 'general_tab' %>
<% when 'appearance' %>
  <%= render 'appearance_tab' %>
...
<% end %>
```

Problems:
1. Not scalable for adding new tabs
2. Duplication in header logic
3. Hard to add tab-specific JavaScript/CSS
4. No clear tab registration mechanism

#### Proposed Solution

**1. Tab Registry Pattern**

```ruby
# app/models/site_admin/settings_tab.rb
module SiteAdmin
  class SettingsTab
    attr_reader :id, :title, :description, :icon, :partial, :category
    
    def initialize(id:, title:, description:, icon:, partial:, category: :general)
      @id = id
      @title = title
      @description = description
      @icon = icon
      @partial = partial
      @category = category
    end
    
    # Registry of all tabs
    def self.all
      @tabs ||= []
    end
    
    def self.register(tab)
      all << tab
    end
    
    def self.find(id)
      all.find { |tab| tab.id.to_s == id.to_s }
    end
    
    def self.by_category
      all.group_by(&:category)
    end
    
    # Default tabs
    register new(
      id: :general,
      title: 'General Settings',
      description: 'Configure basic website settings',
      icon: 'cog',
      partial: 'general_tab',
      category: :general
    )
    
    register new(
      id: :appearance,
      title: 'Theme & Appearance',
      description: "Customize your site's look and feel",
      icon: 'palette',
      partial: 'appearance_tab',
      category: :design
    )
    
    register new(
      id: :navigation,
      title: 'Site Navigation',
      description: 'Manage your site navigation menus',
      icon: 'menu',
      partial: 'navigation_tab',
      category: :design
    )
    
    register new(
      id: :seo,
      title: 'SEO Settings',
      description: 'Optimize your site for search engines',
      icon: 'search',
      partial: 'seo_tab',
      category: :marketing
    )
    
    register new(
      id: :social,
      title: 'Social Links',
      description: 'Add links to your social media profiles',
      icon: 'share',
      partial: 'social_tab',
      category: :marketing
    )
    
    register new(
      id: :notifications,
      title: 'Notification Settings',
      description: 'Configure email and notification preferences',
      icon: 'bell',
      partial: 'notifications_tab',
      category: :general
    )
    
    register new(
      id: :search,
      title: 'Search Settings',
      description: 'Configure property search options and filters',
      icon: 'filter',
      partial: 'search_tab',
      category: :advanced
    )
  end
end
```

**2. Controller**

```ruby
# app/controllers/site_admin/website/settings_controller.rb
module SiteAdmin
  module Website
    class SettingsController < SiteAdminController
      def show
        @tab_id = params[:tab] || 'general'
        @tab = SiteAdmin::SettingsTab.find(@tab_id)
        
        if @tab.nil?
          redirect_to site_admin_website_settings_path(tab: 'general'), 
                      alert: 'Tab not found'
          return
        end
        
        @tabs_by_category = SiteAdmin::SettingsTab.by_category
      end
      
      def update
        # Handle form submission for any tab
        # ...
      end
    end
  end
end
```

**3. View with Tab Navigation**

```erb
<!-- app/views/site_admin/website/settings/show.html.erb -->
<div class="max-w-7xl mx-auto">
  <%= render 'site_admin/shared/page_header',
      title: @tab.title,
      description: @tab.description %>
  
  <!-- Tab Navigation -->
  <div class="bg-white rounded-lg shadow mb-6">
    <div class="border-b border-gray-200">
      <nav class="-mb-px flex space-x-8 px-6" aria-label="Tabs">
        <% @tabs_by_category.each do |category, tabs| %>
          <!-- Category Group -->
          <div class="flex items-center space-x-2 py-4 border-b-2 border-transparent text-xs font-medium text-gray-400 uppercase tracking-wider">
            <%= category.to_s.titleize %>
          </div>
          
          <% tabs.each do |tab| %>
            <%= link_to site_admin_website_settings_tab_path(tab.id),
                class: "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm #{@tab.id == tab.id ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}" do %>
              <div class="flex items-center">
                <%= render "site_admin/shared/icons/#{tab.icon}", class: "w-4 h-4 mr-2" %>
                <%= tab.title %>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </nav>
    </div>
  </div>
  
  <!-- Tab Content -->
  <div class="bg-white rounded-lg shadow overflow-hidden">
    <%= render "site_admin/website/settings/#{@tab.partial}" %>
  </div>
</div>
```

**Benefits:**
1. Easy to add new tabs (just register them)
2. Tabs can be organized by category
3. Cleaner, more maintainable code
4. Tab metadata in one place
5. Can add permissions per tab later
6. Can add JavaScript/CSS per tab

---

### 4.2 Feature Gating Spec Coverage

**Complexity:** Medium  
**Priority:** Low  
**Estimated Hours:** 8-10

#### Current State

No feature gating system found in codebase search.
Need to implement feature flags for:
- Subscription-based features
- Beta features
- A/B testing
- Gradual rollouts

#### Implementation

**1. Use Flipper Gem**

```ruby
# Gemfile
gem 'flipper'
gem 'flipper-active_record'
gem 'flipper-ui'
```

**2. Installation**

```bash
rails generate flipper:active_record
rails db:migrate
```

**3. Configuration**

```ruby
# config/initializers/flipper.rb
require 'flipper'
require 'flipper/adapters/active_record'

Flipper.configure do |config|
  config.default do
    adapter = Flipper::Adapters::ActiveRecord.new
    Flipper.new(adapter)
  end
end

# Common features
Flipper.register(:global_search) do |actor, context|
  # Enable for all premium subscriptions
  actor.respond_to?(:subscription) && 
    actor.subscription&.plan&.global_search_enabled?
end

Flipper.register(:seo_audit) do |actor, context|
  # Enable for all
  true
end

Flipper.register(:external_feeds) do |actor, context|
  # Enable based on plan
  actor.respond_to?(:subscription) && 
    actor.subscription&.plan&.external_feeds_enabled?
end
```

**4. Helper**

```ruby
# app/helpers/site_admin_helper.rb
module SiteAdminHelper
  def feature_enabled?(feature_name)
    Flipper.enabled?(feature_name, current_website)
  end
end
```

**5. Usage in Views**

```erb
<% if feature_enabled?(:global_search) %>
  <!-- Global search component -->
<% end %>

<% if feature_enabled?(:external_feeds) %>
  <%= link_to 'External Feeds', site_admin_external_feed_path, ... %>
<% end %>
```

**6. Controller**

```ruby
class SiteAdminController < ApplicationController
  def require_feature(feature_name)
    unless Flipper.enabled?(feature_name, current_website)
      redirect_to site_admin_root_path, 
                  alert: "This feature is not available on your current plan."
    end
  end
end

# Usage in specific controllers
class SiteAdmin::ExternalFeedsController < SiteAdminController
  before_action -> { require_feature(:external_feeds) }
end
```

**7. Specs**

```ruby
# spec/features/site_admin/feature_gating_spec.rb
require 'rails_helper'

RSpec.describe 'Feature Gating', type: :feature do
  let(:website) { create(:website) }
  let(:user) { create(:user) }
  
  before do
    login_as(user, scope: :user)
  end
  
  context 'with basic plan' do
    before do
      website.subscription.update(plan: create(:plan, :basic))
    end
    
    it 'hides global search' do
      visit site_admin_root_path
      expect(page).not_to have_content('Search')
    end
    
    it 'blocks access to external feeds' do
      visit site_admin_external_feed_path
      expect(page).to have_content('not available on your current plan')
    end
  end
  
  context 'with premium plan' do
    before do
      website.subscription.update(plan: create(:plan, :premium))
    end
    
    it 'shows global search' do
      visit site_admin_root_path
      expect(page).to have_content('Search')
    end
    
    it 'allows access to external feeds' do
      visit site_admin_external_feed_path
      expect(page).to have_content('External Feeds')
    end
  end
end
```

---

## 5. Implementation Roadmap

### Phase 1: Quick Wins (Week 1)
**Goal:** Immediate UX improvements with minimal risk

**Priority Tasks:**
1. ✅ Standardize page headers (4-6 hours)
   - Create shared partial
   - Update top 5 high-traffic pages
   
2. ✅ Enhance flash messages (2-3 hours)
   - Add dismiss button
   - Add auto-dismiss
   - Add animations

3. ✅ Consolidate Insights navigation (4-6 hours)
   - Move SEO Audit to Site Design
   - Move Storage Stats to Settings
   - Rename to Analytics

**Total: 10-15 hours**

---

### Phase 2: Navigation Improvements (Week 2)
**Goal:** Better navigation and context

**Priority Tasks:**
1. ✅ Add breadcrumbs (6-8 hours)
   - Create breadcrumb component
   - Add helper methods
   - Update controllers

2. ✅ Improve sidebar state management (2-3 hours)
   - Smart auto-expand based on current page
   - Fix localStorage inconsistencies

3. ✅ Update remaining page headers (3-4 hours)
   - Update medium and low traffic pages
   - Ensure consistency

**Total: 11-15 hours**

---

### Phase 3: New Features (Week 3-4)
**Goal:** Add missing functionality

**Priority Tasks:**
1. ✅ Global search (12-16 hours)
   - Install pg_search
   - Create search service
   - Build UI component
   - Add keyboard shortcuts

2. ✅ Dashboard quick actions enhancement (2-3 hours)
   - Make configurable
   - Add role-based actions

3. ✅ Standardize empty states (3-4 hours)
   - Create shared component
   - Update all pages

**Total: 17-23 hours**

---

### Phase 4: Code Quality (Week 5)
**Goal:** Refactor and improve maintainability

**Priority Tasks:**
1. ✅ Refactor settings tabs (6-8 hours)
   - Create tab registry
   - Update controller
   - Improve view

2. ✅ Feature gating implementation (8-10 hours)
   - Install Flipper
   - Configure features
   - Add specs
   - Update views/controllers

**Total: 14-18 hours**

---

### Phase 5: Testing & Documentation (Week 6)
**Goal:** Ensure quality and maintainability

**Priority Tasks:**
1. ✅ Write feature specs (8-10 hours)
   - Navigation tests
   - Breadcrumb tests
   - Search tests
   - Feature gating tests

2. ✅ Update documentation (4-6 hours)
   - Update README
   - Add component usage docs
   - Document patterns

3. ✅ Bug fixes and polish (6-8 hours)
   - Fix any issues found in testing
   - Polish UI/UX
   - Performance optimization

**Total: 18-24 hours**

---

## 6. Testing Requirements

### Unit Tests
- [ ] Breadcrumb helper methods
- [ ] Flash message rendering
- [ ] Settings tab registry
- [ ] Search service

### Integration Tests
- [ ] Navigation state persistence
- [ ] Search results
- [ ] Feature gating

### Feature Specs
- [ ] Full navigation flow
- [ ] Breadcrumb navigation
- [ ] Global search with keyboard shortcuts
- [ ] Quick actions functionality
- [ ] Feature gating for different plans

### Accessibility Tests
- [ ] Keyboard navigation
- [ ] Screen reader support
- [ ] ARIA labels
- [ ] Color contrast

---

## Summary

**Total Estimated Hours:** 70-95 hours  
**Estimated Timeline:** 6 weeks (part-time) or 2-3 weeks (full-time)

**Priority Order:**
1. **High Priority** (Week 1-2): Navigation consolidation, page headers, breadcrumbs
2. **Medium Priority** (Week 3-4): Global search, empty states, dashboard enhancements
3. **Low Priority** (Week 5-6): Settings refactor, feature gating, documentation

**Risk Assessment:**
- **Low Risk:** Page headers, flash messages, empty states
- **Medium Risk:** Breadcrumbs, navigation changes, settings refactor
- **Higher Risk:** Global search (requires PgSearch), feature gating (new dependency)

**Dependencies:**
- PgSearch gem for global search
- Flipper gem for feature gating
- No breaking changes to existing functionality

**Success Metrics:**
- Improved navigation (fewer clicks to common tasks)
- Better user context (breadcrumbs)
- Faster task completion (global search)
- Consistent UI/UX across all pages
- Better code maintainability
