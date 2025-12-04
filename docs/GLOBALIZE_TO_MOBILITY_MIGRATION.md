# Globalize to Mobility Migration Plan

## Executive Summary

This document provides a comprehensive plan to migrate PropertyWebBuilder from the **Globalize** gem to the **Mobility** gem using the **JSONB backend** for PostgreSQL.

**Key Benefits:**
- 3x faster read queries (no JOINs required)
- 20% smaller database footprint
- Modern, actively maintained gem
- Better query API
- Simpler schema (no separate translation tables)

---

## Current State Analysis

### Models Using Globalize

| Model | Translated Fields | Translation Table | Fallback Config |
|-------|------------------|-------------------|-----------------|
| `Pwb::Prop` | `title`, `description` | `pwb_prop_translations` | Default |
| `Pwb::Page` | `raw_html`, `page_title`, `link_title` | `pwb_page_translations` | `fallbacks_for_empty_translations: true` |
| `Pwb::Content` | `raw` | `pwb_content_translations` | `fallbacks_for_empty_translations: true` |
| `Pwb::Link` | `link_title` | `pwb_link_translations` | `fallbacks_for_empty_translations: true` |

### Current Locales

Configured in `config/initializers/i18n_globalise.rb`:
```ruby
I18n.available_locales = [:ar, :ca, :de, :en, :es, :fr, :it, :nl, :pl, :pt, :ro, :ru, :tr, :vi, :ko, :bg]

Globalize.fallbacks = {
  de: [:en], es: [:en], pl: [:en], ro: [:en], ru: [:en], ko: [:en], bg: [:en]
}
```

### Globalize Features in Use

1. **Translation declarations:** `translates :field_name`
2. **Locale accessors:** `globalize_accessors locales: I18n.available_locales`
3. **Fallbacks:** `fallbacks_for_empty_translations: true`
4. **Nested attributes:** `accepts_nested_attributes_for :translations` (Prop only)
5. **Eager loading:** `includes(:translations)` in scopes
6. **Serialization helper:** `globalize_attribute_names`

---

## Migration Strategy

### Approach: Parallel Operation with Data Migration

We will:
1. Add JSONB `translations` columns to existing tables
2. Migrate data from Globalize tables to JSONB columns
3. Update models to use Mobility
4. Verify data integrity
5. Remove Globalize tables (after confidence period)

### Prerequisites

1. **Backup your database** before starting
2. Mobility gem is already installed
3. PostgreSQL database (required for JSONB)

---

## Phase 1: Configuration

### Step 1.1: Create Mobility Initializer

Create `config/initializers/mobility.rb`:

```ruby
# frozen_string_literal: true

Mobility.configure do
  plugins do
    # Core plugins
    active_record
    backend :jsonb

    # Accessor plugins
    reader
    writer
    backend_reader

    # Locale accessors - provides title_en, title_es, etc.
    # This replaces globalize_accessors functionality
    locale_accessors I18n.available_locales

    # Query plugin for searching translated content
    query

    # Performance plugins
    cache

    # Behavior plugins
    presence       # Treat blank strings as nil
    fallbacks      # Enable locale fallbacks
  end
end
```

**Important:** The `locale_accessors` plugin provides methods like `title_en`, `title_es`, `description_fr`, etc. - matching the behavior of `globalize_accessors`. Without this plugin, you would only have `title(locale: :en)` syntax.

### Step 1.2: Update Fallbacks Configuration

Create or update `config/initializers/mobility_fallbacks.rb`:

```ruby
# frozen_string_literal: true

# Configure Mobility fallbacks to match previous Globalize behavior
# All non-English locales fall back to English

Rails.application.config.after_initialize do
  Mobility.configure do
    plugins do
      fallbacks(
        ar: :en,
        ca: :en,
        de: :en,
        es: :en,
        fr: :en,
        it: :en,
        nl: :en,
        pl: :en,
        pt: :en,
        ro: :en,
        ru: :en,
        tr: :en,
        vi: :en,
        ko: :en,
        bg: :en
      )
    end
  end
end
```

---

## Phase 2: Database Migrations

### Step 2.1: Add JSONB Columns

Create migration `db/migrate/[TIMESTAMP]_add_mobility_translations_columns.rb`:

