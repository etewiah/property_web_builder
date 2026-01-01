# Support Ticketing System - Implementation Plan

## Overview

A support ticketing system that allows website admins to request help from the platform team. Tickets are created in the per-website admin (site_admin) and managed by platform administrators in the cross-tenant admin (tenant_admin).

**Timeline:** 3-4 weeks (phased)
**Complexity:** Medium
**Dependencies:** Existing multi-tenant infrastructure, notification system

---

## 1. User Stories

### Website Admin (Ticket Creator)
- As a website admin, I can create a support ticket describing my issue
- As a website admin, I can view all tickets I've submitted for my website
- As a website admin, I can add messages to existing tickets
- As a website admin, I receive notifications when my ticket is updated
- As a website admin, I can see the status and priority of my tickets

### Platform Admin (Ticket Handler)
- As a platform admin, I can view all tickets across all websites
- As a platform admin, I can filter tickets by status, priority, and website
- As a platform admin, I can assign tickets to myself or other platform admins
- As a platform admin, I can change ticket status and priority
- As a platform admin, I can respond to tickets with public replies or internal notes
- As a platform admin, I can view ticket metrics and workload

---

## 2. Data Model

### 2.1 Database Tables

#### `pwb_support_tickets`

```ruby
# Migration
create_table :pwb_support_tickets, id: :uuid do |t|
  # Tenant scoping
  t.references :website, foreign_key: { to_table: :pwb_websites }, null: false

  # Identification
  t.string :ticket_number, null: false  # e.g., "TKT-000123"

  # Content
  t.string :subject, null: false, limit: 255
  t.text :description

  # Classification
  t.integer :status, default: 0, null: false      # enum
  t.integer :priority, default: 1, null: false    # enum
  t.string :category                               # billing, technical, feature_request, bug, general

  # Relationships
  t.references :creator, foreign_key: { to_table: :pwb_users }, null: false
  t.references :assigned_to, foreign_key: { to_table: :pwb_users }

  # Tracking
  t.datetime :assigned_at
  t.datetime :first_response_at
  t.datetime :resolved_at
  t.datetime :closed_at
  t.integer :message_count, default: 0
  t.datetime :last_message_at
  t.boolean :last_message_from_platform, default: false

  t.timestamps
end

add_index :pwb_support_tickets, :ticket_number, unique: true
add_index :pwb_support_tickets, [:website_id, :status]
add_index :pwb_support_tickets, [:website_id, :created_at]
add_index :pwb_support_tickets, [:assigned_to_id, :status]
add_index :pwb_support_tickets, :status
```

#### `pwb_ticket_messages`

```ruby
create_table :pwb_ticket_messages, id: :uuid do |t|
  t.references :support_ticket, type: :uuid, foreign_key: { to_table: :pwb_support_tickets }, null: false
  t.references :website, foreign_key: { to_table: :pwb_websites }, null: false

  # Author
  t.references :user, foreign_key: { to_table: :pwb_users }, null: false
  t.boolean :from_platform_admin, default: false  # true = platform team, false = website admin

  # Content
  t.text :content, null: false
  t.boolean :internal_note, default: false  # Only visible to platform admins

  # Status change tracking (for audit trail)
  t.string :status_changed_from
  t.string :status_changed_to

  t.timestamps
end

add_index :pwb_ticket_messages, [:support_ticket_id, :created_at]
add_index :pwb_ticket_messages, [:website_id, :created_at]
```

### 2.2 Models

#### Pwb::SupportTicket

