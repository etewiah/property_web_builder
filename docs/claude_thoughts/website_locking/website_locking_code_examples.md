# Website Locking - Code Examples & Implementation Details

## 1. Database Schema Changes

### Migration File
```ruby
# db/migrate/20260107_add_website_locking_support.rb

class AddWebsiteLockingSupport < ActiveRecord::Migration[7.0]
  def change
    # Add locking fields to websites table
    add_column :pwb_websites, :locked_mode, :boolean, default: false, null: false
    add_column :pwb_websites, :locked_pages_updated_at, :datetime
    add_index :pwb_websites, :locked_mode
    
    # Create compiled_pages table for storing pre-rendered HTML
    create_table :pwb_compiled_pages do |t|
      t.bigint :website_id, null: false, index: true
      t.string :page_slug, null: false
      t.string :locale, default: "en", null: false
      t.text :compiled_html, null: false
      t.jsonb :metadata, default: {}  # title, seo_title, meta_description, etc.
      
      t.timestamps
      
      t.foreign_key :pwb_websites, column: :website_id
      t.index [:website_id, :page_slug, :locale], unique: true, 
              name: "index_compiled_pages_unique_per_website_locale"
    end
  end
end
```

---

## 2. Models

### CompiledPage Model
```ruby
# app/models/pwb/compiled_page.rb

module Pwb
  class CompiledPage < ApplicationRecord
    self.table_name = 'pwb_compiled_pages'
    
    belongs_to :website, class_name: 'Pwb::Website'
    
    validates :page_slug, :locale, :compiled_html, presence: true
    validates :website_id, :page_slug, :locale, 
              uniqueness: { scope: [:website_id, :page_slug, :locale],
                           message: "is already compiled for this website and locale" }
    
    scope :for_website, ->(website) { where(website_id: website.id) }
    scope :for_locale, ->(locale) { where(locale: locale.to_s) }
    
    # Find compiled page for rendering
    def self.find_for_rendering(website_id, page_slug, locale)
      find_by(
        website_id: website_id,
        page_slug: page_slug || "home",
        locale: locale.to_s
      )
    end
    
    # Delete all compiled pages for a website
    def self.clear_for_website(website_id)
      where(website_id: website_id).delete_all
    end
  end
end
```

### Website Model Extensions
```ruby
# app/models/pwb/website.rb (add these methods)

module Pwb
  class Website < ApplicationRecord
    # ... existing code ...
    
    has_many :compiled_pages, class_name: 'Pwb::CompiledPage', 
             dependent: :delete_all
    
    # ===================
    # Website Locking
    # ===================
    
    # Lock the website and compile all pages
    def lock_website
      Pwb::PageCompiler.new(self).compile_all_pages
      update!(locked_mode: true, locked_pages_updated_at: Time.current)
    end
    
    # Unlock the website and clear compiled pages
    def unlock_website
      Pwb::CompiledPage.clear_for_website(id)
      update!(locked_mode: false, locked_pages_updated_at: nil)
    end
    
    # Check if website is in locked mode
    def locked_mode?
      locked_mode == true
    end
    
    # Get a compiled page for rendering
    def find_compiled_page(page_slug, locale)
      compiled_pages.find_for_rendering(id, page_slug, locale)
    end
  end
end
```

---

## 3. Page Compiler Service

