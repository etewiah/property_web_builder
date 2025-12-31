# Site Admin Implementation Plan

Detailed technical implementation plan derived from the Product & UX Roadmap.

---

## Phase 1: Short-Term (0-4 weeks)

### 1.1 Dashboard Restructure

**Current State:**
- Controller: `app/controllers/site_admin/dashboard_controller.rb`
- View: `app/views/site_admin/dashboard/index.html.erb`
- Subscription notice exists but is passive

**Tasks:**

#### 1.1.1 Create Widget Components
```
Files to create:
- app/views/site_admin/dashboard/_widget_growth.html.erb
- app/views/site_admin/dashboard/_widget_engagement.html.erb
- app/views/site_admin/dashboard/_widget_readiness.html.erb
- app/views/site_admin/dashboard/_widget_subscription.html.erb
```

| Widget | Metrics | Data Source |
|--------|---------|-------------|
| Growth | Properties listed, New contacts (7d), Page views | `ListedProperty.count`, `Contact.recent`, Analytics |
| Engagement | Messages received, Response rate, Avg response time | `Message` aggregates |
| Readiness | Profile completion %, SEO score, Missing images | `Website` + `Agency` validation |
| Subscription | Plan name, Usage vs limits, Days remaining, CTA | `Subscription` model |

#### 1.1.2 Subscription Alert Component
```ruby
# app/helpers/site_admin/subscription_helper.rb
def subscription_alert_class(subscription)
  return 'alert-danger' if subscription.expired? || subscription.trial_ending_soon?
  return 'alert-warning' if subscription.usage_near_limit?
  'alert-info'
end
```

**Implementation:**
- Create `app/views/site_admin/shared/_subscription_alert.html.erb`
- Show blocking modal for expired subscriptions
- Add prominent CTA button linked to upgrade path

#### 1.1.3 Activity Feed Filters
```ruby
# app/controllers/site_admin/dashboard_controller.rb
def index
  @activities = current_website.activities
                  .by_type(params[:activity_type])
                  .recent(20)
  # ...
end
```

**UI:** Add filter tabs: All | Properties | Messages | Contacts | Settings

#### 1.1.4 Dashboard Caching
```ruby
# app/controllers/site_admin/dashboard_controller.rb
def index
  @stats = Rails.cache.fetch("dashboard_stats/#{current_website.id}", expires_in: 5.minutes) do
    {
      property_count: current_website.listed_properties.visible.count,
      message_count: current_website.messages.unread.count,
      contact_count: current_website.contacts.count
    }
  end
end
```

**Acceptance Tests:**
- [ ] Dashboard loads with ≤5 SQL queries (verify with Bullet)
- [ ] Subscription CTA visible above fold
- [ ] Activity filters work correctly
- [ ] Cache invalidates on relevant model changes

**Effort:** 3-5 days

---

### 1.2 Performance & N+1 Elimination

**Current State:**
- `ListedProperty` model has associations to `sale_listing` and `rental_listing`
- Some N+1 queries exist in property listings
- Bullet gem available but not enforced

**Tasks:**

#### 1.2.1 Add Eager Loading
```ruby
# app/controllers/site_admin/props_controller.rb
def index
  @properties = current_website.listed_properties
                  .includes(:sale_listing, :rental_listing, :photos)
                  .visible
                  .page(params[:page])
end
```

#### 1.2.2 Cache Expensive Counts
```ruby
# app/models/pwb/website.rb
def cached_property_count
  Rails.cache.fetch("#{cache_key_with_version}/property_count", expires_in: 10.minutes) do
    listed_properties.visible.count
  end
end

def cached_message_count
  Rails.cache.fetch("#{cache_key_with_version}/unread_messages", expires_in: 5.minutes) do
    messages.unread.count
  end
end
```

#### 1.2.3 Enforce Bullet in CI
```ruby
# config/environments/test.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.raise = true # Fail tests on N+1
end
```

```yaml
# .github/workflows/ci.yml (or equivalent)
- name: Run tests with Bullet
  env:
    BULLET_ENABLED: true
  run: bundle exec rspec
```

