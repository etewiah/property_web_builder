# Contact-Message Association: Issues and Solutions

## Executive Summary

The Contact-Message relationship has evolved organically over ~9 years with three major architectural shifts:
1. **2016-2018:** Messages existed before Contacts; they were later linked
2. **2025-12:** Multi-tenancy added via `website_id` column
3. **Current State:** Functional but has security, data consistency, and UX issues

**Key Problems:**
1. **Security:** Cross-tenant data leakage via association
2. **Data Consistency:** Redundant saves, optional relationship, duplicate emails
3. **UX:** Admin views don't show relationship between models
4. **Maintainability:** Identical creation pattern in 3 places

---

## Issue #1: Cross-Tenant Data Access Risk

### Problem Description

The Contact-Message association lacks tenant awareness. An admin from one website could access messages from another website if they share the same contact record.

### Current Code

**Model Association (NOT SCOPED):**
```ruby
# app/models/pwb/contact.rb
has_many :messages, class_name: 'Pwb::Message'

# This allows:
@contact.messages  # ❌ Returns ALL messages for this contact across ALL websites
```

**Scenario that Breaks:**
```ruby
# Website A
website_a = Website.find_by(subdomain: 'a')
contact_a = website_a.contacts.find_by(primary_email: 'shared@example.com')

# Website B  
website_b = Website.find_by(subdomain: 'b')
contact_b = website_b.contacts.find_by(primary_email: 'shared@example.com')

# If same email used across websites (which is allowed),
# accessing contact_a.messages could return messages from contact_b's website!
# This is because the association doesn't filter by website_id
```

### Why It Happens

```ruby
# The association is defined without a scope:
has_many :messages, class_name: 'Pwb::Message'

# It should include a scope that respects website_id:
has_many :messages, 
         -> { where(website_id: website_id) },
         class_name: 'Pwb::Message'
```

### Impact

- **Data Leakage:** Admin of Website A could see messages from Website B
- **Privacy Violation:** Contact information mixed across tenants
- **Audit Trail Poisoning:** Cross-tenant access patterns in logs

### Solution

**Fix 1: Scope the Association**

```ruby
# app/models/pwb/contact.rb
class Contact < ApplicationRecord
  # BEFORE (insecure):
  # has_many :messages, class_name: 'Pwb::Message'
  
  # AFTER (secure):
  has_many :messages, 
           -> { where(website_id: website_id) },
           class_name: 'Pwb::Message',
           foreign_key: :contact_id,
           inverse_of: :contact,
           dependent: :nullify
end
```

**Fix 2: Add Foreign Key Constraint**

```ruby
# db/migrate/xxx_add_foreign_key_constraint_to_messages.rb
class AddForeignKeyConstraintToMessages < ActiveRecord::Migration[8.0]
  def change
    # Add explicit foreign key constraint if not present
    unless foreign_key_exists?(:pwb_messages, :pwb_contacts)
      add_foreign_key :pwb_messages, :pwb_contacts, 
                      column: :contact_id, 
                      on_delete: :nullify
    end
  end
end
```

**Fix 3: Make Contact Required (Optional)**

```ruby
# app/models/pwb/message.rb
class Message < ApplicationRecord
  # Change from:
  # belongs_to :contact, optional: true
  
  # To:
  belongs_to :contact, optional: false  # Enforce presence
  
  # Add validation:
  validates :contact_id, :origin_email, presence: true
end
```

### Testing the Fix

```ruby
require 'rails_helper'

describe "Contact-Message Tenant Isolation" do
  let(:website_a) { create(:website, subdomain: 'a') }
  let(:website_b) { create(:website, subdomain: 'b') }
  
  # Create contacts with same email in different websites
  let(:contact_a) { create(:contact, website: website_a, primary_email: 'test@example.com') }
  let(:contact_b) { create(:contact, website: website_b, primary_email: 'test@example.com') }
  
  # Create messages for each
  let(:message_a) { create(:message, website: website_a, contact: contact_a) }
  let(:message_b) { create(:message, website: website_b, contact: contact_b) }
  
  it "isolates messages by website" do
    expect(contact_a.messages).to include(message_a)
    expect(contact_a.messages).not_to include(message_b)  # ✓ MUST PASS
    
    expect(contact_b.messages).to include(message_b)
    expect(contact_b.messages).not_to include(message_a)
  end
end
```

---

