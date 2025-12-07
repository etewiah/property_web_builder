# Actionable Test Improvements for Page Parts

## Priority 1: Fix rebuild_page_content() Logic (Quick Win)

**File:** `app/services/pwb/page_part_manager.rb`
**Lines:** 173-176
**Effort:** 5 minutes

### Current Code (BROKEN)
```ruby
def rebuild_page_content(locale)
  unless page_part && page_part.template
    raise "page_part with valid template not available"
  end
  # ... rest of method uses page_part.template directly
```

**Problem:** Only checks database field, doesn't use fallback chain

### Fixed Code
```ruby
def rebuild_page_content(locale)
  template_content = page_part&.template_content
  unless template_content.present?
    raise "page_part with valid template not available"
  end
  
  if page_part.present?
    l_template = Liquid::Template.parse(template_content)  # Use template_content instead of page_part.template
    new_fragment_html = l_template.render("page_part" => page_part.block_contents[locale]["blocks"])
    # ... rest stays same
```

---

## Priority 2: Add rebuild_page_content Tests

**File:** `spec/services/pwb/page_part_manager_spec.rb`
**Location:** Add after existing tests (around line 72)
**Effort:** 1-2 hours

### Test 1: Database Template Success Case
```ruby
describe "#rebuild_page_content" do
  let!(:contact_us_page) { FactoryBot.create(:page_with_content_html_page_part, slug: "contact-us") }
  let(:page_part_key) { "content_html" }
  let(:page_part_manager) { Pwb::PagePartManager.new page_part_key, contact_us_page }

  context "when database template exists" do
    before do
      page_part_manager.page_part.update(block_contents: {
        "en" => { "blocks" => { "main_content" => { "content" => "Test content" } } }
      })
    end

    it "successfully renders template with block contents" do
      html = page_part_manager.rebuild_page_content("en")
      expect(html).to include("Test content")
    end

    it "saves rendered HTML to content model" do
      page_part_manager.rebuild_page_content("en")
      content = contact_us_page.contents.find_by_page_part_key(page_part_key)
      expect(content.raw_en).to include("Test content")
    end
  end
end
```

### Test 2: Missing Template Error Case
```ruby
context "when no template exists anywhere" do
  before do
    page_part_manager.page_part.update(template: nil)
    # Ensure no file templates exist either
    FileUtils.rm_f(Rails.root.join("app/views/pwb/page_parts/content_html.liquid"))
    FileUtils.rm_f(Rails.root.join("app/themes/default/page_parts/content_html.liquid"))
  end

  it "raises descriptive error" do
    expect {
      page_part_manager.rebuild_page_content("en")
    }.to raise_error(/page_part with valid template not available/)
  end
end
```

### Test 3: Theme-Specific Template Fallback
```ruby
context "when theme-specific template exists but database template is nil" do
  before do
    page_part_manager.page_part.update(template: nil)
    
    theme_dir = Rails.root.join("app/themes/default/page_parts")
    FileUtils.mkdir_p(theme_dir)
    File.write(
      theme_dir.join("content_html.liquid"),
      "<div>{{ page_part['main_content']['content'] }}</div>"
    )
    
    page_part_manager.page_part.update(block_contents: {
      "en" => { "blocks" => { "main_content" => { "content" => "Theme rendered" } } }
    })
  end

  after do
    FileUtils.rm_f(Rails.root.join("app/themes/default/page_parts/content_html.liquid"))
  end

  it "uses theme template as fallback" do
    html = page_part_manager.rebuild_page_content("en")
    expect(html).to include("Theme rendered")
  end
end
```

### Test 4: Missing Block Contents for Locale
```ruby
context "when block_contents doesn't have locale key" do
  before do
    page_part_manager.page_part.update(block_contents: { "es" => { "blocks" => {} } })
  end

  it "handles missing locale gracefully" do
    expect {
      page_part_manager.rebuild_page_content("en")
    }.to raise_error(NoMethodError) # Current behavior - should fix this too
  end
end
```

---

## Priority 3: Add YAML Seed File Validator

**File:** Create `spec/lib/pwb/page_part_seed_validator_spec.rb`
**Effort:** 2-3 hours