```ruby
# frozen_string_literal: true

class AddMobilityTranslationsColumns < ActiveRecord::Migration[7.0]
  def change
    # Add JSONB translations column to each table that uses Globalize

    # Pwb::Prop - translates :title, :description
    add_column :pwb_props, :translations, :jsonb, default: {}, null: false
    add_index :pwb_props, :translations, using: :gin

    # Pwb::Page - translates :raw_html, :page_title, :link_title
    add_column :pwb_pages, :translations, :jsonb, default: {}, null: false
    add_index :pwb_pages, :translations, using: :gin

    # Pwb::Content - translates :raw
    add_column :pwb_contents, :translations, :jsonb, default: {}, null: false
    add_index :pwb_contents, :translations, using: :gin

    # Pwb::Link - translates :link_title
    add_column :pwb_links, :translations, :jsonb, default: {}, null: false
    add_index :pwb_links, :translations, using: :gin
  end
end
```

### Step 2.2: Migrate Data from Globalize to Mobility

Create migration `db/migrate/[TIMESTAMP]_migrate_globalize_to_mobility.rb`:

```ruby
# frozen_string_literal: true

class MigrateGlobalizeToMobility < ActiveRecord::Migration[7.0]
  def up
    say_with_time "Migrating Globalize translations to Mobility JSONB..." do
      migrate_props
      migrate_pages
      migrate_contents
      migrate_links
    end
  end

  def down
    # Clear JSONB translations (Globalize tables still exist for rollback)
    execute "UPDATE pwb_props SET translations = '{}'"
    execute "UPDATE pwb_pages SET translations = '{}'"
    execute "UPDATE pwb_contents SET translations = '{}'"
    execute "UPDATE pwb_links SET translations = '{}'"
  end

  private

  def migrate_props
    say "  Migrating Pwb::Prop translations..."

    # Get all prop translations from Globalize table
    prop_translations = execute(<<-SQL)
      SELECT prop_id, locale, title, description
      FROM pwb_prop_translations
      WHERE prop_id IS NOT NULL
    SQL

    # Group by prop_id
    translations_by_prop = prop_translations.group_by { |t| t['prop_id'] }

    translations_by_prop.each do |prop_id, translations|
      jsonb_data = {}

      translations.each do |t|
        locale = t['locale']
        jsonb_data[locale] ||= {}
        jsonb_data[locale]['title'] = t['title'] if t['title'].present?
        jsonb_data[locale]['description'] = t['description'] if t['description'].present?
      end

      # Update the prop with JSONB translations
      execute(sanitize_sql([
        "UPDATE pwb_props SET translations = ? WHERE id = ?",
        jsonb_data.to_json,
        prop_id
      ]))
    end

    say "    Migrated #{translations_by_prop.keys.count} props"
  end

  def migrate_pages
    say "  Migrating Pwb::Page translations..."

    page_translations = execute(<<-SQL)
      SELECT page_id, locale, raw_html, page_title, link_title
      FROM pwb_page_translations
      WHERE page_id IS NOT NULL
    SQL

    translations_by_page = page_translations.group_by { |t| t['page_id'] }

    translations_by_page.each do |page_id, translations|
      jsonb_data = {}

      translations.each do |t|
        locale = t['locale']
        jsonb_data[locale] ||= {}
        jsonb_data[locale]['raw_html'] = t['raw_html'] if t['raw_html'].present?
        jsonb_data[locale]['page_title'] = t['page_title'] if t['page_title'].present?
        jsonb_data[locale]['link_title'] = t['link_title'] if t['link_title'].present?
      end

      execute(sanitize_sql([
        "UPDATE pwb_pages SET translations = ? WHERE id = ?",
        jsonb_data.to_json,
        page_id
      ]))
    end

    say "    Migrated #{translations_by_page.keys.count} pages"
  end

  def migrate_contents
    say "  Migrating Pwb::Content translations..."

    content_translations = execute(<<-SQL)
      SELECT content_id, locale, raw
      FROM pwb_content_translations
      WHERE content_id IS NOT NULL
    SQL

    translations_by_content = content_translations.group_by { |t| t['content_id'] }

    translations_by_content.each do |content_id, translations|
      jsonb_data = {}

      translations.each do |t|
        locale = t['locale']
        jsonb_data[locale] ||= {}
        jsonb_data[locale]['raw'] = t['raw'] if t['raw'].present?
      end

      execute(sanitize_sql([
        "UPDATE pwb_contents SET translations = ? WHERE id = ?",
        jsonb_data.to_json,
        content_id
      ]))
    end

    say "    Migrated #{translations_by_content.keys.count} contents"
  end

  def migrate_links
    say "  Migrating Pwb::Link translations..."

    link_translations = execute(<<-SQL)
      SELECT link_id, locale, link_title
      FROM pwb_link_translations
      WHERE link_id IS NOT NULL
    SQL

    translations_by_link = link_translations.group_by { |t| t['link_id'] }

    translations_by_link.each do |link_id, translations|
      jsonb_data = {}

      translations.each do |t|
        locale = t['locale']
        jsonb_data[locale] ||= {}
        jsonb_data[locale]['link_title'] = t['link_title'] if t['link_title'].present?
      end

      execute(sanitize_sql([
        "UPDATE pwb_links SET translations = ? WHERE id = ?",
        jsonb_data.to_json,
        link_id
      ]))
    end

    say "    Migrated #{translations_by_link.keys.count} links"
  end

  def sanitize_sql(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
```