```ruby
# app/models/pwb/support_ticket.rb
module Pwb
  class SupportTicket < ApplicationRecord
    self.table_name = 'pwb_support_tickets'

    # Associations
    belongs_to :website
    belongs_to :creator, class_name: 'Pwb::User'
    belongs_to :assigned_to, class_name: 'Pwb::User', optional: true
    has_many :messages, class_name: 'Pwb::TicketMessage',
             foreign_key: :support_ticket_id, dependent: :destroy

    # Enums
    enum :status, {
      open: 0,
      in_progress: 1,
      waiting_on_customer: 2,
      resolved: 3,
      closed: 4
    }, prefix: true

    enum :priority, {
      low: 0,
      normal: 1,
      high: 2,
      urgent: 3
    }, prefix: true

    # Validations
    validates :subject, presence: true, length: { maximum: 255 }
    validates :description, presence: true, on: :create
    validates :ticket_number, presence: true, uniqueness: true
    validates :category, inclusion: {
      in: %w[billing technical feature_request bug general],
      allow_blank: true
    }

    # Callbacks
    before_validation :generate_ticket_number, on: :create
    after_create :create_initial_message

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :unassigned, -> { where(assigned_to_id: nil) }
    scope :assigned_to_user, ->(user) { where(assigned_to_id: user.id) }
    scope :needs_response, -> {
      where(status: [:open, :in_progress])
        .where(last_message_from_platform: false)
    }
    scope :awaiting_customer, -> { status_waiting_on_customer }

    # Constants
    CATEGORIES = %w[billing technical feature_request bug general].freeze

    # Instance Methods
    def assign_to!(user)
      update!(
        assigned_to: user,
        assigned_at: Time.current,
        status: :in_progress
      )
    end

    def unassign!
      update!(assigned_to: nil, assigned_at: nil)
    end

    def resolve!
      update!(status: :resolved, resolved_at: Time.current)
    end

    def close!
      update!(status: :closed, closed_at: Time.current)
    end

    def reopen!
      update!(status: :open, resolved_at: nil, closed_at: nil)
    end

    def active?
      !status_resolved? && !status_closed?
    end

    def response_time
      return nil unless first_response_at
      first_response_at - created_at
    end

    def resolution_time
      return nil unless resolved_at
      resolved_at - created_at
    end

    private

    def generate_ticket_number
      return if ticket_number.present?

      loop do
        self.ticket_number = "TKT-#{SecureRandom.hex(4).upcase}"
        break unless self.class.exists?(ticket_number: ticket_number)
      end
    end

    def create_initial_message
      messages.create!(
        website: website,
        user: creator,
        content: description,
        from_platform_admin: false
      )
    end
  end
end
```

#### Pwb::TicketMessage

```ruby
# app/models/pwb/ticket_message.rb
module Pwb
  class TicketMessage < ApplicationRecord
    self.table_name = 'pwb_ticket_messages'

    # Associations
    belongs_to :support_ticket, class_name: 'Pwb::SupportTicket'
    belongs_to :website
    belongs_to :user, class_name: 'Pwb::User'

    # ActiveStorage (optional - for attachments)
    has_many_attached :attachments

    # Validations
    validates :content, presence: true

    # Callbacks
    after_create :update_ticket_counters
    after_create :notify_relevant_parties

    # Scopes
    scope :public_messages, -> { where(internal_note: false) }
    scope :internal_notes, -> { where(internal_note: true) }
    scope :chronological, -> { order(created_at: :asc) }
    scope :reverse_chronological, -> { order(created_at: :desc) }

    # Instance Methods
    def status_change?
      status_changed_from.present? || status_changed_to.present?
    end

    def author_name
      user&.display_name || 'Unknown'
    end

    def visible_to?(viewing_user, is_platform_admin:)
      return true unless internal_note
      is_platform_admin
    end

    private

    def update_ticket_counters
      support_ticket.update!(
        message_count: support_ticket.messages.count,
        last_message_at: created_at,
        last_message_from_platform: from_platform_admin
      )

      # Record first response time
      if from_platform_admin && support_ticket.first_response_at.nil?
        support_ticket.update!(first_response_at: created_at)
      end
    end

    def notify_relevant_parties
      TicketNotificationJob.perform_later(id, :new_message)
    end
  end
end
```

#### PwbTenant Models (Auto-scoped)

```ruby
# app/models/pwb_tenant/support_ticket.rb
module PwbTenant
  class SupportTicket < Pwb::SupportTicket
    # Automatically scoped to current_website via acts_as_tenant
  end
end

# app/models/pwb_tenant/ticket_message.rb
module PwbTenant
  class TicketMessage < Pwb::TicketMessage
    # Automatically scoped to current_website via acts_as_tenant
  end
end
```

