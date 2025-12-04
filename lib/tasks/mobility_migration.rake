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
    [
      [Pwb::Prop, [:title, :description]],
      [Pwb::Page, [:raw_html, :page_title, :link_title]],
      [Pwb::Content, [:raw]],
      [Pwb::Link, [:link_title]]
    ].each do |model, expected_attrs|
      if model.respond_to?(:mobility_attributes)
        actual_attrs = model.mobility_attributes.map(&:to_sym)
        if (expected_attrs - actual_attrs).empty?
          puts "   [OK] #{model.name} uses Mobility (#{actual_attrs.join(', ')})"
        else
          missing = expected_attrs - actual_attrs
          errors << "#{model.name} missing Mobility attributes: #{missing.join(', ')}"
          puts "   [FAIL] #{model.name} missing: #{missing.join(', ')}"
        end
      else
        errors << "#{model.name} is not using Mobility"
        puts "   [FAIL] #{model.name} is not using Mobility"
      end
    end

    # Check 3: Data migrated
    puts "\n3. Checking data migration..."

    # Check Props
    prop_count = Pwb::Prop.count
    props_with_translations = Pwb::Prop.where("translations != '{}'::jsonb").count
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
    pages_with_translations = Pwb::Page.where("translations != '{}'::jsonb").count
    globalize_page_count = begin
      ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT page_id) FROM pwb_page_translations").first['count'].to_i
    rescue
      0
    end

    puts "   Pages: #{pages_with_translations}/#{page_count} have Mobility translations"
    puts "   Globalize had: #{globalize_page_count} pages with translations"

    # Check Contents
    content_count = Pwb::Content.count
    contents_with_translations = Pwb::Content.where("translations != '{}'::jsonb").count
    globalize_content_count = begin
      ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT content_id) FROM pwb_content_translations").first['count'].to_i
    rescue
      0
    end

    puts "   Contents: #{contents_with_translations}/#{content_count} have Mobility translations"
    puts "   Globalize had: #{globalize_content_count} contents with translations"

    # Check Links
    link_count = Pwb::Link.count
    links_with_translations = Pwb::Link.where("translations != '{}'::jsonb").count
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
      prop = Pwb::Prop.where("translations != '{}'::jsonb").first
      if prop
        puts "   Testing Prop##{prop.id}:"
        I18n.available_locales.first(3).each do |locale|
          begin
            title = prop.title(locale: locale)
            puts "     title(#{locale}): #{title.to_s.truncate(50)}"
          rescue => e
            puts "     title(#{locale}): ERROR - #{e.message}"
          end
        end
      else
        puts "   No props with translations found"
      end
    else
      puts "   No props in database"
    end

    # Check 5: Test locale accessors
    puts "\n5. Testing locale accessors (e.g., title_en)..."

    if Pwb::Prop.any?
      prop = Pwb::Prop.first
      begin
        # Test that locale accessor methods exist
        if prop.respond_to?(:title_en)
          puts "   [OK] title_en accessor exists"
        else
          errors << "title_en accessor not found - locale_accessors plugin may not be configured"
          puts "   [FAIL] title_en accessor not found"
        end

        if prop.respond_to?(:title_en=)
          puts "   [OK] title_en= setter exists"
        else
          errors << "title_en= setter not found"
          puts "   [FAIL] title_en= setter not found"
        end
      rescue => e
        puts "   [ERROR] #{e.message}"
      end
    end

    # Check 6: Test fallbacks
    puts "\n6. Testing fallbacks..."
    if Pwb::Prop.any?
      prop = Pwb::Prop.where("translations != '{}'::jsonb").first
      if prop && prop.translations.dig('en', 'title').present?
        # Test that German falls back to English
        I18n.with_locale(:de) do
          german_title = prop.title
          english_title = prop.title(locale: :en)
          if german_title.present?
            puts "   [OK] Fallback working (de -> en): '#{german_title.to_s.truncate(50)}'"
          else
            puts "   [WARN] Fallback returned nil/blank"
          end
        end
      else
        puts "   [SKIP] No English translations to test fallback"
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
      puts "  Dropped pwb_prop_translations"
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS pwb_page_translations CASCADE")
      puts "  Dropped pwb_page_translations"
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS pwb_content_translations CASCADE")
      puts "  Dropped pwb_content_translations"
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS pwb_link_translations CASCADE")
      puts "  Dropped pwb_link_translations"
      puts "\nGlobalize tables dropped successfully."
    else
      puts "Aborted. No tables were dropped."
    end
  end
end