**Acceptance Tests:**
- [ ] No Bullet warnings on dashboard
- [ ] No Bullet warnings on properties index
- [ ] Admin TTFB reduced by ≥30% (measure before/after)

**Effort:** 2-3 days

---

### 1.3 Terminology Normalization

**Current State:**
- Mixed terminology across UI
- "Inbox" vs "Messages" inconsistency
- "Contents" is ambiguous

**Tasks:**

#### 1.3.1 Terminology Mapping

| Current | New | Rationale |
|---------|-----|-----------|
| Inbox | Unread Messages | Clearer intent |
| Messages | Conversations | Implies thread context |
| Contents | Page Sections | Describes function |
| Setup Wizard | Getting Started | Friendlier tone |
| Props | Properties | User-facing term |

#### 1.3.2 Files to Update

```
Navigation:
- app/views/site_admin/shared/_sidebar.html.erb
- app/views/site_admin/shared/_header.html.erb

Page Titles:
- app/views/site_admin/messages/index.html.erb
- app/views/site_admin/contents/index.html.erb
- app/views/site_admin/props/index.html.erb

Locale Files:
- config/locales/en.yml (site_admin section)
- config/locales/es.yml (site_admin section)
```

#### 1.3.3 Create Locale Structure
```yaml
# config/locales/site_admin/en.yml
en:
  site_admin:
    nav:
      dashboard: "Dashboard"
      properties: "Properties"
      conversations: "Conversations"
      unread_messages: "Unread Messages"
      page_sections: "Page Sections"
      getting_started: "Getting Started"
    messages:
      title: "Conversations"
      unread: "Unread Messages"
```

**Acceptance Tests:**
- [ ] Navigation uses consistent terminology
- [ ] Page titles match navigation labels
- [ ] No orphaned old terminology in UI

**Effort:** 1-2 days

---

### 1.4 Empty States & Inline Guidance

**Current State:**
- Some empty states exist but are minimal
- No educational content for new users

**Tasks:**

#### 1.4.1 Empty State Components

Create reusable empty state partial:
```erb
<%# app/views/site_admin/shared/_empty_state.html.erb %>
<div class="empty-state text-center py-12">
  <div class="empty-state-icon mb-4">
    <%= material_icon(icon, class: "text-gray-400 text-6xl") %>
  </div>
  <h3 class="text-lg font-medium text-gray-900 mb-2"><%= title %></h3>
  <p class="text-gray-500 mb-4 max-w-md mx-auto"><%= description %></p>
  <% if primary_action %>
    <%= link_to primary_action[:label], primary_action[:path],
        class: "btn btn-primary" %>
  <% end %>
  <% if help_link %>
    <p class="mt-4 text-sm">
      <a href="<%= help_link[:url] %>" class="text-blue-600 hover:underline">
        <%= help_link[:label] %>
      </a>
    </p>
  <% end %>
</div>
```

#### 1.4.2 Empty State Content

| Section | Icon | Title | Description | CTA |
|---------|------|-------|-------------|-----|
| Properties | `home` | No properties yet | Properties are the heart of your website. Add your first listing to start attracting buyers and renters. | Add Property |
| Messages | `mail` | No messages yet | When visitors contact you through your website, their messages will appear here. | View Contact Form |
| Contacts | `people` | No contacts yet | Contacts are automatically created when someone inquires about a property. You can also add contacts manually. | Add Contact |
| Media | `image` | No media uploaded | Upload images to use across your website - property photos, team photos, and content images. | Upload Media |

#### 1.4.3 Inline Guidance Tooltips
```erb
<%# Usage: %>
<%= info_tooltip("Why this matters",
    "Properties with complete information get 3x more inquiries.") %>
```

```ruby
# app/helpers/site_admin/guidance_helper.rb
module SiteAdmin::GuidanceHelper
  def info_tooltip(title, content)
    content_tag(:span, class: "info-tooltip",
                data: { tooltip: content, title: title }) do
      material_icon("info", class: "text-gray-400 text-sm cursor-help")
    end
  end
end
```