### PageCompiler Service
```ruby
# app/services/pwb/page_compiler.rb

module Pwb
  class PageCompiler
    attr_reader :website
    
    def initialize(website)
      @website = website
    end
    
    # Compile all visible pages for all supported locales
    def compile_all_pages
      pages_to_compile = website.pages.where(visible: true)
      
      pages_to_compile.each do |page|
        compile_page(page)
      end
      
      Rails.logger.info("Compiled #{pages_to_compile.count} pages for #{website.subdomain}")
    end
    
    # Compile a single page for all locales
    def compile_page(page)
      website.supported_locales.each do |locale|
        compile_page_for_locale(page, locale)
      end
    end
    
    # Compile a single page for a specific locale
    def compile_page_for_locale(page, locale)
      I18n.with_locale(locale) do
        html = render_page(page)
        store_compiled_page(page, html, locale)
      end
    rescue => e
      Rails.logger.error("Failed to compile page #{page.slug} for #{locale}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end
    
    private
    
    # Render a page to HTML string
    def render_page(page)
      content_to_show = []
      page_contents_for_edit = []
      
      page.ordered_visible_page_contents.each do |page_content|
        if page_content.is_rails_part
          # Rails parts can't be compiled - use placeholder
          content_to_show.push nil
          # Optionally: could render a static placeholder
          # content_to_show.push "[Dynamic: #{page_content.page_part_key}]"
        else
          # Get pre-rendered HTML from Content.raw
          content_to_show.push page_content.content&.raw
        end
        page_contents_for_edit.push page_content
      end
      
      # Render the theme template with compiled content
      render_theme_view(page, content_to_show, page_contents_for_edit)
    end
    
    # Render the theme-specific page view
    def render_theme_view(page, content_to_show, page_contents_for_edit)
      theme_name = website.theme_name || 'default'
      
      # Create a view context with necessary helpers/variables
      # This would typically be done via ActionController::Renderer
      html = ApplicationController.renderer.render(
        template: "pwb/pages/show",
        assigns: {
          page: page,
          content_to_show: content_to_show,
          page_contents_for_edit: page_contents_for_edit,
          current_website: website,
          current_agency: website.agency
        },
        layout: false  # We'll handle layout separately if needed
      )
      
      html
    rescue => e
      Rails.logger.error("Error rendering page #{page.slug}: #{e.message}")
      raise
    end
    
    # Store compiled HTML in database
    def store_compiled_page(page, html, locale)
      metadata = {
        title: page.page_title || page.slug,
        seo_title: page.seo_title,
        meta_description: page.meta_description,
        slug: page.slug,
        locale: locale.to_s,
        compiled_at: Time.current.iso8601
      }
      
      Pwb::CompiledPage.upsert(
        {
          website_id: website.id,
          page_slug: page.slug,
          locale: locale.to_s,
          compiled_html: html,
          metadata: metadata
        },
        unique_by: [:website_id, :page_slug, :locale]
      )
    end
  end
end
```

---

## 4. Modified PagesController

### Updated show_page Action
```ruby
# app/controllers/pwb/pages_controller.rb (modified show_page method)

def show_page
  default_page_slug = "home"
  page_slug = params[:page_slug] || default_page_slug
  @page = @current_website.pages.find_by_slug page_slug
  
  if @page.blank?
    @page = @current_website.pages.find_by_slug default_page_slug
  end
  
  # Check if website is locked and we have compiled HTML
  if @current_website.locked_mode?
    compiled_page = @current_website.find_compiled_page(
      @page&.slug,
      I18n.locale
    )
    
    if compiled_page.present?
      # Set aggressive cache headers for locked content
      set_cache_control_headers(
        max_age: 30.days,
        public: true,
        stale_while_revalidate: 90.days
      )
      
      # Render pre-compiled HTML
      return render inline: compiled_page.compiled_html, 
                   locals: { page: @page }
    end
  end
  
  # Fall back to dynamic rendering (existing logic)
  @content_to_show = []
  @page_contents_for_edit = []
  
  if @page.present?
    @page.ordered_visible_page_contents.each do |page_content|
      if page_content.is_rails_part
        @content_to_show.push nil
      else
        @content_to_show.push page_content.content&.raw
      end
      @page_contents_for_edit.push page_content
    end
    
    set_page_seo(@page)
    set_cache_control_headers(
      max_age: 10.minutes,
      public: true,
      stale_while_revalidate: 1.hour
    )
  end
  
  render "/pwb/pages/show"
end
```

---

## 5. Validation to Prevent Changes When Locked

### PageContent Validation
```ruby
# app/models/pwb/page_content.rb (add validation)

class PageContent < ApplicationRecord
  # ... existing code ...
  
  validate :validate_not_locked, on: [:create, :update, :destroy]
  
  private
  
  def validate_not_locked
    if page && page.website&.locked_mode?
      errors.add(:base, "Cannot modify content on a locked website. Unlock the website first.")
    end
  end
end
```