---

## 3. Controllers

### 3.1 Site Admin Controller (Website Admin View)

```ruby
# app/controllers/site_admin/support_tickets_controller.rb
module SiteAdmin
  class SupportTicketsController < SiteAdminController
    before_action :load_ticket, only: [:show, :update]

    def index
      @tickets = current_website.support_tickets
                   .includes(:creator, :assigned_to)
                   .recent

      # Filtering
      @tickets = @tickets.where(status: params[:status]) if params[:status].present?

      @pagy, @tickets = pagy(@tickets, items: 20)
    end

    def show
      @messages = @ticket.messages
                    .public_messages  # Website admins don't see internal notes
                    .includes(:user)
                    .chronological
    end

    def new
      @ticket = current_website.support_tickets.build
    end

    def create
      @ticket = current_website.support_tickets.build(ticket_params)
      @ticket.creator = current_user

      if @ticket.save
        TicketNotificationJob.perform_later(@ticket.id, :created)
        redirect_to site_admin_support_ticket_path(@ticket),
                    notice: "Support ticket created successfully. Ticket ##{@ticket.ticket_number}"
      else
        render :new, status: :unprocessable_entity
      end
    end

    # Website admin can only add messages, not change status
    def add_message
      @ticket = current_website.support_tickets.find(params[:id])

      @message = @ticket.messages.build(
        website: current_website,
        user: current_user,
        content: params[:message][:content],
        from_platform_admin: false
      )

      if @message.save
        # Reopen ticket if it was waiting on customer
        @ticket.update!(status: :open) if @ticket.status_waiting_on_customer?

        redirect_to site_admin_support_ticket_path(@ticket),
                    notice: "Message added successfully"
      else
        redirect_to site_admin_support_ticket_path(@ticket),
                    alert: "Could not add message"
      end
    end

    private

    def load_ticket
      @ticket = current_website.support_tickets.find(params[:id])
    end

    def ticket_params
      params.require(:support_ticket).permit(:subject, :description, :category, :priority)
    end
  end
end
```

### 3.2 Tenant Admin Controller (Platform Admin View)

```ruby
# app/controllers/tenant_admin/support_tickets_controller.rb
module TenantAdmin
  class SupportTicketsController < TenantAdminController
    before_action :load_ticket, only: [:show, :update, :assign, :change_status]

    def index
      @tickets = Pwb::SupportTicket
                   .includes(:website, :creator, :assigned_to)
                   .recent

      # Filters
      @tickets = filter_tickets(@tickets)

      @pagy, @tickets = pagy(@tickets, items: 25)

      # Stats for dashboard
      @stats = {
        open: Pwb::SupportTicket.status_open.count,
        in_progress: Pwb::SupportTicket.status_in_progress.count,
        needs_response: Pwb::SupportTicket.needs_response.count,
        my_tickets: Pwb::SupportTicket.assigned_to_user(current_user).active.count
      }
    end

    def show
      @messages = @ticket.messages
                    .includes(:user)
                    .chronological
      # Platform admins see ALL messages including internal notes
    end

    def assign
      if params[:user_id].present?
        assignee = Pwb::User.find(params[:user_id])
        @ticket.assign_to!(assignee)

        TicketNotificationJob.perform_later(@ticket.id, :assigned)

        redirect_to tenant_admin_support_ticket_path(@ticket),
                    notice: "Ticket assigned to #{assignee.display_name}"
      else
        @ticket.unassign!
        redirect_to tenant_admin_support_ticket_path(@ticket),
                    notice: "Ticket unassigned"
      end
    end

    def change_status
      old_status = @ticket.status
      new_status = params[:status]

      case new_status
      when 'resolved'
        @ticket.resolve!
      when 'closed'
        @ticket.close!
      when 'open'
        @ticket.reopen!
      else
        @ticket.update!(status: new_status)
      end

      # Create status change message
      @ticket.messages.create!(
        website: @ticket.website,
        user: current_user,
        content: "Status changed from #{old_status.humanize} to #{new_status.humanize}",
        from_platform_admin: true,
        status_changed_from: old_status,
        status_changed_to: new_status
      )

      TicketNotificationJob.perform_later(@ticket.id, :status_changed)

      redirect_to tenant_admin_support_ticket_path(@ticket),
                  notice: "Ticket status updated"
    end

    def add_message
      @ticket = Pwb::SupportTicket.find(params[:id])

      @message = @ticket.messages.build(
        website: @ticket.website,
        user: current_user,
        content: params[:message][:content],
        from_platform_admin: true,
        internal_note: params[:message][:internal_note] == '1'
      )

      if @message.save
        # Update ticket status if needed
        if @ticket.status_open? && !@message.internal_note
          @ticket.update!(status: :waiting_on_customer)
        end

        redirect_to tenant_admin_support_ticket_path(@ticket),
                    notice: @message.internal_note ? "Internal note added" : "Reply sent"
      else
        redirect_to tenant_admin_support_ticket_path(@ticket),
                    alert: "Could not add message"
      end
    end

    private

    def load_ticket
      @ticket = Pwb::SupportTicket.find(params[:id])
    end

    def filter_tickets(scope)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(priority: params[:priority]) if params[:priority].present?
      scope = scope.where(website_id: params[:website_id]) if params[:website_id].present?
      scope = scope.where(assigned_to_id: params[:assigned_to]) if params[:assigned_to].present?
      scope = scope.where(category: params[:category]) if params[:category].present?

      if params[:search].present?
        search = "%#{params[:search]}%"
        scope = scope.where(
          "subject ILIKE :search OR ticket_number ILIKE :search",
          search: search
        )
      end

      scope
    end
  end
end
```