**Acceptance Tests:**
- [ ] Properties index shows empty state when no properties
- [ ] Messages index shows empty state when no messages
- [ ] Each empty state has primary CTA
- [ ] CTAs navigate to correct create/add flows

**Effort:** 2-3 days

---

## Phase 2: Medium-Term (1-3 months)

### 2.1 Properties UX Overhaul

**Current State:**
- Controller: `app/controllers/site_admin/props_controller.rb`
- Edit flow uses standard form
- No completeness indicator
- Limited bulk actions

**Tasks:**

#### 2.1.1 Property Completeness Indicator

```ruby
# app/models/concerns/property_completeness.rb
module PropertyCompleteness
  extend ActiveSupport::Concern

  REQUIRED_FIELDS = %i[title description price].freeze
  RECOMMENDED_FIELDS = %i[bedrooms bathrooms area photos].freeze

  def completeness_score
    required_score = REQUIRED_FIELDS.count { |f| send(f).present? }
    recommended_score = RECOMMENDED_FIELDS.count { |f| send(f).present? }

    required_weight = 0.6
    recommended_weight = 0.4

    ((required_score.to_f / REQUIRED_FIELDS.count) * required_weight +
     (recommended_score.to_f / RECOMMENDED_FIELDS.count) * recommended_weight) * 100
  end

  def completeness_status
    case completeness_score
    when 0..49 then :incomplete
    when 50..79 then :needs_work
    when 80..99 then :good
    else :complete
    end
  end

  def missing_fields
    (REQUIRED_FIELDS + RECOMMENDED_FIELDS).select { |f| send(f).blank? }
  end
end
```

#### 2.1.2 Status Badges Component
```erb
<%# app/views/site_admin/props/_status_badges.html.erb %>
<div class="flex gap-2">
  <% if property.for_sale? %>
    <span class="badge badge-green">For Sale</span>
  <% end %>
  <% if property.for_rent? %>
    <span class="badge badge-blue">For Rent</span>
  <% end %>
  <% unless property.visible? %>
    <span class="badge badge-gray">Draft</span>
  <% end %>
  <% if property.highlighted? %>
    <span class="badge badge-yellow">Featured</span>
  <% end %>
</div>
```

#### 2.1.3 Bulk Actions

```ruby
# app/controllers/site_admin/props_controller.rb
def bulk_action
  @properties = current_website.listed_properties.where(id: params[:property_ids])

  case params[:action_type]
  when 'publish'
    @properties.update_all(visible: true)
  when 'unpublish'
    @properties.update_all(visible: false)
  when 'delete'
    @properties.destroy_all
  when 'feature'
    @properties.update_all(highlighted: true)
  end

  redirect_to site_admin_props_path, notice: "#{@properties.count} properties updated"
end
```

```erb
<%# Bulk action UI %>
<form id="bulk-actions-form" data-controller="bulk-actions">
  <div class="bulk-actions-bar hidden" data-bulk-actions-target="bar">
    <span data-bulk-actions-target="count">0 selected</span>
    <select name="action_type" data-action="change->bulk-actions#execute">
      <option value="">Actions...</option>
      <option value="publish">Publish</option>
      <option value="unpublish">Unpublish</option>
      <option value="feature">Mark Featured</option>
      <option value="delete">Delete</option>
    </select>
  </div>
</form>
```

#### 2.1.4 Tabbed Edit Interface

```erb
<%# app/views/site_admin/props/edit.html.erb %>
<div data-controller="tabs">
  <nav class="tabs-nav">
    <button data-tabs-target="tab" data-tab="details" class="active">Details</button>
    <button data-tabs-target="tab" data-tab="pricing">Pricing</button>
    <button data-tabs-target="tab" data-tab="location">Location</button>
    <button data-tabs-target="tab" data-tab="photos">Photos</button>
    <button data-tabs-target="tab" data-tab="seo">SEO</button>
  </nav>

  <div data-tabs-target="panel" data-tab="details">
    <%= render 'form_details', property: @property %>
  </div>
  <!-- Additional panels... -->
</div>
```