## Issue #2: Redundant Saves During Message Creation

### Problem Description

Messages are saved twice during the creation flow: once without a contact, then again after linking the contact. This wastes database writes, creates race condition windows, and complicates the logic.

### Current Code Flow

**ContactUsController#contact_us_ajax (lines 68-104):**
```ruby
# Create message without contact initially
@enquiry = Message.new({
  website: @current_website,
  title: params[:contact][:subject],
  content: params[:contact][:message],
  # ... other fields ...
})

# First save attempt (contact_id is NULL at this point)
unless @enquiry.save && @contact.save  # ← SAVE #1
  # Handle errors
  return render "pwb/ajax/contact_us_errors"
end

# ... some logging ...

# Link contact AFTER creation
@enquiry.contact = @contact  # ← NOW assign contact_id
@enquiry.save                # ← SAVE #2 (redundant!)
```

### Why This Is Bad

1. **Wasted DB Writes:** Each `save` is a full UPDATE/INSERT to database
2. **Race Conditions:** Between save #1 and #2, an async job might process incomplete message
3. **Audit Trail Noise:** Two separate update events in logs instead of one
4. **Error Handling Complexity:** What if second save fails?
5. **Not Transactional:** If second save fails, message is already in DB

### Race Condition Example

```
Timeline:
T1: @enquiry.save (contact_id still NULL)      ← SAVE #1
T2: Background job processes message (no contact info!)
T3: @enquiry.contact = @contact
T4: @enquiry.save (contact_id now set)          ← SAVE #2

NtfyService.build_inquiry_message(@enquiry) at T2:
  message.contact.present?  # ← FALSE! Breaks assumptions
```

### Solution

**Approach 1: Single-Phase Creation with Transaction**

```ruby
# app/controllers/pwb/contact_us_controller.rb
def contact_us_ajax
  @error_messages = []
  I18n.locale = params["contact"]["locale"] || I18n.default_locale
  
  StructuredLogger.info('[ContactForm] Processing submission', ...)
  
  # Use transaction for atomicity
  result = Message.transaction do
    # Create or update contact
    @contact = @current_website.contacts.find_or_initialize_by(
      primary_email: params[:contact][:email]
    )
    @contact.attributes = {
      primary_phone_number: params[:contact][:tel],
      first_name: params[:contact][:name]
    }
    @contact.save!
    
    # Create message WITH contact association in single save
    @enquiry = @contact.messages.create!(
      website: @current_website,
      title: params[:contact][:subject],
      content: params[:contact][:message],
      locale: params[:contact][:locale],
      url: request.referer,
      host: request.host,
      origin_ip: request.ip,
      origin_email: params[:contact][:email],
      user_agent: request.user_agent,
      delivery_email: @current_agency.email_for_general_contact_form
    )
    
    # Return both for later use
    [@contact, @enquiry]
  rescue ActiveRecord::RecordInvalid => e
    nil
  end
  
  unless result
    @error_messages = [@contact&.errors&.full_messages, 
                       @enquiry&.errors&.full_messages].compact.flatten
    StructuredLogger.warn('[ContactForm] Validation failed', ...)
    return render "pwb/ajax/contact_us_errors"
  end
  
  @contact, @enquiry = result
  
  # Rest of the code...
  EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later
  NtfyNotificationJob.perform_later(@current_website.id, :inquiry, @enquiry.id)
  
  @flash = I18n.t "contact.success"
  render "pwb/ajax/contact_us_success", layout: false
end
```

**Key Improvements:**
- ✓ Single `create!` call (one save)
- ✓ Within transaction (atomic)
- ✓ Contact always set (no race window)
- ✓ Error handling consolidated

**Approach 2: Service Object (Better Design)**

```ruby
# app/services/contact_inquiry_service.rb
class ContactInquiryService
  def initialize(website, contact_params, message_params)
    @website = website
    @contact_params = contact_params
    @message_params = message_params
  end
  
  def create!
    Message.transaction do
      # Create/update contact
      contact = @website.contacts.find_or_initialize_by(
        primary_email: @contact_params[:email]
      )
      contact.update!(@contact_params)
      
      # Create message with contact
      message = contact.messages.create!(@message_params)
      
      [contact, message]
    end
  end
end

# Usage in controller:
service = ContactInquiryService.new(
  @current_website,
  { email: params[:contact][:email], ... },
  { title: params[:contact][:subject], ... }
)
@contact, @enquiry = service.create!
```

