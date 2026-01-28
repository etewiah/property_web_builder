# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_page_contents
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  is_rails_part          :boolean          default(FALSE)
#  label                  :string
#  page_part_key          :string
#  slot_name              :string
#  sort_order             :integer
#  visible_on_page        :boolean          default(TRUE)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  content_id             :bigint
#  page_id                :bigint
#  parent_page_content_id :bigint
#  website_id             :bigint
#
# Indexes
#
#  index_pwb_page_contents_on_content_id              (content_id)
#  index_pwb_page_contents_on_page_id                 (page_id)
#  index_pwb_page_contents_on_parent_and_slot         (parent_page_content_id,slot_name)
#  index_pwb_page_contents_on_parent_page_content_id  (parent_page_content_id)
#  index_pwb_page_contents_on_parent_slot_order       (parent_page_content_id,slot_name,sort_order)
#  index_pwb_page_contents_on_website_id              (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_page_content_id => pwb_page_contents.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe PageContent, type: :model do
    include FactoryBot::Syntax::Methods

    let(:website) { create(:pwb_website) }
    let(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website)
      end
    end

    # Set tenant context for specs that use factories
    around do |example|
      if website
        ActsAsTenant.with_tenant(website) do
          example.run
        end
      else
        example.run
      end
    end

    describe 'associations' do
      it 'belongs to page (optional)' do
        assoc = PageContent.reflect_on_association(:page)
        expect(assoc.macro).to eq(:belongs_to)
        expect(assoc.options[:optional]).to be true
      end

      it 'belongs to content (optional)' do
        assoc = PageContent.reflect_on_association(:content)
        expect(assoc.macro).to eq(:belongs_to)
        expect(assoc.options[:optional]).to be true
      end

      it 'belongs to website (optional)' do
        assoc = PageContent.reflect_on_association(:website)
        expect(assoc.macro).to eq(:belongs_to)
        # NOTE: website is optional in PageContent model
        expect(assoc.options[:optional]).to be true
      end
    end

    describe 'validations' do
      it 'validates presence of page_part_key' do
        page_content = PageContent.new(website: website, page_part_key: nil)
        expect(page_content).not_to be_valid
        expect(page_content.errors[:page_part_key]).to be_present
      end

      it 'allows page_content without website_id (website is optional)' do
        # NOTE: website is optional in PageContent model
        page_content = PageContent.new(page_part_key: 'test_key', page: nil, website: nil)
        expect(page_content).to be_valid
      end

      it 'does not allow content_id to be changed after creation' do
        content1 = create(:pwb_content, website: website, key: 'content_key_1')
        content2 = create(:pwb_content, website: website, key: 'content_key_2')
        page_content = create(:pwb_page_content, page_part_key: 'test_key', website: website, content: content1)

        page_content.content_id = content2.id
        expect(page_content).not_to be_valid
        expect(page_content.errors[:content_id]).to include('Change of content_id not allowed!')
      end

      it 'allows content_id to be set if it was blank' do
        content = create(:pwb_content, website: website)
        page_content = create(:pwb_page_content, page_part_key: 'test_key', website: website, content: nil)

        page_content.content = content
        expect(page_content).to be_valid
      end
    end

    describe 'callbacks' do
      describe '#set_website_id_from_page' do
        it 'automatically sets website_id from associated page' do
          page_content = PageContent.new(page_part_key: 'test_key', page: page)
          page_content.valid?
          expect(page_content.website_id).to eq(website.id)
        end

        it 'does not override website_id if already set' do
          other_website = create(:pwb_website)
          page_content = PageContent.new(
            page_part_key: 'test_key',
            page: page,
            website: other_website
          )
          page_content.valid?
          expect(page_content.website_id).to eq(other_website.id)
        end

        it 'does not set website_id if page has no website' do
          orphan_page = build(:pwb_page, website: nil)
          orphan_page.save(validate: false) # bypass validations to create orphan page
          page_content = PageContent.new(page_part_key: 'test_key', page: orphan_page)
          page_content.valid?
          expect(page_content.website_id).to be_nil
        end
      end
    end

    describe 'scopes' do
      describe '.ordered_visible' do
        it 'returns only visible page_contents ordered by sort_order' do
          visible1 = create(:pwb_page_content, page_part_key: 'key1', website: website, visible_on_page: true, sort_order: 2)
          visible2 = create(:pwb_page_content, page_part_key: 'key2', website: website, visible_on_page: true, sort_order: 1)
          hidden = create(:pwb_page_content, page_part_key: 'key3', website: website, visible_on_page: false, sort_order: 0)

          result = PageContent.ordered_visible
          result_ids = result.map(&:id)
          expect(result_ids).to eq([visible2.id, visible1.id])
          expect(result_ids).not_to include(hidden.id)
        end
      end
    end

    describe '#content_page_part_key' do
      it 'returns the content page_part_key when content exists' do
        content = create(:pwb_content, website: website, page_part_key: 'my_content_key')
        page_content = create(:pwb_page_content, page_part_key: 'test_key', website: website, content: content)

        expect(page_content.content_page_part_key).to eq('my_content_key')
      end

      it 'returns empty string when content is nil' do
        page_content = create(:pwb_page_content, page_part_key: 'test_key', website: website, content: nil)

        expect(page_content.content_page_part_key).to eq('')
      end
    end

    describe 'multi-tenant isolation' do
      it 'allows page_content without website_id (website is optional for flexibility)' do
        # NOTE: PageContent model has optional: true for website association
        # This allows legacy data and flexible content creation
        page_content = PageContent.new(page_part_key: 'orphan_key')
        expect(page_content).to be_valid
      end

      it 'ensures all page_contents have website_id when created through page association' do
        new_page_content = page.page_contents.create(page_part_key: 'new_key', website: website)
        expect(new_page_content).to be_persisted
        expect(new_page_content.website_id).to eq(website.id)
      end
    end

    describe 'container functionality' do
      let(:container) do
        create(:pwb_page_content,
               page_part_key: 'layout/layout_two_column_equal',
               website: website,
               page: page)
      end

      describe 'associations' do
        it 'has many child_page_contents' do
          assoc = PageContent.reflect_on_association(:child_page_contents)
          expect(assoc.macro).to eq(:has_many)
          expect(assoc.options[:foreign_key]).to eq(:parent_page_content_id)
        end

        it 'belongs to parent_page_content (optional)' do
          assoc = PageContent.reflect_on_association(:parent_page_content)
          expect(assoc.macro).to eq(:belongs_to)
          expect(assoc.options[:optional]).to be true
        end
      end

      describe '#container?' do
        it 'returns true for container page parts' do
          expect(container.container?).to be true
        end

        it 'returns false for non-container page parts' do
          regular = create(:pwb_page_content, page_part_key: 'heroes/hero_centered', website: website)
          expect(regular.container?).to be false
        end
      end

      describe '#has_parent?' do
        it 'returns false for root-level page contents' do
          expect(container.has_parent?).to be false
        end

        it 'returns true for child page contents' do
          child = create(:pwb_page_content,
                         page_part_key: 'cta/cta_banner',
                         website: website,
                         parent_page_content: container,
                         slot_name: 'left')
          expect(child.has_parent?).to be true
        end
      end

      describe '#available_slots' do
        it 'returns slot names for container page parts' do
          expect(container.available_slots).to contain_exactly('left', 'right')
        end

        it 'returns empty array for non-container page parts' do
          regular = create(:pwb_page_content, page_part_key: 'heroes/hero_centered', website: website)
          expect(regular.available_slots).to eq([])
        end
      end

      describe '#children_in_slot' do
        it 'returns children assigned to a specific slot ordered by sort_order' do
          child1 = create(:pwb_page_content,
                          page_part_key: 'content_html',
                          website: website,
                          parent_page_content: container,
                          slot_name: 'left',
                          sort_order: 2)
          child2 = create(:pwb_page_content,
                          page_part_key: 'cta/cta_banner',
                          website: website,
                          parent_page_content: container,
                          slot_name: 'left',
                          sort_order: 1)
          child_right = create(:pwb_page_content,
                               page_part_key: 'faqs/faq_accordion',
                               website: website,
                               parent_page_content: container,
                               slot_name: 'right',
                               sort_order: 1)

          left_children = container.children_in_slot('left')
          expect(left_children.map(&:id)).to eq([child2.id, child1.id])

          right_children = container.children_in_slot('right')
          expect(right_children.map(&:id)).to eq([child_right.id])
        end
      end

      describe 'validations' do
        describe 'slot_name presence for children' do
          it 'requires slot_name when parent is set' do
            child = build(:pwb_page_content,
                          page_part_key: 'content_html',
                          website: website,
                          parent_page_content: container,
                          slot_name: nil)
            expect(child).not_to be_valid
            expect(child.errors[:slot_name]).to be_present
          end

          it 'does not require slot_name for root-level page contents' do
            root = build(:pwb_page_content,
                         page_part_key: 'content_html',
                         website: website,
                         parent_page_content: nil,
                         slot_name: nil)
            expect(root).to be_valid
          end
        end

        describe 'parent must be container' do
          it 'allows children only in container page parts' do
            non_container = create(:pwb_page_content,
                                   page_part_key: 'heroes/hero_centered',
                                   website: website)
            child = build(:pwb_page_content,
                          page_part_key: 'content_html',
                          website: website,
                          parent_page_content: non_container,
                          slot_name: 'left')
            expect(child).not_to be_valid
            expect(child.errors[:parent_page_content]).to include('must be a container page part')
          end
        end

        describe 'no nested containers' do
          it 'prevents containers from being nested inside other containers' do
            nested_container = build(:pwb_page_content,
                                     page_part_key: 'layout/layout_sidebar_left',
                                     website: website,
                                     parent_page_content: container,
                                     slot_name: 'left')
            expect(nested_container).not_to be_valid
            expect(nested_container.errors[:base]).to include('Containers cannot be nested inside other containers')
          end
        end

        describe 'slot exists in container' do
          it 'validates that slot_name is valid for the parent container' do
            child = build(:pwb_page_content,
                          page_part_key: 'content_html',
                          website: website,
                          parent_page_content: container,
                          slot_name: 'invalid_slot')
            expect(child).not_to be_valid
            expect(child.errors[:slot_name].first).to include('is not valid for this container')
          end

          it 'allows valid slot names' do
            child = build(:pwb_page_content,
                          page_part_key: 'content_html',
                          website: website,
                          parent_page_content: container,
                          slot_name: 'left')
            expect(child).to be_valid
          end
        end
      end

      describe 'scopes' do
        before do
          @root1 = create(:pwb_page_content, page_part_key: 'key1', website: website, parent_page_content: nil)
          @root2 = create(:pwb_page_content, page_part_key: 'key2', website: website, parent_page_content: nil)
          @child = create(:pwb_page_content,
                          page_part_key: 'key3',
                          website: website,
                          parent_page_content: container,
                          slot_name: 'left')
        end

        describe '.root_level' do
          it 'returns only page contents without a parent' do
            # Container is also root level
            root_ids = PageContent.root_level.pluck(:id)
            expect(root_ids).to include(@root1.id, @root2.id, container.id)
            expect(root_ids).not_to include(@child.id)
          end
        end

        describe '.in_slot' do
          it 'returns page contents in the specified slot' do
            expect(PageContent.in_slot('left').pluck(:id)).to include(@child.id)
            expect(PageContent.in_slot('right').pluck(:id)).not_to include(@child.id)
          end
        end
      end
    end
  end
end