### Validator Class (to create)
```ruby
# lib/pwb/page_part_seed_validator.rb
module Pwb
  class PagePartSeedValidator
    def self.validate_all!
      errors = []
      
      page_parts_dir = Rails.root.join("db/yml_seeds/page_parts")
      page_parts_dir.children.each do |file|
        if file.extname == ".yml"
          errors.concat(validate_file(file))
        end
      end
      
      raise "Page part seed validation errors:\n#{errors.join("\n")}" if errors.any?
    end

    private

    def self.validate_file(file)
      errors = []
      yml = YAML.load_file(file)
      page_part = yml.first

      # Validate required fields
      unless page_part["page_part_key"]
        errors << "#{file.basename}: Missing page_part_key"
      end

      unless page_part["page_slug"]
        errors << "#{file.basename}: Missing page_slug"
      end

      # Validate template for non-rails parts
      unless page_part["is_rails_part"]
        unless page_part["template"].present?
          errors << "#{file.basename}: Missing template for non-rails-part"
        end

        # Try to parse as Liquid to catch syntax errors
        begin
          Liquid::Template.parse(page_part["template"])
        rescue => e
          errors << "#{file.basename}: Invalid Liquid template: #{e.message}"
        end
      end

      errors
    end
  end
end
```

### Test File
```ruby
# spec/lib/pwb/page_part_seed_validator_spec.rb
require 'rails_helper'
require 'pwb/page_part_seed_validator'

RSpec.describe Pwb::PagePartSeedValidator do
  describe ".validate_all!" do
    it "validates all page part YML files exist and have required fields" do
      expect {
        Pwb::PagePartSeedValidator.validate_all!
      }.not_to raise_error
    end

    context "with invalid template" do
      before do
        @temp_file = Rails.root.join("db/yml_seeds/page_parts/test_invalid.yml")
        File.write(@temp_file, <<~YAML)
          - page_slug: test
            page_part_key: test_key
            template: "{{ unclosed tag"
        YAML
      end

      after do
        FileUtils.rm_f(@temp_file)
      end

      it "raises error for invalid Liquid syntax" do
        expect {
          Pwb::PagePartSeedValidator.validate_all!
        }.to raise_error(/Invalid Liquid template/)
      end
    end

    context "with missing template for non-rails-part" do
      before do
        @temp_file = Rails.root.join("db/yml_seeds/page_parts/test_no_template.yml")
        File.write(@temp_file, <<~YAML)
          - page_slug: test
            page_part_key: test_key
            is_rails_part: false
        YAML
      end

      after do
        FileUtils.rm_f(@temp_file)
      end

      it "raises error for missing template" do
        expect {
          Pwb::PagePartSeedValidator.validate_all!
        }.to raise_error(/Missing template/)
      end
    end
  end
end
```

---

## Priority 4: Add Real Seeding Integration Tests

**File:** `spec/lib/pwb/seed_runner_spec.rb`
**Location:** Add new describe block around line 183
**Effort:** 3-4 hours

### Test: Real End-to-End Seeding
```ruby
describe "real seeding execution" do
  let!(:test_website) { create(:pwb_website, subdomain: 'seeding-test', slug: 'seeding-test') }

  context "when running complete seeding" do
    before do
      # Clear any existing data
      test_website.pages.destroy_all
      test_website.page_parts.destroy_all
      test_website.contents.destroy_all
    end

    it "successfully seeds all pages with valid page parts" do
      expect {
        described_class.run(
          website: test_website,
          mode: :create_only,
          dry_run: false,
          verbose: false,
          skip_properties: true
        )
      }.not_to raise_error

      expect(test_website.pages).not_to be_empty
      expect(test_website.page_parts).not_to be_empty
    end

    it "creates all page parts with valid templates" do
      described_class.run(
        website: test_website,
        mode: :create_only,
        dry_run: false,
        verbose: false,
        skip_properties: true
      )

      test_website.page_parts.where(is_rails_part: false).each do |page_part|
        expect(page_part.template_content).not_to be_empty,
          "Page part #{page_part.page_part_key} has no template"
      end
    end

    it "seeds content without template errors" do
      described_class.run(
        website: test_website,
        mode: :create_only,
        dry_run: false,
        verbose: false,
        skip_properties: true
      )

      # Verify content was created and has valid HTML
      test_website.contents.each do |content|
        # This would have thrown rebuild_page_content error if template was missing
        expect(content.raw_en).to be_a(String)
      end
    end
  end
end
```

