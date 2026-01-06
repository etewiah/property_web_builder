# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_pages
# Database name: primary
#
#  id                      :integer          not null, primary key
#  details                 :json
#  flags                   :integer          default(0), not null
#  meta_description        :text
#  seo_title               :string
#  show_in_footer          :boolean          default(FALSE)
#  show_in_top_nav         :boolean          default(FALSE)
#  slug                    :string
#  sort_order_footer       :integer          default(0)
#  sort_order_top_nav      :integer          default(0)
#  translations            :jsonb            not null
#  visible                 :boolean          default(FALSE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  last_updated_by_user_id :integer
#  setup_id                :string
#  website_id              :integer
#
# Indexes
#
#  index_pwb_pages_on_flags                (flags)
#  index_pwb_pages_on_show_in_footer       (show_in_footer)
#  index_pwb_pages_on_show_in_top_nav      (show_in_top_nav)
#  index_pwb_pages_on_slug_and_website_id  (slug,website_id) UNIQUE
#  index_pwb_pages_on_translations         (translations) USING gin
#  index_pwb_pages_on_website_id           (website_id)
#
require 'rails_helper'

module Pwb
  RSpec.describe Page, type: :model do
    let(:website) { FactoryBot.create(:pwb_website) }
    let(:page) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page, website: website)
      end
    end
    # below will not be available in context block
    # let(:about_us_page) { FactoryBot.create(:about_us_page_with_page_part)}

    it 'has a valid factory' do
      expect(page).to be_valid
    end

    # below to be replaced with page_part_manager
    # it 'sets fragment visibility correctly' do

    # end

    # context 'with correct fragment_block' do
    #   before(:all) do
    #     @about_us_page = FactoryBot.create(:about_us_page_with_page_part)

    #     @fragment_block = {
    #       "blocks": {
    #         "main_content": {
    #           "content": "<p>Hola.</p>"
    #         }
    #       }
    #     }
    #     @page_part_key = "content_html"
    #   end

    #   it 'sets page_part block contents correctly' do
    #     # for the "content_html" page part
    #     # if I pass in a locale key and a blocks json element to the right method on the page
    #     # (the below method is called by admin page via API that passes in correctly
    #     # formated fragment_block)
    #     byebug
    #     @about_us_page.update_page_part_content  @page_part_key, "en", @fragment_block
    #     about_us__content_html__page_part  = @about_us_page.page_parts.find_by_page_part_key @page_part_key


    #     # the corresponding page_part will have that json element correctly set
    #     expect(about_us__content_html__page_part.block_contents.to_json).to have_json_path("en/blocks")
    #   end

    #   it 'builds page content correctly' do
    #     about_us__content_html__page_part  = @about_us_page.page_parts.find_by_page_part_key @page_part_key
    #     about_us__content_html__page_part.template = '<div>{{ page_part["main_content"]["content"] %> }}</div>'
    #     about_us__content_html__page_part.save!
    #     @about_us_page.update_page_part_content  @page_part_key, "en", @fragment_block

    #     expect(@about_us_page.page_contents.first.page_part_key).to eq(@page_part_key)
    #     expect(@about_us_page.contents.first.raw_en).to eq("<div><p>Hola.</p></div>")
    #   end

    #   # @about_us_page not available in context below
    #   # context 'www' do
    #   #   # and when I rebuild the page content
    #   #   @about_us_page.rebuild_page_content @page_part_key, "en"
    #   # end

    # end
  end
end