### PagePart Validation
```ruby
# app/models/pwb/page_part.rb (add validation)

class PagePart < ApplicationRecord
  # ... existing code ...
  
  validate :validate_not_locked, on: [:create, :update, :destroy]
  
  private
  
  def validate_not_locked
    if website&.locked_mode?
      errors.add(:base, "Cannot modify page parts on a locked website. Unlock the website first.")
    end
  end
end
```

### Content Validation
```ruby
# app/models/pwb/content.rb (add validation)

class Content < ApplicationRecord
  # ... existing code ...
  
  validate :validate_not_locked, on: [:create, :update, :destroy]
  
  private
  
  def validate_not_locked
    if website&.locked_mode?
      errors.add(:base, "Cannot modify content on a locked website. Unlock the website first.")
    end
  end
end
```

---

## 6. Admin API Endpoints

### Locking API Controller
```ruby
# app/controllers/site_admin/website_locking_controller.rb

module SiteAdmin
  class WebsiteLockingController < SiteAdminController
    before_action :authorize_admin!
    before_action :set_website
    
    # GET /site_admin/websites/:website_id/locking/status
    def status
      render json: {
        locked: @website.locked_mode?,
        locked_at: @website.locked_pages_updated_at,
        compiled_pages_count: @website.compiled_pages.count,
        total_pages: @website.pages.where(visible: true).count
      }
    end
    
    # POST /site_admin/websites/:website_id/locking/lock
    def lock
      begin
        @website.lock_website
        render json: {
          success: true,
          message: "Website locked successfully",
          compiled_pages: @website.compiled_pages.count
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end
    end
    
    # POST /site_admin/websites/:website_id/locking/unlock
    def unlock
      @website.unlock_website
      render json: {
        success: true,
        message: "Website unlocked successfully"
      }
    end
    
    # POST /site_admin/websites/:website_id/locking/recompile
    def recompile
      if @website.locked_mode?
        Pwb::CompiledPage.clear_for_website(@website.id)
        @website.lock_website
        render json: {
          success: true,
          message: "Pages recompiled successfully",
          compiled_pages: @website.compiled_pages.count
        }
      else
        render json: {
          success: false,
          error: "Website is not locked"
        }, status: :unprocessable_entity
      end
    end
    
    private
    
    def set_website
      @website = Pwb::Website.find(params[:website_id])
    end
    
    def authorize_admin!
      unless current_user && current_website.admins.include?(current_user)
        render json: { error: "Unauthorized" }, status: :forbidden
      end
    end
  end
end
```

---

## 7. Rake Tasks

### Locking Management Tasks
```ruby
# lib/tasks/websites.rake

namespace :websites do
  desc "Lock a website and compile all pages"
  task :lock, [:website_id] => :environment do |t, args|
    website = Pwb::Website.find(args[:website_id])
    
    puts "Locking website: #{website.subdomain}"
    website.lock_website
    puts "✓ Website locked"
    puts "✓ #{website.compiled_pages.count} pages compiled"
  end
  
  desc "Unlock a website"
  task :unlock, [:website_id] => :environment do |t, args|
    website = Pwb::Website.find(args[:website_id])
    
    puts "Unlocking website: #{website.subdomain}"
    website.unlock_website
    puts "✓ Website unlocked"
  end
  
  desc "Recompile locked pages"
  task :recompile, [:website_id] => :environment do |t, args|
    website = Pwb::Website.find(args[:website_id])
    
    unless website.locked_mode?
      puts "Website is not locked"
      exit(1)
    end
    
    puts "Recompiling pages for: #{website.subdomain}"
    Pwb::CompiledPage.clear_for_website(website.id)
    website.lock_website
    puts "✓ #{website.compiled_pages.count} pages recompiled"
  end
  
  desc "Check locking status for a website"
  task :lock_status, [:website_id] => :environment do |t, args|
    website = Pwb::Website.find(args[:website_id])
    
    puts "Website: #{website.subdomain}"
    puts "Locked: #{website.locked_mode?}"
    puts "Compiled pages: #{website.compiled_pages.count}"
    puts "Total pages: #{website.pages.where(visible: true).count}"
    puts "Last compiled: #{website.locked_pages_updated_at}"
  end
end
```