### Testing the Fix

```ruby
describe ContactInquiryService do
  let(:website) { create(:website) }
  
  it "creates contact and message in single transaction" do
    service = ContactInquiryService.new(website, contact_params, message_params)
    
    expect {
      @contact, @message = service.create!
    }.to change(Contact, :count).by(1)
     .and change(Message, :count).by(1)
    
    # Verify they're linked
    expect(@message.contact).to eq(@contact)
    expect(@message.website_id).to eq(website.id)
    expect(@contact.website_id).to eq(website.id)
  end
  
  it "rolls back all changes on validation error" do
    invalid_params = message_params.merge(content: '')  # Invalid
    service = ContactInquiryService.new(website, contact_params, invalid_params)
    
    expect {
      service.create!
    }.to raise(ActiveRecord::RecordInvalid)
      .and not_change(Contact, :count)
      .and not_change(Message, :count)
  end
end
```

---

## Issue #3: Email Address Duplication and Source-of-Truth Confusion

### Problem Description

Email addresses are stored in two places with inconsistent rules:
- `Contact.primary_email` (unique index, but not tenant-aware)
- `Message.origin_email` (no uniqueness constraint)

This creates ambiguity about which is the source of truth.

### Current Schema

```ruby
# Contacts table
t.string :primary_email, index: true, unique: true  # ← UNIQUE at DB level

# Messages table  
t.string :origin_email  # ← No uniqueness constraint
```

### Issues

1. **Inconsistent Constraints:** Contact enforces uniqueness, Message doesn't
2. **Lookup Ambiguity:** Should we use contact.primary_email or message.origin_email?
3. **Sync Problems:** What if user updates email on contact but message still has old email?
4. **Non-Tenant-Aware:** Unique index should be (website_id, primary_email)

### Example Problem

```ruby
# Create message with email
message = Message.create(origin_email: "alice@example.com")

# Create contact later with same email
contact = Contact.create(primary_email: "alice@example.com")

# Link them
message.contact = contact
message.save

# Later: user edits contact email to "alice.smith@example.com"
contact.update(primary_email: "alice.smith@example.com")

# Now we have:
# message.origin_email = "alice@example.com" (old)
# contact.primary_email = "alice.smith@example.com" (new)
# ❌ Inconsistent!
```

### Solution

**Option A: Contact is Source of Truth (Recommended)**

```ruby
# app/models/pwb/message.rb
class Message < ApplicationRecord
  belongs_to :contact, optional: false
  
  # Remove origin_email from messages, always read from contact
  # or create a method:
  def sender_email
    contact.primary_email
  end
  
  # For backward compat during migration:
  before_create :set_origin_email_from_contact
  
  private
  
  def set_origin_email_from_contact
    self.origin_email ||= contact&.primary_email
  end
end
```

**Step 1: Make Contact Required**
```ruby
# Ensure all messages have contacts
Message.where(contact_id: nil).count  # Verify none exist

# Update schema if needed
# has_many messages: belongs_to :contact, optional: false
```

**Step 2: Fix Uniqueness Constraint**
```ruby
# db/migrate/xxx_fix_contact_email_uniqueness.rb
class FixContactEmailUniqueness < ActiveRecord::Migration[8.0]
  def change
    # Remove old unique index
    remove_index :pwb_contacts, :primary_email
    
    # Add compound unique index (website_id, primary_email)
    add_index :pwb_contacts, [:website_id, :primary_email], 
              unique: true,
              name: 'index_pwb_contacts_on_website_and_email'
  end
end
```

**Step 3: Document the Rule**
```ruby
# app/models/pwb/contact.rb
class Contact < ApplicationRecord
  # ...
  # NOTE: primary_email is the source of truth for contact email
  # Messages display this via contact relationship, not origin_email
  # origin_email on Message is maintained for audit/history only
end
```

### Testing the Fix

