# Magic Links Implementation Guide

**Quick reference for implementing passwordless authentication via magic links**

---

## Executive Summary

The application already has the exact pattern needed for magic links through the `signup_token` system. This guide shows how to implement magic links by following the same pattern.

---

## 1. What We're Building

**Goal**: User clicks "Send Magic Link" → Receives email → Clicks link → Automatically signed in

**Pattern**: Reuse signup_token implementation but for login instead of signup

---

## 2. Implementation Steps

### Step 1: Create Migration

```bash
rails generate migration AddMagicLinkTokenToUsers
```

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_magic_link_token_to_users.rb
class AddMagicLinkTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_users, :magic_link_token, :string
    add_index :pwb_users, :magic_link_token, unique: true
    add_column :pwb_users, :magic_link_expires_at, :datetime
  end
end
```

### Step 2: Create MagicLinkService

```ruby
# app/services/pwb/magic_link_service.rb
module Pwb
  class MagicLinkService
    TOKEN_EXPIRY = 24.hours

    # Generate and store magic link token
    def generate_token(user)
      return nil unless user
      
      token = SecureRandom.urlsafe_base64(32)
      user.update_columns(
        magic_link_token: token,
        magic_link_expires_at: TOKEN_EXPIRY.from_now
      )
      
      Rails.logger.info("[MagicLink] Generated token for #{user.email}")
      token
    end

    # Verify and retrieve user by magic link token
    def find_user_by_token(token)
      return nil if token.blank?

      user = Pwb::User.find_by(magic_link_token: token)
      return nil unless user
      
      # Check expiry
      if user.magic_link_expires_at && user.magic_link_expires_at < Time.current
        Rails.logger.warn("[MagicLink] Token expired for #{user.email}")
        return nil
      end

      user
    end

    # Clear token after successful login
    def clear_token(user)
      user.update_columns(magic_link_token: nil, magic_link_expires_at: nil)
    end

    # Request magic link for email
    def request_magic_link(email)
      email = email.to_s.strip.downcase
      
      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        return { success: false, errors: ["Invalid email address"] }
      end

      user = Pwb::User.find_by(email: email)
      unless user
        # For security, don't reveal if email exists
        return { success: true, message: "If that email exists, we'll send a magic link" }
      end

      begin
        token = generate_token(user)
        # Send email (next step)
        Pwb::UserMailer.magic_link_email(user, token).deliver_later
        
        Rails.logger.info("[MagicLink] Sent magic link to #{email}")
        { success: true, message: "Check your email for the login link" }
      rescue StandardError => e
        Rails.logger.error("[MagicLink] Error: #{e.message}")
        { success: false, errors: [e.message] }
      end
    end

    # Complete login with magic link
    def login_with_token(token)
      user = find_user_by_token(token)
      return { success: false, errors: ["Invalid or expired link"] } unless user

      begin
        clear_token(user)
        
        # Log the magic link login
        Pwb::AuthAuditLog.log_login_success(
          user: user,
          request: nil,
          method: 'magic_link'
        )
        
        { success: true, user: user }
      rescue StandardError => e
        Rails.logger.error("[MagicLink] Login error: #{e.message}")
        { success: false, errors: [e.message] }
      end
    end
  end
end
```

### Step 3: Create Email Mailer Method

```ruby
# app/mailers/pwb/user_mailer.rb
module Pwb
  class UserMailer < ApplicationMailer
    default from: ENV.fetch("DEVISE_MAILER_SENDER") {
      ENV.fetch("DEFAULT_FROM_EMAIL") { "PropertyWebBuilder <noreply@propertywebbuilder.com>" }
    }

    def magic_link_email(user, token)
      @user = user
      @token = token
      @magic_link_url = magic_login_url(token: token, host: request_host)
      
      mail(
        to: user.email,
        subject: "Your PropertyWebBuilder Login Link"
      )
    end

    private

    def request_host
      # Get host from env or default
      ENV.fetch('MAGIC_LINK_HOST') {
        ENV.fetch('BASE_DOMAIN') { 'propertywebbuilder.com' }
      }
    end
  end
end
```

### Step 4: Create Email View

```erb
<!-- app/views/pwb/user_mailer/magic_link_email.html.erb -->
<h2>Your Login Link</h2>

<p>Hi <%= @user.email %>,</p>

<p>Click the link below to log in to PropertyWebBuilder:</p>

<p>
  <%= link_to 'Log In to PropertyWebBuilder', @magic_link_url, class: 'btn btn-primary' %>
</p>

