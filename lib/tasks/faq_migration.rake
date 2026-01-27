# frozen_string_literal: true

namespace :pwb do
  namespace :faq do
    desc 'Migrate legacy FAQ fields (faq_1_question, faq_1_answer, etc.) to array-based faq_items format'
    task migrate_to_array: :environment do
      puts "Starting FAQ migration to array format..."

      migrated_count = 0
      error_count = 0

      Pwb::PagePart.where(page_part_key: 'faqs/faq_accordion').find_each do |page_part|
        begin
          migrate_page_part_faqs(page_part)
          migrated_count += 1
          puts "  ✓ Migrated PagePart #{page_part.id} (website: #{page_part.website_id})"
        rescue StandardError => e
          error_count += 1
          puts "  ✗ Error migrating PagePart #{page_part.id}: #{e.message}"
        end
      end

      puts "\nMigration complete:"
      puts "  Migrated: #{migrated_count}"
      puts "  Errors: #{error_count}"
    end

    desc 'Preview FAQ migration without making changes'
    task preview_migration: :environment do
      puts "Previewing FAQ migration (no changes will be made)...\n\n"

      Pwb::PagePart.where(page_part_key: 'faqs/faq_accordion').find_each do |page_part|
        puts "PagePart #{page_part.id} (website: #{page_part.website_id}):"

        page_part.block_contents&.each do |locale, locale_data|
          blocks = locale_data['blocks'] || {}

          # Check if already migrated
          if blocks['faq_items'].present?
            puts "  [#{locale}] Already has faq_items - SKIP"
            next
          end

          # Extract legacy FAQs
          faq_items = extract_legacy_faqs(blocks)
          if faq_items.any?
            puts "  [#{locale}] Found #{faq_items.size} FAQs to migrate:"
            faq_items.each_with_index do |item, idx|
              q_preview = item['question'].to_s[0..50]
              puts "    #{idx + 1}. #{q_preview}..."
            end
          else
            puts "  [#{locale}] No legacy FAQs found"
          end
        end
        puts ""
      end
    end

    private

    def migrate_page_part_faqs(page_part)
      return unless page_part.block_contents.present?

      updated_contents = page_part.block_contents.deep_dup

      updated_contents.each do |locale, locale_data|
        blocks = locale_data['blocks'] || {}

        # Skip if already has faq_items
        next if blocks['faq_items'].present?

        # Extract legacy FAQs
        faq_items = extract_legacy_faqs(blocks)
        next if faq_items.empty?

        # Add faq_items as JSON string
        blocks['faq_items'] = { 'content' => faq_items.to_json }

        # Remove legacy fields
        (1..10).each do |i|
          blocks.delete("faq_#{i}_question")
          blocks.delete("faq_#{i}_answer")
        end

        locale_data['blocks'] = blocks
      end

      page_part.update!(block_contents: updated_contents)
    end

    def extract_legacy_faqs(blocks)
      faq_items = []

      (1..10).each do |i|
        question = blocks.dig("faq_#{i}_question", 'content')
        answer = blocks.dig("faq_#{i}_answer", 'content')

        next if question.blank?

        faq_items << {
          'question' => question,
          'answer' => answer || ''
        }
      end

      faq_items
    end
  end
end