---

## 8. Background Job (Optional)

### Async Compilation Job
```ruby
# app/jobs/compile_website_job.rb

class CompileWebsiteJob < ApplicationJob
  queue_as :default
  
  # Compile pages for a website in the background
  def perform(website_id)
    website = Pwb::Website.find(website_id)
    
    Rails.logger.info("Starting compilation for website #{website.subdomain}")
    
    start_time = Time.current
    compiler = Pwb::PageCompiler.new(website)
    compiler.compile_all_pages
    
    duration = Time.current - start_time
    count = website.compiled_pages.count
    
    Rails.logger.info("Completed compilation: #{count} pages in #{duration.round(2)}s")
  rescue => e
    Rails.logger.error("Compilation failed: #{e.message}")
    raise
  end
end

# Usage:
# CompileWebsiteJob.perform_later(website.id)
```

---

## 9. RSpec Tests

### Compilation Service Tests
```ruby
# spec/services/pwb/page_compiler_spec.rb

require 'rails_helper'

describe Pwb::PageCompiler do
  let(:website) { create(:website, supported_locales: ['en', 'es']) }
  let(:page) { create(:page, website: website, visible: true) }
  let(:compiler) { described_class.new(website) }
  
  describe '#compile_all_pages' do
    it 'compiles all visible pages' do
      create_list(:page, 3, website: website, visible: true)
      create(:page, website: website, visible: false)
      
      compiler.compile_all_pages
      
      expect(Pwb::CompiledPage.where(website_id: website.id).count).to eq(6) # 3 pages × 2 locales
    end
  end
  
  describe '#compile_page' do
    it 'compiles page for all locales' do
      compiler.compile_page(page)
      
      expect(Pwb::CompiledPage.where(website_id: website.id, page_slug: page.slug).count).to eq(2)
    end
  end
  
  describe '#compile_page_for_locale' do
    it 'creates CompiledPage record' do
      compiler.compile_page_for_locale(page, :en)
      
      compiled = Pwb::CompiledPage.find_by(
        website_id: website.id,
        page_slug: page.slug,
        locale: 'en'
      )
      
      expect(compiled).to be_present
      expect(compiled.compiled_html).to include('<html')
    end
  end
end
```

### Website Locking Tests
```ruby
# spec/models/pwb/website_spec.rb (add to existing)

describe '#lock_website' do
  let(:website) { create(:website) }
  let!(:page) { create(:page, website: website, visible: true) }
  
  it 'sets locked_mode to true' do
    website.lock_website
    expect(website.reload.locked_mode).to be(true)
  end
  
  it 'compiles all visible pages' do
    website.lock_website
    expect(website.compiled_pages.count).to be > 0
  end
  
  it 'sets locked_pages_updated_at' do
    website.lock_website
    expect(website.reload.locked_pages_updated_at).to be_present
  end
end

describe '#unlock_website' do
  let(:website) { create(:website, locked_mode: true) }
  
  before { create(:compiled_page, website: website) }
  
  it 'deletes all compiled pages' do
    expect {
      website.unlock_website
    }.to change(Pwb::CompiledPage.where(website_id: website.id), :count).to(0)
  end
  
  it 'sets locked_mode to false' do
    website.unlock_website
    expect(website.reload.locked_mode).to be(false)
  end
end
```