### Remove Mocks (Lines 13-14)
**OLD:**
```ruby
before do
  # Ensure we have the seed files available
  allow_any_instance_of(described_class).to receive(:seed_translations)
  allow_any_instance_of(described_class).to receive(:seed_pages)
end
```

**DELETE THESE LINES** - they prevent real seeding from being tested

---

## Priority 5: Add Theme-Specific Template Tests

**File:** `spec/models/pwb/page_part_spec.rb`
**Location:** Add new context block around line 136
**Effort:** 1-2 hours

### Test: Theme-Specific Template Loading
```ruby
context "with multiple themes" do
  let!(:bristol_website) { create(:pwb_website, theme_name: 'bristol') }
  let(:bristol_page_part) do
    create(:pwb_page_part, 
           page_part_key: 'landing_hero',
           website: bristol_website,
           template: nil)  # Explicitly null - test file fallback
  end

  before do
    bristol_dir = Rails.root.join("app/themes/bristol/page_parts")
    FileUtils.mkdir_p(bristol_dir)
    File.write(
      bristol_dir.join("landing_hero.liquid"),
      "<div class='bristol-hero'>{{ page_part['title']['content'] }}</div>"
    )
  end

  after do
    FileUtils.rm_f(Rails.root.join("app/themes/bristol/page_parts/landing_hero.liquid"))
  end

  it "loads bristol-specific template" do
    expect(bristol_page_part.template_content).to include('bristol-hero')
  end

  it "doesn't use default template when theme template exists" do
    expect(bristol_page_part.template_content).not_to include('default-hero')
  end
end
```

---

## Priority 6: Add PagesSeeder Template Validation

**File:** `spec/libraries/pwb/pages_seeder_spec.rb`
**Location:** Add new describe block at end (after line 75)
**Effort:** 1-2 hours

### Test: Verify All Seeded Page Parts Have Templates
```ruby
it 'ensures all non-rails page parts have valid templates' do
  Pwb::PagesSeeder.seed_page_parts!
  
  # Get current website to check
  website = Pwb::Website.first
  
  invalid_parts = website.page_parts.where(is_rails_part: false).select do |pp|
    pp.template_content.blank?
  end
  
  expect(invalid_parts).to be_empty,
    "Page parts without templates: #{invalid_parts.map(&:page_part_key).join(', ')}"
end
```

---

## Implementation Order

1. **Week 1:**
   - Fix `rebuild_page_content()` to use `template_content()`
   - Add Priority 1 fix tests (3-4 tests)

2. **Week 2:**
   - Create PagePartSeedValidator
   - Add seed file validation tests
   - Run against all existing YAML files

3. **Week 3:**
   - Enhance SeedRunner tests with real seeding
   - Add theme-specific template tests
   - Add PagesSeeder validation tests

4. **Week 4:**
   - Run full test suite
   - Update CI/CD to include seed validation
   - Document in CONTRIBUTING.md

---

## Quick Validation Checklist

After implementing tests, run:

```bash
# 1. Run all page part tests
rspec spec/services/pwb/page_part_manager_spec.rb
rspec spec/models/pwb/page_part_spec.rb

# 2. Run seeding tests
rspec spec/libraries/pwb/pages_seeder_spec.rb
rspec spec/lib/pwb/seed_runner_spec.rb

# 3. Run seed validators
rspec spec/lib/pwb/page_part_seed_validator_spec.rb

# 4. Quick smoke test - seed a new website
rails console
Pwb::Website.first.destroy if Pwb::Website.first
Pwb::SeedRunner.run(mode: :create_only, dry_run: false)
# Should not raise "page_part with valid template not available"
```

---

## Estimated Impact

- **Test Coverage:** +30 test cases
- **Integration Tests:** +5 end-to-end scenarios
- **Prevention:** Would have caught bristol theme issue immediately
- **Maintenance:** Validates seed files on every test run
- **Documentation:** Makes expectations explicit in code