---

## 4. Routes

```ruby
# config/routes.rb

namespace :site_admin do
  resources :support_tickets, only: [:index, :show, :new, :create] do
    member do
      post :add_message
    end
  end
end

namespace :tenant_admin do
  resources :support_tickets, only: [:index, :show] do
    member do
      patch :assign
      patch :change_status
      post :add_message
    end

    collection do
      get :metrics  # Optional: ticket analytics
    end
  end
end
```

---

## 5. Views

### 5.1 Site Admin Views (Website Admin)

#### Index View

```erb
<%# app/views/site_admin/support_tickets/index.html.erb %>
<div class="space-y-6">
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold">Support Tickets</h1>
    <%= link_to "New Ticket", new_site_admin_support_ticket_path,
                class: "btn btn-primary" %>
  </div>

  <%# Status filter tabs %>
  <div class="flex space-x-4 border-b">
    <%= link_to "All", site_admin_support_tickets_path,
                class: "tab #{params[:status].blank? ? 'active' : ''}" %>
    <% Pwb::SupportTicket.statuses.keys.each do |status| %>
      <%= link_to status.humanize,
                  site_admin_support_tickets_path(status: status),
                  class: "tab #{params[:status] == status ? 'active' : ''}" %>
    <% end %>
  </div>

  <%# Ticket list %>
  <div class="bg-white rounded-lg shadow divide-y">
    <% @tickets.each do |ticket| %>
      <%= link_to site_admin_support_ticket_path(ticket),
                  class: "block p-4 hover:bg-gray-50" do %>
        <div class="flex justify-between items-start">
          <div>
            <div class="flex items-center gap-2">
              <span class="text-sm text-gray-500"><%= ticket.ticket_number %></span>
              <%= render 'shared/status_badge', status: ticket.status %>
              <%= render 'shared/priority_badge', priority: ticket.priority %>
            </div>
            <h3 class="font-medium mt-1"><%= ticket.subject %></h3>
            <p class="text-sm text-gray-500 mt-1">
              Created <%= time_ago_in_words(ticket.created_at) %> ago
              <% if ticket.assigned_to %>
                &middot; Assigned to <%= ticket.assigned_to.display_name %>
              <% end %>
            </p>
          </div>
          <% if ticket.message_count > 1 %>
            <span class="text-sm text-gray-500">
              <%= ticket.message_count %> messages
            </span>
          <% end %>
        </div>
      <% end %>
    <% end %>
  </div>

  <%== pagy_nav(@pagy) %>
</div>
```

#### New Ticket Form