### Controller Tests
```ruby
# spec/controllers/pwb/pages_controller_spec.rb (add to existing)

describe PagesController do
  let(:website) { create(:website) }
  let(:page) { create(:page, website: website, visible: true, slug: 'about') }
  
  before { sign_in_website(website) }
  
  context 'when website is locked' do
    let(:compiled_page) { create(:compiled_page, website: website, page_slug: 'about') }
    
    before do
      website.update(locked_mode: true)
      compiled_page
    end
    
    it 'serves compiled HTML' do
      get :show_page, params: { page_slug: 'about' }
      
      expect(response.body).to eq(compiled_page.compiled_html)
    end
    
    it 'sets aggressive cache headers' do
      get :show_page, params: { page_slug: 'about' }
      
      expect(response.headers['Cache-Control']).to include('max-age=2592000') # 30 days
    end
  end
  
  context 'when website is not locked' do
    it 'uses dynamic rendering' do
      get :show_page, params: { page_slug: 'about' }
      
      expect(response).to render_template('pwb/pages/show')
    end
  end
end
```

---

## 10. Configuration

### Routes
```ruby
# config/routes.rb (add)

namespace :site_admin do
  resources :websites do
    scope module: :website_locking do
      get 'locking/status', to: 'locking#status'
      post 'locking/lock', to: 'locking#lock'
      post 'locking/unlock', to: 'locking#unlock'
      post 'locking/recompile', to: 'locking#recompile'
    end
  end
end
```

### Environment Variables
```bash
# .env.example

# Website locking configuration
WEBSITE_LOCKING_ENABLED=true
WEBSITE_LOCKING_CACHE_MAX_AGE=2592000  # 30 days in seconds
WEBSITE_LOCKING_STALE_WHILE_REVALIDATE=7776000  # 90 days in seconds
```

---

## 11. Usage Examples

### From Rails Console
```ruby
# Get a website
website = Pwb::Website.find_by(subdomain: 'mysite')

# Lock the website
website.lock_website
# => Compiles all pages and sets locked_mode = true

# Check status
website.locked_mode?      # => true
website.compiled_pages.count  # => 12 (pages × locales)

# Unlock
website.unlock_website
# => Deletes all compiled pages and sets locked_mode = false

# Programmatic access
compiled = website.find_compiled_page('about', 'en')
compiled.compiled_html
```

### From Rake
```bash
# Lock a website
bundle exec rake websites:lock[123]

# Unlock a website
bundle exec rake websites:unlock[123]

# Check status
bundle exec rake websites:lock_status[123]

# Recompile
bundle exec rake websites:recompile[123]
```

### From API
```bash
# Check locking status
curl https://mysite.com/site_admin/websites/123/locking/status

# Lock website
curl -X POST https://mysite.com/site_admin/websites/123/locking/lock

# Unlock website
curl -X POST https://mysite.com/site_admin/websites/123/locking/unlock

# Recompile pages
curl -X POST https://mysite.com/site_admin/websites/123/locking/recompile
```

---

## 12. Monitoring & Logging

### Logging Example
```ruby
# In PageCompiler
Rails.logger.info({
  event: 'page_compile_start',
  website_id: website.id,
  website_subdomain: website.subdomain,
  pages_count: website.pages.where(visible: true).count,
  locales: website.supported_locales
}.to_json)

Rails.logger.info({
  event: 'page_compile_success',
  website_id: website.id,
  website_subdomain: website.subdomain,
  compiled_pages_count: website.compiled_pages.count,
  duration_seconds: (Time.current - start_time).round(2)
}.to_json)
```

### Monitoring Metrics
```ruby
# Track in your monitoring system (NewRelic, Datadog, etc.)
- Number of locked websites
- Average compilation time per website
- Compiled pages served (cache hit rate)
- Lock/unlock operations
```

---

## 13. Deployment Considerations

### Before Deploying
```bash
# 1. Run migration
bundle exec rake db:migrate

# 2. Test in staging
# - Lock a test website
# - Verify pages render correctly
# - Check cache headers
# - Test unlock process

# 3. Monitor during rollout
# - Watch for compilation errors
# - Monitor response times
# - Track cache hit rates
```

### Zero-Downtime Deployment
```ruby
# 1. Deploy code (locked_mode checks are backward compatible)
# 2. Run migrations (creates tables, no data changes)
# 3. Feature flag locking (disabled by default)
# 4. Enable locking gradually for websites
# 5. Monitor and rollback if needed
```