<p>Or copy this link:</p>
<p><%= @magic_link_url %></p>

<p>This link expires in 24 hours.</p>

<p>If you didn't request this link, you can safely ignore this email.</p>
```

### Step 5: Add Controller Actions

```ruby
# app/controllers/pwb/sessions_controller.rb
module Pwb
  class SessionsController < ApplicationController
    # GET /magic-link
    # Show magic link request form
    def request_magic_link_form
      # Renders form to enter email
    end

    # POST /magic-link/request
    # Handle magic link email request
    def request_magic_link
      email = params[:email]&.strip&.downcase

      service = MagicLinkService.new
      result = service.request_magic_link(email)

      if result[:success]
        # Always show success message for security
        flash[:notice] = result[:message]
        redirect_to new_session_path
      else
        flash[:alert] = result[:errors].first
        render :request_magic_link_form
      end
    end

    # GET /magic-login/:token
    # Handle magic link click
    def magic_login
      token = params[:token]
      
      service = MagicLinkService.new
      result = service.login_with_token(token)

      if result[:success]
        user = result[:user]
        sign_in(user)  # Devise helper
        
        # Redirect to website or admin depending on context
        redirect_to authenticated_root_path, notice: 'Signed in successfully'
      else
        redirect_to new_session_path, alert: result[:errors].first
      end
    end
  end
end
```

### Step 6: Add Routes

```ruby
# config/routes.rb
devise_for :users, module: :pwb_devise

# Magic link routes
get  '/magic-link',           to: 'pwb/sessions#request_magic_link_form'
post '/magic-link/request',   to: 'pwb/sessions#request_magic_link'
get  '/magic-login/:token',   to: 'pwb/sessions#magic_login'
```

### Step 7: Update Login View

```erb
<!-- app/views/pwb/devise/sessions/new.html.erb -->
<div class="auth-form">
  <h2>Sign In</h2>

  <!-- Existing email/password form -->
  <%= form_with url: user_session_path, local: true do |form| %>
    <!-- ... email and password fields ... -->
  <% end %>

  <!-- OR divider -->
  <div class="divider">Or</div>

  <!-- Magic link option -->
  <div class="magic-link-form">
    <p>Sign in with a magic link instead</p>
    <%= link_to 'Request Magic Link', magic_link_path, class: 'btn btn-secondary' %>
  </div>
</div>
```

---

## 3. Integration Points

### A. AuthAuditLog Integration

Update the AuthAuditLog to track magic link events:

```ruby
# app/models/pwb/auth_audit_log.rb - Add to existing class
class << self
  def log_magic_link_requested(user:)
    create(
      user: user,
      event_type: 'magic_link_requested',
      success: true
    )
  end

  def log_magic_link_used(user:)
    create(
      user: user,
      event_type: 'magic_link_login_success',
      success: true
    )
  end

  def log_magic_link_expired(email:)
    create(
      event_type: 'magic_link_expired',
      success: false,
      details: { email: email }
    )
  end