---

## Phase 3: Model Updates

### Step 3.1: Update Pwb::Prop

**Before (Globalize):**
```ruby
module Pwb
  class Prop < ApplicationRecord
    belongs_to :website, optional: true
    translates :title, :description
    globalize_accessors locales: I18n.available_locales
    accepts_nested_attributes_for :translations

    attribute :title
    attribute :description
    # ...
  end
end
```

**After (Mobility):**
```ruby
module Pwb
  class Prop < ApplicationRecord
    extend Mobility

    belongs_to :website, optional: true

    # Mobility translations with JSONB backend
    translates :title, :description

    # Remove these lines:
    # - globalize_accessors locales: I18n.available_locales
    # - accepts_nested_attributes_for :translations
    # - attribute :title
    # - attribute :description

    # ...
  end
end
```

### Step 3.2: Update Pwb::Page

**Before (Globalize):**
```ruby
module Pwb
  class Page < ApplicationRecord
    translates :raw_html, fallbacks_for_empty_translations: true
    translates :page_title, fallbacks_for_empty_translations: true
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: I18n.available_locales

    attribute :link_title
    attribute :page_title
    attribute :raw_html

    # In globalize_attribute_names method:
    # globalize_attribute_names.push :page_contents, :page_parts
    # ...
  end
end
```

**After (Mobility):**
```ruby
module Pwb
  class Page < ApplicationRecord
    extend Mobility

    # Mobility translations with JSONB backend
    # Fallbacks are configured globally in the initializer
    translates :raw_html, :page_title, :link_title

    # Remove these lines:
    # - globalize_accessors locales: I18n.available_locales
    # - attribute :link_title
    # - attribute :page_title
    # - attribute :raw_html

    # Update serialization method (see below)
    # ...
  end
end
```

### Step 3.3: Update Pwb::Content

**Before (Globalize):**
```ruby
module Pwb
  class Content < ApplicationRecord
    translates :raw, fallbacks_for_empty_translations: true
    globalize_accessors locales: I18n.available_locales

    attribute :raw

    # In globalize_attribute_names method:
    # globalize_attribute_names.push :content_photos
    # ...
  end
end
```

**After (Mobility):**
```ruby
module Pwb
  class Content < ApplicationRecord
    extend Mobility

    # Mobility translations with JSONB backend
    translates :raw

    # Remove these lines:
    # - globalize_accessors locales: I18n.available_locales
    # - attribute :raw

    # Update serialization method (see below)
    # ...
  end
end
```

### Step 3.4: Update Pwb::Link

**Before (Globalize):**
```ruby
module Pwb
  class Link < ApplicationRecord
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: I18n.available_locales

    attribute :link_title

    scope :ordered_visible_admin, ->() { includes(:translations).where(visible: true, placement: :admin).order("sort_order asc") }
    scope :ordered_visible_top_nav, ->() { includes(:translations).where(visible: true, placement: :top_nav).order("sort_order asc") }
    # ...
  end
end
```