```erb
<%# app/views/site_admin/support_tickets/new.html.erb %>
<div class="max-w-2xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">Create Support Ticket</h1>

  <%= form_with model: @ticket, url: site_admin_support_tickets_path,
                class: "space-y-6" do |f| %>

    <div>
      <%= f.label :category, class: "block text-sm font-medium text-gray-700" %>
      <%= f.select :category,
                   Pwb::SupportTicket::CATEGORIES.map { |c| [c.humanize, c] },
                   { include_blank: "Select a category..." },
                   class: "mt-1 block w-full rounded-lg border-gray-300" %>
    </div>

    <div>
      <%= f.label :priority, class: "block text-sm font-medium text-gray-700" %>
      <%= f.select :priority,
                   Pwb::SupportTicket.priorities.keys.map { |p| [p.humanize, p] },
                   {},
                   class: "mt-1 block w-full rounded-lg border-gray-300" %>
    </div>

    <div>
      <%= f.label :subject, class: "block text-sm font-medium text-gray-700" %>
      <%= f.text_field :subject,
                       class: "mt-1 block w-full rounded-lg border-gray-300",
                       placeholder: "Brief summary of your issue" %>
    </div>

    <div>
      <%= f.label :description, class: "block text-sm font-medium text-gray-700" %>
      <%= f.text_area :description,
                      rows: 8,
                      class: "mt-1 block w-full rounded-lg border-gray-300",
                      placeholder: "Please describe your issue in detail..." %>
    </div>

    <div class="flex gap-3">
      <%= f.submit "Submit Ticket", class: "btn btn-primary" %>
      <%= link_to "Cancel", site_admin_support_tickets_path, class: "btn btn-secondary" %>
    </div>
  <% end %>
</div>
```

#### Show View (Conversation)

```erb
<%# app/views/site_admin/support_tickets/show.html.erb %>
<div class="max-w-4xl mx-auto space-y-6">
  <%# Header %>
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex justify-between items-start">
      <div>
        <div class="flex items-center gap-2 mb-2">
          <span class="text-sm text-gray-500"><%= @ticket.ticket_number %></span>
          <%= render 'shared/status_badge', status: @ticket.status %>
          <%= render 'shared/priority_badge', priority: @ticket.priority %>
        </div>
        <h1 class="text-xl font-bold"><%= @ticket.subject %></h1>
        <p class="text-sm text-gray-500 mt-2">
          Created by <%= @ticket.creator.display_name %>
          on <%= @ticket.created_at.strftime("%B %d, %Y at %H:%M") %>
        </p>
      </div>
    </div>
  </div>

  <%# Message Thread %>
  <div class="bg-white rounded-lg shadow divide-y">
    <% @messages.each do |message| %>
      <div class="p-4 <%= message.from_platform_admin ? 'bg-blue-50' : '' %>">
        <div class="flex items-center gap-2 mb-2">
          <span class="font-medium">
            <%= message.from_platform_admin ? 'Support Team' : message.author_name %>
          </span>
          <span class="text-sm text-gray-500">
            <%= time_ago_in_words(message.created_at) %> ago
          </span>
          <% if message.status_change? %>
            <span class="text-xs bg-gray-200 px-2 py-1 rounded">Status Update</span>
          <% end %>
        </div>
        <div class="prose prose-sm max-w-none">
          <%= simple_format(message.content) %>
        </div>
      </div>
    <% end %>
  </div>

  <%# Reply Form (only if ticket is not closed) %>
  <% unless @ticket.status_closed? %>
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="font-medium mb-4">Add a Reply</h3>
      <%= form_with url: add_message_site_admin_support_ticket_path(@ticket),
                    method: :post, class: "space-y-4" do |f| %>
        <%= f.text_area :content,
                        name: "message[content]",
                        rows: 4,
                        class: "block w-full rounded-lg border-gray-300",
                        placeholder: "Type your message..." %>
        <%= f.submit "Send Reply", class: "btn btn-primary" %>
      <% end %>
    </div>
  <% end %>
</div>
```

### 5.2 Tenant Admin Views (Platform Admin)

