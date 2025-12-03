require 'rails_helper'

module Pwb
  RSpec.describe PageContent, type: :model do
    include FactoryBot::Syntax::Methods

    let(:website) { create(:pwb_website) }
    let(:page) { create(:pwb_page, website: website) }

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

      it 'belongs to website (required)' do
        assoc = PageContent.reflect_on_association(:website)
        expect(assoc.macro).to eq(:belongs_to)
        expect(assoc.options[:optional]).to be_falsey
      end
    end

    describe 'validations' do
      it 'validates presence of page_part_key' do
        page_content = PageContent.new(website: website, page_part_key: nil)
        expect(page_content).not_to be_valid
        expect(page_content.errors[:page_part_key]).to be_present
      end

      it 'requires website_id to be present' do
        page_content = PageContent.new(page_part_key: 'test_key', page: nil, website: nil)
        expect(page_content).not_to be_valid
        expect(page_content.errors[:website]).to include('must exist')
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
          expect(result).to eq([visible2, visible1])
          expect(result).not_to include(hidden)
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
      it 'prevents creation of page_content without website_id' do
        page_content = PageContent.new(page_part_key: 'orphan_key')
        expect(page_content.save).to be false
        expect(page_content.errors[:website]).to be_present
      end

      it 'ensures all page_contents have website_id when created through page association' do
        new_page_content = page.page_contents.create(page_part_key: 'new_key', website: website)
        expect(new_page_content).to be_persisted
        expect(new_page_content.website_id).to eq(website.id)
      end
    end
  end
end