```ruby
describe "Email source of truth" do
  it "contact email is authoritative" do
    contact = create(:contact, primary_email: "alice@example.com")
    message = create(:message, contact: contact)
    
    # Both should match initially
    expect(message.contact.primary_email).to eq("alice@example.com")
    
    # If contact email changes
    contact.update(primary_email: "alice.new@example.com")
    
    # Message contact should reflect new email
    expect(message.reload.contact.primary_email).to eq("alice.new@example.com")
    
    # origin_email preserved for audit trail
    expect(message.origin_email).to eq("alice@example.com")
  end
  
  it "enforces unique email per website" do
    website = create(:website)
    
    contact1 = create(:contact, website: website, primary_email: "alice@example.com")
    
    expect {
      create(:contact, website: website, primary_email: "alice@example.com")
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
  
  it "allows same email across websites" do
    website_a = create(:website, subdomain: 'a')
    website_b = create(:website, subdomain: 'b')
    
    contact_a = create(:contact, website: website_a, primary_email: "alice@example.com")
    contact_b = create(:contact, website: website_b, primary_email: "alice@example.com")
    
    expect(contact_a.primary_email).to eq(contact_b.primary_email)
    expect(contact_a.id).not_to eq(contact_b.id)  # Different records
  end
end
```

---

## Issue #4: Admin Views Don't Show Relationships

### Problem Description

The admin interface shows contacts and messages separately without links between them. An admin viewing a message can't easily see the associated contact, and vice versa.

### Current Views

**Message Show View:** (app/views/site_admin/messages/show.html.erb)
```erb
<div class="max-w-4xl mx-auto">
  <dl>
    <div>
      <dt>Email</dt>
      <dd><%= @message.origin_email.presence || 'N/A' %></dd>
    </div>
    <div>
      <dt>Date</dt>
      <dd><%= format_date(@message.created_at) %></dd>
    </div>
    <div>
      <dt>Message</dt>
      <dd class="whitespace-pre-wrap"><%= @message.content %></dd>
    </div>
  </dl>
</div>
<!-- ❌ NO CONTACT INFO, NO LINK TO CONTACT -->
```

**Contact Show View:** (app/views/site_admin/contacts/show.html.erb)
```erb
<div class="max-w-4xl mx-auto">
  <dl>
    <div><dt>Email</dt><dd><%= @contact.primary_email %></dd></div>
    <div><dt>Name</dt><dd><%= [@contact.first_name, @contact.last_name].join(' ') %></dd></div>
    <div><dt>Created</dt><dd><%= format_date(@contact.created_at) %></dd></div>
    <div><dt>Updated</dt><dd><%= format_date(@contact.updated_at) %></dd></div>
  </dl>
</div>
<!-- ❌ NO MESSAGE HISTORY, NO LINK TO MESSAGES -->
```

### Solution

**Enhancement 1: Add Contact Info to Message Show**