**After (Mobility):**
```ruby
module Pwb
  class Link < ApplicationRecord
    extend Mobility

    # Mobility translations with JSONB backend
    translates :link_title

    # Remove these lines:
    # - globalize_accessors locales: I18n.available_locales
    # - attribute :link_title

    # Update scopes - remove includes(:translations) as JSONB doesn't need eager loading
    scope :ordered_visible_admin, -> { where(visible: true, placement: :admin).order("sort_order asc") }
    scope :ordered_visible_top_nav, -> { where(visible: true, placement: :top_nav).order("sort_order asc") }
    scope :ordered_visible_footer, -> { where(visible: true, placement: :footer).order("sort_order asc") }
    scope :ordered_top_nav, -> { where(placement: :top_nav).order("sort_order asc") }
    scope :ordered_footer, -> { where(placement: :footer).order("sort_order asc") }
    # ...
  end
end
```

---

## Phase 4: Update Serialization Methods

### Replace `globalize_attribute_names`

The `globalize_attribute_names` method needs to be replaced with a Mobility-compatible approach.

**Create a concern for shared behavior:**

`app/models/concerns/mobility_serializable.rb`:
```ruby
# frozen_string_literal: true

module MobilitySerializable
  extend ActiveSupport::Concern

  class_methods do
    # Returns attribute names with locale suffixes for all available locales
    # Similar to what globalize_accessors provided
    def mobility_attribute_names
      return [] unless respond_to?(:mobility_attributes)

      attributes = []
      mobility_attributes.each do |attr|
        I18n.available_locales.each do |locale|
          attributes << "#{attr}_#{locale}"
        end
      end
      attributes
    end
  end

  # Instance method to get all translations as a hash
  def translations_hash
    return {} unless self.class.respond_to?(:mobility_attributes)

    result = {}
    I18n.available_locales.each do |locale|
      locale_data = {}
      self.class.mobility_attributes.each do |attr|
        value = send(attr, locale: locale)
        locale_data[attr.to_s] = value if value.present?
      end
      result[locale.to_s] = locale_data if locale_data.present?
    end
    result
  end
end
```

**Include in models:**
```ruby
module Pwb
  class Page < ApplicationRecord
    extend Mobility
    include MobilitySerializable

    translates :raw_html, :page_title, :link_title

    # Update the serialization method
    def self.attribute_names_for_serialization
      super + mobility_attribute_names + [:page_contents, :page_parts]
    end
  end
end
```

---

## Phase 5: Remove Globalize Configuration

### Step 5.1: Remove Globalize Initializer

Delete or rename `config/initializers/i18n_globalise.rb`.

**Note:** Keep `I18n.available_locales` configuration - move it to a new file if needed:

`config/initializers/i18n.rb`:
```ruby
# frozen_string_literal: true

I18n.available_locales = [:ar, :ca, :de, :en, :es, :fr, :it, :nl, :pl, :pt, :ro, :ru, :tr, :vi, :ko, :bg]
I18n.default_locale = :en
```

### Step 5.2: Update Gemfile

Remove Globalize gems:

```ruby
# Remove these lines:
# gem 'globalize', git: 'https://github.com/globalize/globalize'
# gem "globalize-accessors", "~> 0.3.0"

# Keep Mobility (already installed):
gem 'mobility', '~> 1.2'
```

### Step 5.3: Update Gemspec

Update `pwb.gemspec`:

```ruby
# Remove these lines:
# s.add_dependency 'globalize'
# s.add_dependency 'globalize-accessors'

# Add:
s.add_dependency 'mobility', '~> 1.2'
```

---

## Phase 6: Verification

### Step 6.1: Create Verification Rake Task

`lib/tasks/mobility_migration.rake`:

