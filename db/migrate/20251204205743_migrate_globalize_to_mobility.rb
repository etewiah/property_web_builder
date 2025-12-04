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

    # Check if Globalize table exists
    unless table_exists?(:pwb_prop_translations)
      say "    Skipping - pwb_prop_translations table does not exist"
      return
    end

    # Get all prop translations from Globalize table
    prop_translations = execute(<<-SQL)
      SELECT prop_id, locale, title, description
      FROM pwb_prop_translations
      WHERE prop_id IS NOT NULL
    SQL

    # Group by prop_id
    translations_by_prop = {}
    prop_translations.each do |t|
      prop_id = t['prop_id']
      translations_by_prop[prop_id] ||= []
      translations_by_prop[prop_id] << t
    end

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

    unless table_exists?(:pwb_page_translations)
      say "    Skipping - pwb_page_translations table does not exist"
      return
    end

    page_translations = execute(<<-SQL)
      SELECT page_id, locale, raw_html, page_title, link_title
      FROM pwb_page_translations
      WHERE page_id IS NOT NULL
    SQL

    translations_by_page = {}
    page_translations.each do |t|
      page_id = t['page_id']
      translations_by_page[page_id] ||= []
      translations_by_page[page_id] << t
    end

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

    unless table_exists?(:pwb_content_translations)
      say "    Skipping - pwb_content_translations table does not exist"
      return
    end

    content_translations = execute(<<-SQL)
      SELECT content_id, locale, raw
      FROM pwb_content_translations
      WHERE content_id IS NOT NULL
    SQL

    translations_by_content = {}
    content_translations.each do |t|
      content_id = t['content_id']
      translations_by_content[content_id] ||= []
      translations_by_content[content_id] << t
    end

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

    unless table_exists?(:pwb_link_translations)
      say "    Skipping - pwb_link_translations table does not exist"
      return
    end

    link_translations = execute(<<-SQL)
      SELECT link_id, locale, link_title
      FROM pwb_link_translations
      WHERE link_id IS NOT NULL
    SQL

    translations_by_link = {}
    link_translations.each do |t|
      link_id = t['link_id']
      translations_by_link[link_id] ||= []
      translations_by_link[link_id] << t
    end

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

  def table_exists?(table_name)
    ActiveRecord::Base.connection.table_exists?(table_name)
  end
end