```erb
<!-- app/views/site_admin/messages/show.html.erb -->
<div class="max-w-4xl mx-auto">
  <div class="mb-6">
    <%= link_to '← Back to Messages', site_admin_messages_path, 
                class: 'text-blue-600 hover:text-blue-800' %>
  </div>

  <div class="bg-white rounded-lg shadow overflow-hidden">
    <div class="px-6 py-4 border-b border-gray-200">
      <h1 class="text-2xl font-bold text-gray-900">Message Details</h1>
    </div>

    <div class="p-6">
      <!-- Contact Card (if associated) -->
      <% if @message.contact.present? %>
        <div class="mb-6 p-4 bg-blue-50 border-l-4 border-blue-500 rounded">
          <h3 class="font-semibold text-gray-900 mb-2">Associated Contact</h3>
          <dl class="grid grid-cols-1 gap-x-4 gap-y-2 text-sm">
            <div>
              <dt class="text-gray-500">Name</dt>
              <dd class="text-gray-900">
                <%= link_to [@message.contact.first_name, @message.contact.last_name].compact.join(' '),
                            site_admin_contact_path(@message.contact),
                            class: 'text-blue-600 hover:text-blue-800' %>
              </dd>
            </div>
            <div>
              <dt class="text-gray-500">Email</dt>
              <dd class="text-gray-900"><%= @message.contact.primary_email %></dd>
            </div>
            <div>
              <dt class="text-gray-500">Phone</dt>
              <dd class="text-gray-900"><%= @message.contact.primary_phone_number || 'Not provided' %></dd>
            </div>
            <div class="pt-2">
              <%= link_to 'View All Messages from this Contact', 
                          site_admin_messages_path(search: @message.contact.primary_email),
                          class: 'text-blue-600 hover:text-blue-800 text-sm' %>
            </div>
          </dl>
        </div>
      <% else %>
        <div class="mb-6 p-4 bg-yellow-50 border-l-4 border-yellow-500 rounded">
          <p class="text-yellow-800 text-sm">⚠️ No contact associated with this message</p>
        </div>
      <% end %>
      
      <!-- Message Content -->
      <dl class="grid grid-cols-1 gap-x-4 gap-y-6">
        <div>
          <dt class="text-sm font-medium text-gray-500">From Email</dt>
          <dd class="mt-1 text-sm text-gray-900"><%= @message.origin_email %></dd>
        </div>

        <div>
          <dt class="text-sm font-medium text-gray-500">Subject</dt>
          <dd class="mt-1 text-sm text-gray-900"><%= @message.title.presence || 'No subject' %></dd>
        </div>

        <div>
          <dt class="text-sm font-medium text-gray-500">Date</dt>
          <dd class="mt-1 text-sm text-gray-900"><%= format_date(@message.created_at) %></dd>
        </div>

        <% if @message.content.present? %>
          <div>
            <dt class="text-sm font-medium text-gray-500">Message</dt>
            <dd class="mt-1 text-sm text-gray-900 whitespace-pre-wrap bg-gray-50 p-3 rounded">
              <%= @message.content %>
            </dd>
          </div>
        <% end %>

        <!-- Delivery Info -->
        <div class="border-t pt-4">
          <h3 class="font-semibold text-gray-900 mb-3">Delivery Status</h3>
          <dl class="grid grid-cols-1 gap-2">
            <div>
              <dt class="text-xs text-gray-500 font-medium">Status</dt>
              <dd class="text-sm text-gray-900">
                <% if @message.delivery_success %>
                  <span class="text-green-600 font-semibold">✓ Delivered</span>
                <% else %>
                  <span class="text-red-600 font-semibold">✗ Not Delivered</span>
                <% end %>
              </dd>
            </div>
            <% if @message.delivered_at.present? %>
              <div>
                <dt class="text-xs text-gray-500 font-medium">Delivered At</dt>
                <dd class="text-sm text-gray-900"><%= format_date(@message.delivered_at) %></dd>
              </div>
            <% end %>
            <% if @message.delivery_error.present? %>
              <div>
                <dt class="text-xs text-gray-500 font-medium">Error</dt>
                <dd class="text-sm text-red-900 bg-red-50 p-2 rounded"><%= @message.delivery_error %></dd>
              </div>
            <% end %>
          </dl>
        </div>

        <!-- Read Status -->
        <div class="border-t pt-4">
          <dt class="text-sm font-medium text-gray-500">Read Status</dt>
          <dd class="mt-1">
            <% if @message.read? %>
              <span class="text-green-600">✓ Read</span>
            <% else %>
              <span class="text-gray-500">Unread</span>
            <% end %>
          </dd>
        </div>
      </dl>
    </div>
  </div>
</div>
```

**Enhancement 2: Add Message History to Contact Show**