#### 2.1.5 Sticky Save Bar

```erb
<%# app/views/site_admin/props/_sticky_save_bar.html.erb %>
<div class="sticky-save-bar" data-controller="sticky-save" data-sticky-save-target="bar">
  <div class="flex items-center justify-between">
    <div class="unsaved-indicator hidden" data-sticky-save-target="indicator">
      <span class="text-amber-600">Unsaved changes</span>
    </div>
    <div class="flex gap-2">
      <%= link_to "Cancel", site_admin_props_path, class: "btn btn-secondary" %>
      <%= submit_tag "Save Draft", name: "draft", class: "btn btn-secondary" %>
      <%= submit_tag "Save & Publish", name: "publish", class: "btn btn-primary" %>
    </div>
  </div>
</div>
```

**Acceptance Tests:**
- [ ] Completeness indicator shows on property list and edit
- [ ] Status badges display correctly for all states
- [ ] Bulk actions work for publish/unpublish/delete
- [ ] Tab navigation persists form state
- [ ] Sticky bar shows unsaved changes warning

**Effort:** 8-10 days

---

### 2.2 Pages & CMS Improvements

**Current State:**
- Controller: `app/controllers/site_admin/pages_controller.rb`
- Flat page list
- Limited SEO fields

**Tasks:**

#### 2.2.1 Hierarchical Page Tree

```ruby
# app/models/pwb/page.rb
class Page < ApplicationRecord
  belongs_to :parent, class_name: 'Page', optional: true
  has_many :children, class_name: 'Page', foreign_key: 'parent_id'

  scope :roots, -> { where(parent_id: nil) }

  def ancestors
    parent ? parent.ancestors + [parent] : []
  end

  def depth
    ancestors.count
  end
end
```

```erb
<%# app/views/site_admin/pages/_page_tree.html.erb %>
<ul class="page-tree">
  <% pages.each do |page| %>
    <li class="page-tree-item" style="padding-left: <%= page.depth * 20 %>px">
      <div class="flex items-center justify-between">
        <span><%= page.title %></span>
        <div class="flex gap-2">
          <%= link_to "Edit", edit_site_admin_page_path(page), class: "text-sm" %>
          <%= link_to "View", page.public_path, target: "_blank", class: "text-sm" %>
        </div>
      </div>
      <% if page.children.any? %>
        <%= render 'page_tree', pages: page.children %>
      <% end %>
    </li>
  <% end %>
</ul>
```

#### 2.2.2 SEO Completeness Indicator

```ruby
# app/models/concerns/seo_completeness.rb
module SeoCompleteness
  extend ActiveSupport::Concern

  SEO_FIELDS = {
    meta_title: { max_length: 60, weight: 0.3 },
    meta_description: { max_length: 160, weight: 0.3 },
    og_image: { weight: 0.2 },
    canonical_url: { weight: 0.1 },
    structured_data: { weight: 0.1 }
  }.freeze

  def seo_score
    SEO_FIELDS.sum do |field, config|
      value = send(field)
      if value.present?
        if config[:max_length] && value.length > config[:max_length]
          config[:weight] * 0.5 # Partial credit for too-long content
        else
          config[:weight]
        end
      else
        0
      end
    end * 100
  end

  def seo_issues
    issues = []
    SEO_FIELDS.each do |field, config|
      value = send(field)
      if value.blank?
        issues << "Missing #{field.to_s.humanize}"
      elsif config[:max_length] && value.length > config[:max_length]
        issues << "#{field.to_s.humanize} too long (#{value.length}/#{config[:max_length]})"
      end
    end
    issues
  end
end
```

**Acceptance Tests:**
- [ ] Page tree displays hierarchy correctly
- [ ] "View on site" links work
- [ ] SEO score shows on page list
- [ ] SEO issues highlighted in edit form

**Effort:** 5-7 days

---

### 2.3 Inbox to Lightweight CRM

**Current State:**
- Controller: `app/controllers/site_admin/messages_controller.rb`
- Basic message list
- Contact model exists but limited status tracking