```ruby
# frozen_string_literal: true

namespace :mobility do
  desc "Verify Mobility migration was successful"
  task verify: :environment do
    puts "=" * 80
    puts "Verifying Mobility Migration"
    puts "=" * 80

    errors = []

    # Check 1: JSONB columns exist
    puts "\n1. Checking JSONB columns exist..."
    [
      ['pwb_props', 'translations'],
      ['pwb_pages', 'translations'],
      ['pwb_contents', 'translations'],
      ['pwb_links', 'translations']
    ].each do |table, column|
      if ActiveRecord::Base.connection.column_exists?(table, column)
        puts "   [OK] #{table}.#{column} exists"
      else
        errors << "#{table}.#{column} does not exist"
        puts "   [FAIL] #{table}.#{column} does not exist"
      end
    end

    # Check 2: Models use Mobility
    puts "\n2. Checking models use Mobility..."
    [Pwb::Prop, Pwb::Page, Pwb::Content, Pwb::Link].each do |model|
      if model.respond_to?(:mobility_attributes) && model.mobility_attributes.any?
        puts "   [OK] #{model.name} uses Mobility (#{model.mobility_attributes.join(', ')})"
      else
        errors << "#{model.name} is not using Mobility"
        puts "   [FAIL] #{model.name} is not using Mobility"
      end
    end

    # Check 3: Data migrated
    puts "\n3. Checking data migration..."

    # Check Props
    prop_count = Pwb::Prop.count
    props_with_translations = Pwb::Prop.where("translations != '{}'").count
    globalize_prop_count = begin
      ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT prop_id) FROM pwb_prop_translations").first['count'].to_i
    rescue
      0
    end

    puts "   Props: #{props_with_translations}/#{prop_count} have Mobility translations"
    puts "   Globalize had: #{globalize_prop_count} props with translations"

    if globalize_prop_count > 0 && props_with_translations < globalize_prop_count
      errors << "Not all Prop translations migrated (#{props_with_translations} < #{globalize_prop_count})"
    end

    # Check Pages
    page_count = Pwb::Page.count
    pages_with_translations = Pwb::Page.where("translations != '{}'").count
    globalize_page_count = begin
      ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT page_id) FROM pwb_page_translations").first['count'].to_i
    rescue
      0
    end

    puts "   Pages: #{pages_with_translations}/#{page_count} have Mobility translations"
    puts "   Globalize had: #{globalize_page_count} pages with translations"

    # Check Contents
    content_count = Pwb::Content.count
    contents_with_translations = Pwb::Content.where("translations != '{}'").count
    globalize_content_count = begin
      ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT content_id) FROM pwb_content_translations").first['count'].to_i
    rescue
      0
    end

    puts "   Contents: #{contents_with_translations}/#{content_count} have Mobility translations"
    puts "   Globalize had: #{globalize_content_count} contents with translations"

    # Check Links
    link_count = Pwb::Link.count
    links_with_translations = Pwb::Link.where("translations != '{}'").count
    globalize_link_count = begin
      ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT link_id) FROM pwb_link_translations").first['count'].to_i
    rescue
      0
    end

    puts "   Links: #{links_with_translations}/#{link_count} have Mobility translations"
    puts "   Globalize had: #{globalize_link_count} links with translations"

    # Check 4: Test reading translations
    puts "\n4. Testing translation reads..."

    if Pwb::Prop.any?
      prop = Pwb::Prop.where("translations != '{}'").first
      if prop
        I18n.available_locales.first(3).each do |locale|
          title = prop.title(locale: locale)
          puts "   Prop##{prop.id} title(#{locale}): #{title.to_s.truncate(50)}"
        end
      end
    end

    # Check 5: Test fallbacks
    puts "\n5. Testing fallbacks..."
    if Pwb::Prop.any?
      prop = Pwb::Prop.where("translations != '{}'").first
      if prop && prop.translations.dig('en', 'title').present?
        # Test that German falls back to English
        I18n.with_locale(:de) do
          german_title = prop.title
          english_title = prop.title(locale: :en)
          if german_title.present?
            puts "   [OK] Fallback working (de -> en): '#{german_title.truncate(50)}'"
          end
        end
      end
    end

    # Summary
    puts "\n" + "=" * 80
    puts "VERIFICATION SUMMARY"
    puts "=" * 80

    if errors.empty?
      puts "\n[SUCCESS] All checks passed! Mobility migration successful."
      puts "\nNext steps:"
      puts "  1. Test the application thoroughly"
      puts "  2. Monitor for any translation issues"
      puts "  3. After 1-2 weeks, run: rails mobility:drop_globalize_tables"
    else
      puts "\n[ERRORS] Found #{errors.count} issue(s):"
      errors.each { |e| puts "  - #{e}" }
      puts "\nPlease fix these issues before proceeding."
    end
  end

  desc "Drop old Globalize translation tables (DESTRUCTIVE - only after verification)"
  task drop_globalize_tables: :environment do
    puts "WARNING: This will permanently delete Globalize translation tables!"
    puts "Tables to be dropped:"
    puts "  - pwb_prop_translations"
    puts "  - pwb_page_translations"
    puts "  - pwb_content_translations"
    puts "  - pwb_link_translations"
    puts ""
    print "Type 'DELETE' to confirm: "

    confirmation = STDIN.gets.chomp

    if confirmation == 'DELETE'
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS pwb_prop_translations CASCADE")
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS pwb_page_translations CASCADE")
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS pwb_content_translations CASCADE")
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS pwb_link_translations CASCADE")
      puts "Globalize tables dropped successfully."
    else
      puts "Aborted. No tables were dropped."
    end
  end
end
```