```erb
<!-- app/views/site_admin/contacts/show.html.erb -->
<div class="max-w-4xl mx-auto">
  <div class="mb-6">
    <%= link_to '← Back to Contacts', site_admin_contacts_path, 
                class: 'text-blue-600 hover:text-blue-800' %>
  </div>

  <!-- Contact Details Card -->
  <div class="bg-white rounded-lg shadow overflow-hidden mb-6">
    <div class="px-6 py-4 border-b border-gray-200">
      <h1 class="text-2xl font-bold text-gray-900">Contact Details</h1>
    </div>

    <div class="p-6">
      <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
        <div>
          <dt class="text-sm font-medium text-gray-500">Email</dt>
          <dd class="mt-1 text-sm text-gray-900"><%= @contact.primary_email %></dd>
        </div>

        <div>
          <dt class="text-sm font-medium text-gray-500">Name</dt>
          <dd class="mt-1 text-sm text-gray-900">
            <%= [@contact.first_name, @contact.last_name].compact.join(' ').presence || 'Not provided' %>
          </dd>
        </div>

        <div>
          <dt class="text-sm font-medium text-gray-500">Phone</dt>
          <dd class="mt-1 text-sm text-gray-900"><%= @contact.primary_phone_number.presence || 'Not provided' %></dd>
        </div>

        <div>
          <dt class="text-sm font-medium text-gray-500">Created</dt>
          <dd class="mt-1 text-sm text-gray-900"><%= format_date(@contact.created_at) %></dd>
        </div>

        <div>
          <dt class="text-sm font-medium text-gray-500">Updated</dt>
          <dd class="mt-1 text-sm text-gray-900"><%= format_date(@contact.updated_at) %></dd>
        </div>

        <div>
          <dt class="text-sm font-medium text-gray-500">Messages</dt>
          <dd class="mt-1 text-sm text-gray-900">
            <%= link_to "#{@contact.messages.count} message(s)",
                        site_admin_messages_path(search: @contact.primary_email),
                        class: 'text-blue-600 hover:text-blue-800' %>
          </dd>
        </div>
      </dl>
    </div>
  </div>

  <!-- Messages History -->
  <div class="bg-white rounded-lg shadow overflow-hidden">
    <div class="px-6 py-4 border-b border-gray-200">
      <h2 class="text-xl font-bold text-gray-900">Message History</h2>
    </div>

    <% if @contact.messages.any? %>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Subject</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <% @contact.messages.order(created_at: :desc).limit(10).each do |message| %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= format_date(message.created_at) %>
                </td>
                <td class="px-6 py-4 text-sm text-gray-900">
                  <%= message.title.presence || message.content.truncate(50) %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <% if message.read? %>
                    <span class="text-green-600">✓ Read</span>
                  <% else %>
                    <span class="text-blue-600 font-semibold">Unread</span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <%= link_to 'View', site_admin_message_path(message), 
                              class: 'text-blue-600 hover:text-blue-800' %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      
      <% if @contact.messages.count > 10 %>
        <div class="px-6 py-4 text-sm text-gray-600 border-t">
          <%= link_to "View all #{@contact.messages.count} messages",
                      site_admin_messages_path(search: @contact.primary_email),
                      class: 'text-blue-600 hover:text-blue-800' %>
        </div>
      <% end %>
    <% else %>
      <div class="px-6 py-4 text-center text-gray-500">
        No messages from this contact
      </div>
    <% end %>
  </div>
</div>
```

**Controller Updates Needed:**

```ruby
# app/controllers/site_admin/contacts_controller.rb
class ContactsController < SiteAdminController
  include SiteAdminIndexable

  indexable_config model: Pwb::Contact,
                   search_columns: %i[primary_email first_name last_name],
                   limit: 100,
                   includes: [:messages]  # ← Add eager loading
end

# app/controllers/site_admin/messages_controller.rb
class MessagesController < SiteAdminController
  include SiteAdminIndexable

  indexable_config model: Pwb::Message,
                   search_columns: %i[origin_email content],
                   limit: 100,
                   includes: [:contact]  # ← Add eager loading
end
```

---

## Implementation Checklist

### Phase 1: Data Safety (Immediate)
- [ ] Add FK constraint on `contact_id`
- [ ] Fix email uniqueness to `(website_id, primary_email)`
- [ ] Add test for cross-tenant isolation

### Phase 2: Creation Flow (Next Sprint)
- [ ] Refactor contact creation to use single transaction
- [ ] Create ContactInquiryService
- [ ] Update all 3 entry points (ContactUs, Props, GraphQL)
- [ ] Add transaction tests

### Phase 3: Scoping (Before Production)
- [ ] Add scoped association to Contact model
- [ ] Update Contact tests
- [ ] Update Message tests
- [ ] Make contact required on Message

### Phase 4: UX Improvements (Optional)
- [ ] Enhance contact show view with message history
- [ ] Enhance message show view with contact info
- [ ] Add message count badge to contact index
- [ ] Add contact link to message index

### Phase 5: Cleanup (Later)
- [ ] Remove legacy `client_id` field
- [ ] Remove `origin_email` if moving to contact email only
- [ ] Document email strategy
- [ ] Review PwbTenant:: variants

---

## Summary of Changes

```diff
# Models
+ has_many :messages, -> { where(website_id: website_id) }  # Scoped
+ belongs_to :contact, optional: false  # Required

# Migrations
+ Foreign key constraint on contact_id
+ Compound unique index on (website_id, primary_email)

# Controllers
+ Single-transaction creation
+ Eager loading includes

# Views
+ Contact info on message show
+ Message history on contact show
+ Links between related records

# Services
+ ContactInquiryService for encapsulation
```

---

**Created:** 2025-12-28
**Purpose:** Detailed issue analysis with concrete solutions
**For Overview:** See CONTACTS_AND_MESSAGES_ARCHITECTURE.md