**Tasks:**

#### 2.3.1 Contact Status Field

```ruby
# Migration
add_column :pwb_contacts, :status, :string, default: 'new'
add_column :pwb_contacts, :last_activity_at, :datetime
add_column :pwb_contacts, :internal_notes, :text

# app/models/pwb/contact.rb
class Contact < ApplicationRecord
  STATUSES = %w[new active follow_up cold converted].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :by_status, ->(status) { where(status: status) }

  def update_activity!
    update!(last_activity_at: Time.current)
  end
end
```

#### 2.3.2 Conversation View Enhancement

```erb
<%# app/views/site_admin/messages/show.html.erb %>
<div class="conversation-container grid grid-cols-3 gap-6">
  <div class="col-span-2">
    <h2>Conversation with <%= @contact.name %></h2>

    <div class="messages-thread">
      <% @messages.each do |message| %>
        <%= render 'message', message: message %>
      <% end %>
    </div>

    <%= render 'reply_form' %>
  </div>

  <aside class="contact-sidebar">
    <%= render 'contact_card', contact: @contact %>
    <%= render 'property_context', property: @contact.interested_property %>
    <%= render 'internal_notes', contact: @contact %>
    <%= render 'activity_timeline', contact: @contact %>
  </aside>
</div>
```

#### 2.3.3 Response Time Tracking

```ruby
# app/models/pwb/message.rb
class Message < ApplicationRecord
  after_create :calculate_response_time, if: :reply?

  def calculate_response_time
    previous = conversation.messages.where.not(id: id).order(created_at: :desc).first
    return unless previous

    self.response_time_seconds = (created_at - previous.created_at).to_i
    save!
  end
end

# Dashboard metric
def average_response_time
  messages.where.not(response_time_seconds: nil)
          .average(:response_time_seconds)
          .to_i
end
```

**Acceptance Tests:**
- [ ] Contact status can be changed
- [ ] Property context shows in conversation
- [ ] Internal notes are saved and not visible to contacts
- [ ] Response time displayed in conversation header

**Effort:** 6-8 days

---

### 2.4 Media Library Intelligence

**Current State:**
- Controller: `app/controllers/site_admin/media_controller.rb`
- Basic upload/list functionality
- No usage tracking

**Tasks:**

#### 2.4.1 Usage Tracking

```ruby
# app/models/pwb/media.rb
class Media < ApplicationRecord
  has_many :media_usages, dependent: :destroy

  def usage_count
    media_usages.count
  end

  def unused?
    usage_count.zero?
  end

  def oversized?
    file_size > 2.megabytes
  end
end

# app/models/pwb/media_usage.rb
class MediaUsage < ApplicationRecord
  belongs_to :media
  belongs_to :usable, polymorphic: true
end
```

#### 2.4.2 Media Analysis Job

```ruby
# app/jobs/media_analysis_job.rb
class MediaAnalysisJob < ApplicationJob
  def perform(media_id)
    media = Pwb::Media.find(media_id)

    # Check file size
    media.update!(
      file_size: media.file.byte_size,
      dimensions: extract_dimensions(media),
      analyzed_at: Time.current
    )
  end

  private

  def extract_dimensions(media)
    return unless media.image?

    metadata = media.file.metadata
    "#{metadata['width']}x#{metadata['height']}"
  end
end
```

#### 2.4.3 Bulk Actions for Media

```ruby
# app/controllers/site_admin/media_controller.rb
def bulk_delete
  media_ids = params[:media_ids]
  deleted = current_website.media.unused.where(id: media_ids).destroy_all

  redirect_to site_admin_media_path,
              notice: "Deleted #{deleted.count} unused media files"
end
```

**Acceptance Tests:**
- [ ] Usage count shows on media list
- [ ] Unused media can be filtered
- [ ] Oversized images are flagged
- [ ] Bulk delete works for unused media only

**Effort:** 4-5 days

---

## Phase 3: Long-Term (3-6+ months)

### 3.1 Guided Onboarding Mode