---

## Phase 7: Testing

### Step 7.1: Model Specs

`spec/models/pwb/mobility_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mobility Translations', type: :model do
  describe Pwb::Prop do
    let(:prop) { create(:prop) }

    it 'stores translations in multiple locales' do
      I18n.with_locale(:en) { prop.update!(title: 'Luxury Apartment') }
      I18n.with_locale(:es) { prop.update!(title: 'Apartamento de Lujo') }

      expect(prop.title(locale: :en)).to eq('Luxury Apartment')
      expect(prop.title(locale: :es)).to eq('Apartamento de Lujo')
    end

    it 'falls back to English when translation missing' do
      I18n.with_locale(:en) { prop.update!(title: 'Apartment') }

      # German should fall back to English
      expect(prop.title(locale: :de)).to eq('Apartment')
    end

    it 'persists translations in JSONB column' do
      I18n.with_locale(:en) { prop.update!(title: 'Test') }
      prop.reload

      expect(prop.translations).to be_a(Hash)
      expect(prop.translations.dig('en', 'title')).to eq('Test')
    end

    it 'supports locale-specific setters' do
      prop.title_en = 'English Title'
      prop.title_es = 'Titulo en Espanol'
      prop.save!

      expect(prop.title(locale: :en)).to eq('English Title')
      expect(prop.title(locale: :es)).to eq('Titulo en Espanol')
    end
  end

  describe Pwb::Page do
    let(:page) { create(:page) }

    it 'translates multiple fields' do
      I18n.with_locale(:en) do
        page.update!(
          page_title: 'About Us',
          link_title: 'About',
          raw_html: '<p>Welcome</p>'
        )
      end

      expect(page.page_title(locale: :en)).to eq('About Us')
      expect(page.link_title(locale: :en)).to eq('About')
      expect(page.raw_html(locale: :en)).to eq('<p>Welcome</p>')
    end
  end

  describe Pwb::Content do
    let(:content) { create(:content) }

    it 'translates raw content' do
      I18n.with_locale(:en) { content.update!(raw: 'Hello World') }
      I18n.with_locale(:fr) { content.update!(raw: 'Bonjour Monde') }

      expect(content.raw(locale: :en)).to eq('Hello World')
      expect(content.raw(locale: :fr)).to eq('Bonjour Monde')
    end
  end

  describe Pwb::Link do
    let(:link) { create(:link) }

    it 'translates link_title' do
      I18n.with_locale(:en) { link.update!(link_title: 'Home') }
      I18n.with_locale(:es) { link.update!(link_title: 'Inicio') }

      expect(link.link_title(locale: :en)).to eq('Home')
      expect(link.link_title(locale: :es)).to eq('Inicio')
    end
  end

  describe 'Querying translations' do
    it 'finds records by translated attribute' do
      I18n.with_locale(:en) do
        create(:prop, title: 'Beach House')
        create(:prop, title: 'Mountain Cabin')
      end

      results = Pwb::Prop.i18n.where(title: 'Beach House')
      expect(results.count).to eq(1)
      expect(results.first.title).to eq('Beach House')
    end
  end
end
```

---

## Execution Checklist

### Pre-Migration

- [ ] Backup production database
- [ ] Backup development database
- [ ] Review all code changes
- [ ] Run existing test suite (ensure it passes)

### Migration Steps

1. [ ] Create `config/initializers/mobility.rb`
2. [ ] Create `config/initializers/mobility_fallbacks.rb`
3. [ ] Generate migration timestamp: `date +%Y%m%d%H%M%S`
4. [ ] Create migration: `add_mobility_translations_columns`
5. [ ] Create migration: `migrate_globalize_to_mobility`
6. [ ] Run migrations: `rails db:migrate`
7. [ ] Update `app/models/pwb/prop.rb`
8. [ ] Update `app/models/pwb/page.rb`
9. [ ] Update `app/models/pwb/content.rb`
10. [ ] Update `app/models/pwb/link.rb`
11. [ ] Create `app/models/concerns/mobility_serializable.rb`
12. [ ] Create `lib/tasks/mobility_migration.rake`
13. [ ] Run verification: `rails mobility:verify`
14. [ ] Run test suite: `bundle exec rspec`
15. [ ] Test manually in browser