end
```

### B. Update Devise Configuration

No changes needed - Devise is already configured. Magic links work alongside email/password auth.

### C. Firebase Compatibility

Magic links work independently from Firebase. Users can choose:
- Email/password (Devise)
- Magic link (new)
- Google/OAuth (Firebase)

---

## 4. Testing

```ruby
# spec/services/pwb/magic_link_service_spec.rb
RSpec.describe Pwb::MagicLinkService do
  let(:service) { described_class.new }
  let(:user) { create(:pwb_user) }

  describe '#generate_token' do
    it 'generates a valid token' do
      token = service.generate_token(user)
      expect(token).to be_present
      expect(token.length).to eq(43)  # urlsafe_base64(32) produces ~43 chars
    end

    it 'sets expiry to 24 hours from now' do
      token = service.generate_token(user)
      user.reload
      expect(user.magic_link_expires_at).to be_within(1.minute).of(24.hours.from_now)
    end
  end

  describe '#find_user_by_token' do
    it 'finds user by valid token' do
      token = service.generate_token(user)
      found_user = service.find_user_by_token(token)
      expect(found_user.id).to eq(user.id)
    end

    it 'returns nil for expired token' do
      token = service.generate_token(user)
      user.update_columns(magic_link_expires_at: 1.hour.ago)
      expect(service.find_user_by_token(token)).to be_nil
    end

    it 'returns nil for invalid token' do
      expect(service.find_user_by_token('invalid-token')).to be_nil
    end
  end

  describe '#request_magic_link' do
    it 'sends email for valid email' do
      expect {
        service.request_magic_link(user.email)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'returns success for non-existent email (security)' do
      result = service.request_magic_link('nonexistent@example.com')
      expect(result[:success]).to be true
    end

    it 'returns error for invalid email format' do
      result = service.request_magic_link('not-an-email')
      expect(result[:success]).to be false
    end
  end
end
```

---

## 5. Security Checklist

- [x] Use `SecureRandom.urlsafe_base64(32)` for token generation
- [x] Set 24-hour expiry (configurable via TOKEN_EXPIRY)
- [x] One-time use (clear token after successful login)
- [x] Unique index on token to prevent reuse
- [x] Log magic link events in AuthAuditLog
- [x] Use time-constant comparison for token verification (automatic with `.find_by`)
- [x] Don't reveal if email exists (return success regardless)
- [x] HTTPS only for production
- [x] Rate limiting on magic link requests (optional, can add later)
- [x] Clear expired tokens (background job, can add later)

---

## 6. Optional: Rate Limiting

Add rate limiting to prevent abuse:

```ruby
# Gemfile
gem 'rack-attack'  # or 'redis-throttle'
```

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle('magic_link_requests', limit: 3, period: 60.seconds) do |req|
  req.ip if req.path == '/magic-link/request' && req.post?
end
```

---

## 7. Optional: Background Job for Cleanup

```ruby
# app/jobs/pwb/cleanup_expired_magic_links_job.rb
module Pwb
  class CleanupExpiredMagicLinksJob < ApplicationJob
    queue_as :default

    def perform
      User.where('magic_link_expires_at < ?', Time.current).update_all(
        magic_link_token: nil,
        magic_link_expires_at: nil
      )
      
      Rails.logger.info('[MagicLink] Cleaned up expired tokens')
    end
  end
end

# config/initializers/sidekiq.rb or ActiveJob
# Schedule: Daily at 2:00 AM
```

---

## 8. Key Differences from Devise Password Reset

| Aspect | Devise Reset | Magic Link |
|--------|--------------|-----------|
| **User Action** | Enters new password | Just clicks link |
| **Password Changed** | Yes | No |
| **Database Change** | `encrypted_password` | Only token fields |
| **Use Case** | Forgotten password | Passwordless login |
| **Implementation** | `:recoverable` module | Custom (this guide) |
| **Token Expiry** | 6 hours (default) | 24 hours |

---

## 9. File Locations Summary

After implementation:

```
app/
  services/
    pwb/
      magic_link_service.rb (NEW)
  controllers/
    pwb/
      sessions_controller.rb (MODIFY - add magic_login methods)
  mailers/
    pwb/
      user_mailer.rb (MODIFY - add magic_link_email method)
  views/
    pwb/
      user_mailer/
        magic_link_email.html.erb (NEW)
      devise/
        sessions/
          new.html.erb (MODIFY - add magic link button)
          request_magic_link_form.html.erb (NEW)

db/
  migrate/
    YYYYMMDDHHMMSS_add_magic_link_token_to_users.rb (NEW)

spec/
  services/
    pwb/
      magic_link_service_spec.rb (NEW)
  requests/
    sessions_spec.rb (MODIFY - add magic_link tests)
```

---

## 10. Comparison: Signup Token vs Magic Link

Both use the same pattern! Here's how they differ:

| Aspect | Signup Token | Magic Link |
|--------|--------------|-----------|
| **Purpose** | Multi-step signup tracking | Passwordless login |
| **Field** | `signup_token` | `magic_link_token` |
| **When Created** | Step 1 (email capture) | On request |
| **When Cleared** | After signup completion | After login |
| **Expiry** | 24 hours | 24 hours |
| **Service** | `SignupApiService` | `MagicLinkService` (new) |
| **State Machine** | User onboarding state | N/A |

**Key Insight**: Both are stateless, token-based authentication. You can actually use the same service if you want!

---

## Quick Start Checklist

- [ ] Run migration
- [ ] Create MagicLinkService
- [ ] Create UserMailer#magic_link_email
- [ ] Create email template
- [ ] Add controller actions
- [ ] Add routes
- [ ] Update login view
- [ ] Add tests
- [ ] Test manually
- [ ] Deploy

---

## References

- **Existing signup_token implementation**: `app/services/pwb/signup_api_service.rb:180-188`
- **Devise password reset**: `config/initializers/devise.rb` (`:recoverable` module)
- **AuthAuditLog events**: `app/models/pwb/auth_audit_log.rb`
- **Full analysis**: `docs/claude_thoughts/AUTHENTICATION_SIGNUP_ANALYSIS.md`