The tenant_admin views follow a similar pattern but include:
- Cross-website filtering
- Assignment controls
- Status change buttons
- Internal notes toggle
- Metrics dashboard

---

## 6. Background Jobs

### 6.1 Notification Job

```ruby
# app/jobs/ticket_notification_job.rb
class TicketNotificationJob < ApplicationJob
  queue_as :default

  def perform(ticket_or_message_id, event_type)
    case event_type.to_sym
    when :created
      ticket = Pwb::SupportTicket.find(ticket_or_message_id)
      notify_platform_admins_new_ticket(ticket)

    when :assigned
      ticket = Pwb::SupportTicket.find(ticket_or_message_id)
      notify_assignee(ticket)

    when :status_changed
      ticket = Pwb::SupportTicket.find(ticket_or_message_id)
      notify_website_admin_status_change(ticket)

    when :new_message
      message = Pwb::TicketMessage.find(ticket_or_message_id)
      ticket = message.support_ticket

      if message.from_platform_admin && !message.internal_note
        # Platform replied - notify website admin
        notify_website_admin_new_reply(ticket, message)
      else
        # Website admin replied - notify assigned platform admin
        notify_platform_admin_new_reply(ticket, message)
      end
    end
  end

  private

  def notify_platform_admins_new_ticket(ticket)
    # Send ntfy notification
    if ticket.website.ntfy_enabled?
      NtfyService.notify_admin(
        ticket.website,
        "New Support Ticket: #{ticket.ticket_number}",
        "#{ticket.subject}\n\nFrom: #{ticket.creator.display_name}\nPriority: #{ticket.priority.humanize}",
        priority: ticket.priority_urgent? ? 'high' : 'default',
        tags: ['ticket', ticket.category].compact
      )
    end

    # Send email to platform admins
    # TicketMailer.new_ticket_notification(ticket).deliver_later
  end

  def notify_website_admin_new_reply(ticket, message)
    # Email the website admin about the reply
    # TicketMailer.new_reply_notification(ticket, message).deliver_later
  end

  def notify_assignee(ticket)
    return unless ticket.assigned_to

    # Notify the assigned user
    # TicketMailer.ticket_assigned(ticket).deliver_later
  end

  def notify_website_admin_status_change(ticket)
    # TicketMailer.status_changed(ticket).deliver_later
  end

  def notify_platform_admin_new_reply(ticket, message)
    return unless ticket.assigned_to

    # Notify assigned admin of customer reply
    # TicketMailer.customer_replied(ticket, message).deliver_later
  end
end
```

---

## 7. Mailer (Optional but Recommended)

```ruby
# app/mailers/pwb/ticket_mailer.rb
module Pwb
  class TicketMailer < ApplicationMailer
    def new_ticket_notification(ticket)
      @ticket = ticket
      @website = ticket.website

      mail(
        to: platform_admin_emails,
        subject: "[#{ticket.ticket_number}] New Support Ticket: #{ticket.subject}"
      )
    end

    def new_reply_notification(ticket, message)
      @ticket = ticket
      @message = message

      mail(
        to: ticket.creator.email,
        subject: "[#{ticket.ticket_number}] Reply to your support ticket"
      )
    end

    def ticket_assigned(ticket)
      @ticket = ticket

      mail(
        to: ticket.assigned_to.email,
        subject: "[#{ticket.ticket_number}] Ticket assigned to you"
      )
    end

    def status_changed(ticket)
      @ticket = ticket

      mail(
        to: ticket.creator.email,
        subject: "[#{ticket.ticket_number}] Ticket status updated to #{ticket.status.humanize}"
      )
    end

    private

    def platform_admin_emails
      ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip)
    end
  end
end
```

---

## 8. Implementation Phases

### Phase 1: Core Foundation (Week 1)

**Tasks:**
- [ ] Create database migrations
- [ ] Create Pwb::SupportTicket model with validations and enums
- [ ] Create Pwb::TicketMessage model
- [ ] Create PwbTenant:: scoped versions
- [ ] Add routes for both admin areas
- [ ] Create basic SiteAdmin::SupportTicketsController (CRUD)
- [ ] Create basic TenantAdmin::SupportTicketsController (read + status)
- [ ] Create index/show/new views for site_admin
- [ ] Create index/show views for tenant_admin