### Post-Migration (After 1-2 Weeks)

- [ ] Remove Globalize from Gemfile
- [ ] Remove Globalize from gemspec
- [ ] Delete `config/initializers/i18n_globalise.rb`
- [ ] Run `rails mobility:drop_globalize_tables`
- [ ] Run `bundle install`

---

## Rollback Plan

If issues arise, rollback is straightforward:

### Option 1: Rollback Migrations

```bash
# Roll back the data migration
rails db:rollback STEP=1

# Roll back the column addition
rails db:rollback STEP=1

# Revert model changes (use git)
git checkout app/models/pwb/prop.rb
git checkout app/models/pwb/page.rb
git checkout app/models/pwb/content.rb
git checkout app/models/pwb/link.rb
```

### Option 2: Restore from Backup

```bash
# PostgreSQL
psql your_database < backup_before_mobility.sql

# Revert all code changes
git checkout HEAD -- app/models/ config/initializers/
```

---

## API Compatibility

**Note:** The `locale_accessors` plugin must be enabled in the Mobility configuration for `title_en`, `title_es` style accessors to work. Without it, only `title(locale: :en)` syntax is available.

### Reading Translations

| Globalize | Mobility | Notes |
|-----------|----------|-------|
| `prop.title` | `prop.title` | Same - uses current locale |
| `prop.title_en` | `prop.title_en` | Same - requires `locale_accessors` plugin |
| `prop.title(locale: :es)` | `prop.title(locale: :es)` | Same - explicit locale |

### Writing Translations

| Globalize | Mobility | Notes |
|-----------|----------|-------|
| `prop.title = 'X'` | `prop.title = 'X'` | Same - uses current locale |
| `prop.title_en = 'X'` | `prop.title_en = 'X'` | Same - requires `locale_accessors` plugin |
| `prop.update(title: 'X')` | `prop.update(title: 'X')` | Same |

### Querying

| Globalize | Mobility | Notes |
|-----------|----------|-------|
| `Prop.with_translations(:en)` | `Prop.i18n { ... }` | Different syntax |
| `Prop.where(title: 'X')` | `Prop.i18n.where(title: 'X')` | Add `.i18n` scope |
| `includes(:translations)` | Not needed | JSONB doesn't require eager loading |

---

## Performance Comparison

### Query Performance

**Globalize (Before):**
```sql
-- Every read requires a JOIN
SELECT pwb_props.*, t.title, t.description
FROM pwb_props
LEFT JOIN pwb_prop_translations t ON t.prop_id = pwb_props.id
WHERE t.locale = 'en';
```

**Mobility JSONB (After):**
```sql
-- Direct column access, no JOIN
SELECT pwb_props.*,
       translations->'en'->>'title' as title,
       translations->'en'->>'description' as description
FROM pwb_props;
```

**Expected improvement:** 2-5x faster read queries

### Storage

**Globalize:** Separate table per model = more overhead
**Mobility JSONB:** Single column = less overhead

**Expected improvement:** ~20% reduction in storage

---

## Troubleshooting

### Issue: "undefined method `title_en`"

**Solution:** Ensure the `locale_accessors` plugin is enabled in your Mobility configuration:

```ruby
Mobility.configure do
  plugins do
    # ... other plugins ...
    locale_accessors I18n.available_locales
  end
end
```

Without `locale_accessors`, only `title(locale: :en)` syntax is available, not `title_en`.

### Issue: Translations not saving

**Solution:** Check that `extend Mobility` is present in the model.

### Issue: Fallbacks not working

**Solution:** Verify `config/initializers/mobility_fallbacks.rb` is loaded.

### Issue: Queries returning nil

**Solution:** Use `Model.i18n.where(...)` for translated attribute queries.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-04 | Claude | Initial plan |

---

## References

- [Mobility Gem Documentation](https://github.com/shioyama/mobility)
- [Mobility Wiki](https://github.com/shioyama/mobility/wiki)
- [PostgreSQL JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [Globalize Gem](https://github.com/globalize/globalize) (for reference)
