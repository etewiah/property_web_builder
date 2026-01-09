# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe ContentsSeeder do
    let!(:website) { create(:pwb_website) }

    before do
      Pwb::Current.website = website
    end

    after do
      Pwb::Current.reset
    end

    describe '.seed_page_content_translations!' do
      context 'when page_parts have nil page_part_key' do
        let!(:page) do
          ActsAsTenant.with_tenant(website) do
            create(:pwb_page, slug: 'test-page', website: website)
          end
        end

        it 'skips website-level page_parts with nil page_part_key without raising error' do
          # Create a page_part with nil page_part_key directly in the database
          ActsAsTenant.with_tenant(website) do
            Pwb::PagePart.create!(
              page_slug: nil,
              page_part_key: nil,
              website_id: website.id
            )
          end

          expect do
            ContentsSeeder.seed_page_content_translations!(website: website)
          end.not_to raise_error
        end

        it 'skips page-level page_parts with nil page_part_key without raising error' do
          # Create a page_part with nil page_part_key for a specific page
          ActsAsTenant.with_tenant(website) do
            Pwb::PagePart.create!(
              page_slug: page.slug,
              page_part_key: nil,
              website_id: website.id
            )
          end

          expect do
            ContentsSeeder.seed_page_content_translations!(website: website)
          end.not_to raise_error
        end

        it 'skips page_parts with empty string page_part_key without raising error' do
          ActsAsTenant.with_tenant(website) do
            Pwb::PagePart.create!(
              page_slug: page.slug,
              page_part_key: '',
              website_id: website.id
            )
          end

          expect do
            ContentsSeeder.seed_page_content_translations!(website: website)
          end.not_to raise_error
        end

        it 'still processes page_parts with valid page_part_key' do
          # Create a valid page_part
          ActsAsTenant.with_tenant(website) do
            Pwb::PagePart.create!(
              page_slug: page.slug,
              page_part_key: 'content_html',
              website_id: website.id,
              editor_setup: {
                'editorBlocks' => [[{ 'label' => 'main_content', 'isHtml' => 'true' }]]
              }
            )
          end

          # Should not raise error and should process the valid page_part
          expect do
            ContentsSeeder.seed_page_content_translations!(website: website)
          end.not_to raise_error
        end
      end
    end
  end
end