**Current State:**
- `SiteAdmin::OnboardingController` exists with 5 steps
- Steps: Welcome, Profile, Property, Theme, Complete
- Per-user `onboarding_step` tracking

**Tasks:**

#### 3.1.1 Enhanced Onboarding Flow

```
New Flow:
1. Welcome & Goals (new)
2. Domain Setup (new)
3. Branding (logo, colors, company info)
4. SEO Basics (site title, description)
5. First Property
6. Theme Selection
7. Review & Launch
```

#### 3.1.2 Progressive Section Unlocking

```ruby
# app/models/concerns/onboarding_gates.rb
module OnboardingGates
  SECTION_REQUIREMENTS = {
    properties: { min_step: 5 },
    pages: { min_step: 4 },
    media: { min_step: 3 },
    settings: { min_step: 2 },
    analytics: { completed: true }
  }.freeze

  def can_access_section?(section)
    requirements = SECTION_REQUIREMENTS[section]
    return true unless requirements

    if requirements[:completed]
      onboarding_completed?
    else
      onboarding_step >= requirements[:min_step]
    end
  end
end
```

#### 3.1.3 Onboarding Analytics

```ruby
# Track completion funnel
class OnboardingEvent < ApplicationRecord
  belongs_to :user
  belongs_to :website

  # step_entered, step_completed, step_skipped, onboarding_completed
  validates :event_type, presence: true
  validates :step, presence: true
end
```

**Effort:** 10-15 days

---

### 3.2 Plan-Aware Admin UX

**Current State:**
- `Pwb::Subscription` model exists
- Plan limits defined but not consistently enforced

**Tasks:**

#### 3.2.1 Plan Limits Display

```erb
<%# app/views/site_admin/shared/_usage_indicator.html.erb %>
<div class="usage-indicator">
  <div class="flex justify-between text-sm mb-1">
    <span><%= label %></span>
    <span><%= current %> / <%= limit %></span>
  </div>
  <div class="progress-bar">
    <div class="progress-fill <%= usage_class(current, limit) %>"
         style="width: <%= (current.to_f / limit * 100).clamp(0, 100) %>%">
    </div>
  </div>
</div>
```

#### 3.2.2 Feature Gating

```ruby
# app/controllers/concerns/plan_gating.rb
module PlanGating
  extend ActiveSupport::Concern

  def require_feature!(feature)
    unless current_subscription.has_feature?(feature)
      respond_to do |format|
        format.html { redirect_to upgrade_path, alert: upgrade_message(feature) }
        format.json { render json: { error: 'Upgrade required' }, status: :payment_required }
      end
    end
  end

  def at_limit?(resource)
    current_subscription.at_limit?(resource)
  end
end
```

#### 3.2.3 Contextual Upgrade Prompts

```erb
<%# When approaching limit %>
<% if at_limit?(:properties) %>
  <div class="upgrade-prompt">
    <p>You've reached your plan's property limit.</p>
    <%= link_to "Upgrade to add more", upgrade_path, class: "btn btn-primary" %>
  </div>
<% end %>
```

**Effort:** 8-10 days

---

### 3.3 Analytics That Drive Action

**Tasks:**

#### 3.3.1 Property Performance Dashboard

```ruby
# app/services/property_analytics_service.rb
class PropertyAnalyticsService
  def top_performing(website, limit: 5)
    website.listed_properties
           .joins(:analytics_events)
           .group(:id)
           .order('COUNT(analytics_events.id) DESC')
           .limit(limit)
  end

  def suggested_actions(website)
    actions = []

    # Properties without photos
    no_photos = website.listed_properties.without_photos.count
    if no_photos > 0
      actions << {
        type: :warning,
        message: "#{no_photos} properties have no photos",
        action: "Add photos",
        path: properties_needing_photos_path
      }
    end

    # Stale properties
    stale = website.listed_properties.where('updated_at < ?', 30.days.ago).count
    if stale > 0
      actions << {
        type: :info,
        message: "#{stale} properties haven't been updated in 30 days",
        action: "Review listings",
        path: stale_properties_path
      }
    end

    actions
  end
end
```