**Deliverables:**
- Website admins can create and view tickets
- Platform admins can view all tickets and change status

### Phase 2: Messaging & Workflow (Week 2)

**Tasks:**
- [ ] Implement message thread functionality
- [ ] Add reply forms to both admin areas
- [ ] Implement internal notes for platform admins
- [ ] Add status change workflow with audit messages
- [ ] Implement assignment functionality
- [ ] Create status/priority badge partials
- [ ] Add filtering by status/priority

**Deliverables:**
- Full conversation threading
- Status workflow (open -> in_progress -> resolved -> closed)
- Assignment system
- Internal notes

### Phase 3: Notifications & Polish (Week 3)

**Tasks:**
- [ ] Create TicketNotificationJob
- [ ] Integrate with NtfyService for push notifications
- [ ] Create TicketMailer with email templates
- [ ] Add navigation links and unread counts
- [ ] Implement search functionality
- [ ] Add pagination
- [ ] Create metrics dashboard (optional)

**Deliverables:**
- Email notifications for ticket events
- Push notifications via ntfy
- Search and filtering
- Dashboard metrics

### Phase 4: Testing & Refinement (Week 4)

**Tasks:**
- [ ] Write model specs for SupportTicket and TicketMessage
- [ ] Write request specs for both controllers
- [ ] Test multi-tenant isolation
- [ ] Add feature specs for key workflows
- [ ] Performance optimization (indexes, eager loading)
- [ ] UI polish and responsive design
- [ ] Documentation

**Deliverables:**
- Full test coverage
- Production-ready system

---

## 9. Feature Gating (Optional)

If support tickets should be a premium feature:

```ruby
# In Plan::FEATURES
support_tickets: 'Support ticket system',
priority_support: 'Priority support with faster response times'

# In views/controllers
<% if current_website.subscription.has_feature?(:support_tickets) %>
  <%= link_to "Support", site_admin_support_tickets_path %>
<% end %>
```

---

## 10. Future Enhancements

After initial release, consider:

1. **SLA Tracking** - Response time targets by priority
2. **Canned Responses** - Pre-written reply templates
3. **File Attachments** - ActiveStorage integration
4. **Ticket Merging** - Combine duplicate tickets
5. **Customer Satisfaction** - Post-resolution survey
6. **Knowledge Base Integration** - Link to help articles
7. **Auto-close** - Close resolved tickets after X days
8. **Escalation Rules** - Auto-escalate based on SLA
9. **Reporting Dashboard** - Resolution times, volume trends
10. **API Access** - For third-party integrations

---

## Appendix: Quick Reference

### Status Flow
```
open -> in_progress -> waiting_on_customer -> resolved -> closed
                   \-> waiting_on_customer -/
```

### Priority Levels
- **Low** - General questions, no urgency
- **Normal** - Standard issues (default)
- **High** - Impacting business operations
- **Urgent** - Critical system issues

### Categories
- `billing` - Payment, subscription issues
- `technical` - Bugs, errors, technical problems
- `feature_request` - New feature suggestions
- `bug` - Bug reports
- `general` - Everything else

### Key Files to Create
```
db/migrate/XXXXXX_create_support_tickets.rb
db/migrate/XXXXXX_create_ticket_messages.rb
app/models/pwb/support_ticket.rb
app/models/pwb/ticket_message.rb
app/models/pwb_tenant/support_ticket.rb
app/models/pwb_tenant/ticket_message.rb
app/controllers/site_admin/support_tickets_controller.rb
app/controllers/tenant_admin/support_tickets_controller.rb
app/views/site_admin/support_tickets/
app/views/tenant_admin/support_tickets/
app/jobs/ticket_notification_job.rb
app/mailers/pwb/ticket_mailer.rb
spec/models/pwb/support_ticket_spec.rb
spec/models/pwb/ticket_message_spec.rb
spec/requests/site_admin/support_tickets_spec.rb
spec/requests/tenant_admin/support_tickets_spec.rb
```