**Effort:** 10-12 days

---

### 3.4 Admin Power Tools

**Tasks:**

#### 3.4.1 Global Search

```ruby
# app/controllers/site_admin/search_controller.rb
class SiteAdmin::SearchController < SiteAdmin::BaseController
  def index
    @query = params[:q]
    return if @query.blank?

    @results = {
      properties: search_properties,
      contacts: search_contacts,
      pages: search_pages,
      messages: search_messages
    }
  end

  private

  def search_properties
    current_website.listed_properties
                   .where('title ILIKE ? OR reference ILIKE ?', "%#{@query}%", "%#{@query}%")
                   .limit(5)
  end
  # ... other search methods
end
```

#### 3.4.2 Command Palette (Stimulus Controller)

```javascript
// app/javascript/controllers/command_palette_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "input", "results"]

  connect() {
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }

  handleKeydown(event) {
    // Cmd/Ctrl + K to open
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault()
      this.open()
    }
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  search() {
    const query = this.inputTarget.value
    // Fetch and display results
  }
}
```

#### 3.4.3 Activity Log

```ruby
# app/models/pwb/activity_log.rb
class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :website
  belongs_to :trackable, polymorphic: true, optional: true

  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # Actions: created, updated, deleted, published, unpublished, logged_in, etc.
end
```

**Effort:** 12-15 days

---

## Implementation Schedule

| Phase | Item | Effort | Sprint |
|-------|------|--------|--------|
| 1 | Dashboard Restructure | 3-5 days | Week 1-2 |
| 1 | Performance & N+1 | 2-3 days | Week 2 |
| 1 | Terminology | 1-2 days | Week 2 |
| 1 | Empty States | 2-3 days | Week 3 |
| 2 | Properties UX | 8-10 days | Week 4-6 |
| 2 | Pages & CMS | 5-7 days | Week 6-7 |
| 2 | Inbox → CRM | 6-8 days | Week 8-9 |
| 2 | Media Library | 4-5 days | Week 10 |
| 3 | Guided Onboarding | 10-15 days | Week 11-13 |
| 3 | Plan-Aware UX | 8-10 days | Week 14-15 |
| 3 | Analytics | 10-12 days | Week 16-18 |
| 3 | Power Tools | 12-15 days | Week 19-21 |

**Total Estimated Effort:** 70-95 days (~14-19 weeks)

---

## Dependencies

```
Phase 1 (no dependencies - can start immediately)
├── 1.1 Dashboard
├── 1.2 Performance
├── 1.3 Terminology
└── 1.4 Empty States

Phase 2 (depends on Phase 1 completion)
├── 2.1 Properties UX (depends on 1.2 Performance)
├── 2.2 Pages & CMS
├── 2.3 Inbox → CRM
└── 2.4 Media Library

Phase 3 (depends on Phase 2 completion)
├── 3.1 Guided Onboarding (depends on 2.1 Properties)
├── 3.2 Plan-Aware UX (depends on 3.1 Onboarding)
├── 3.3 Analytics (depends on 2.1, 2.3)
└── 3.4 Power Tools (can run parallel)
```

---

## Testing Strategy

### Unit Tests
- Model concerns (PropertyCompleteness, SeoCompleteness)
- Service objects (PropertyAnalyticsService)
- Helper methods

### Integration Tests
- Controller actions with authentication
- Plan gating behavior
- Onboarding flow progression

### E2E Tests (Playwright)
- Dashboard widget rendering
- Property bulk actions
- Onboarding complete flow
- Search functionality

---

## Metrics to Track

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Dashboard load time | TBD | <1s | Performance monitoring |
| SQL queries on dashboard | TBD | ≤5 | Bullet + logs |
| Onboarding completion rate | TBD | >60% | Analytics events |
| Time to first property | TBD | <10 min | Analytics events |
| Support tickets (UX-related) | TBD | -30% | Support system |

---

*Document generated: 2025-12-31*
*Last updated: 2025-12-31*
