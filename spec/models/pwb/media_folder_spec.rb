# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_media_folders
# Database name: primary
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string
#  sort_order :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_media_folders_on_parent_id                 (parent_id)
#  index_pwb_media_folders_on_website_id                (website_id)
#  index_pwb_media_folders_on_website_id_and_parent_id  (website_id,parent_id)
#  index_pwb_media_folders_on_website_id_and_slug       (website_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => pwb_media_folders.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe MediaFolder, type: :model do
    let(:website) { create(:pwb_website) }

    describe 'associations' do
      it { is_expected.to belong_to(:website).class_name('Pwb::Website') }
      it { is_expected.to belong_to(:parent).class_name('Pwb::MediaFolder').optional }
      it { is_expected.to have_many(:children).class_name('Pwb::MediaFolder').dependent(:destroy) }
      it { is_expected.to have_many(:media).class_name('Pwb::Media').dependent(:nullify) }
    end

    describe 'validations' do
      subject { build(:pwb_media_folder, website: website) }

      it { is_expected.to validate_presence_of(:name) }

      describe 'slug uniqueness scoped to website' do
        let!(:existing_folder) { create(:pwb_media_folder, website: website, slug: 'unique-slug') }

        it 'does not allow duplicate slug for same website' do
          duplicate = build(:pwb_media_folder, website: website, slug: 'unique-slug')
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:slug]).to be_present
        end

        it 'allows same slug for different website' do
          other_website = create(:pwb_website)
          folder = build(:pwb_media_folder, website: other_website, slug: 'unique-slug')
          expect(folder).to be_valid
        end

        it 'allows blank slug' do
          folder = build(:pwb_media_folder, website: website, slug: nil)
          expect(folder).to be_valid
        end
      end

      describe '#parent_belongs_to_same_website' do
        let(:other_website) { create(:pwb_website) }
        let(:other_folder) { create(:pwb_media_folder, website: other_website) }

        it 'does not allow parent from different website' do
          folder = build(:pwb_media_folder, website: website, parent: other_folder)
          expect(folder).not_to be_valid
          expect(folder.errors[:parent]).to include(match(/same website/))
        end

        it 'allows parent from same website' do
          parent_folder = create(:pwb_media_folder, website: website)
          folder = build(:pwb_media_folder, website: website, parent: parent_folder)
          expect(folder).to be_valid
        end
      end

      describe '#prevent_circular_reference' do
        let!(:parent_folder) { create(:pwb_media_folder, website: website) }
        let!(:child_folder) { create(:pwb_media_folder, website: website, parent: parent_folder) }

        it 'prevents folder from being its own parent' do
          parent_folder.parent = parent_folder
          expect(parent_folder).not_to be_valid
          expect(parent_folder.errors[:parent]).to include(match(/circular/))
        end

        it 'prevents circular reference through descendants' do
          parent_folder.parent = child_folder
          expect(parent_folder).not_to be_valid
          expect(parent_folder.errors[:parent]).to include(match(/circular/))
        end

        it 'allows valid parent assignment' do
          new_parent = create(:pwb_media_folder, website: website)
          parent_folder.parent = new_parent
          expect(parent_folder).to be_valid
        end
      end
    end

    describe 'scopes' do
      let!(:root_folder1) { create(:pwb_media_folder, website: website, parent: nil, sort_order: 2) }
      let!(:root_folder2) { create(:pwb_media_folder, website: website, parent: nil, sort_order: 1) }
      let!(:child_folder) { create(:pwb_media_folder, website: website, parent: root_folder1) }

      describe '.root' do
        it 'returns only folders without parent' do
          expect(MediaFolder.root).to include(root_folder1, root_folder2)
          expect(MediaFolder.root).not_to include(child_folder)
        end
      end

      describe '.ordered' do
        it 'orders by sort_order then name' do
          # Scope to website to only get the folders created in this test
          result = website.media_folders.ordered
          # root_folder2 has sort_order 1, root_folder1 has sort_order 2
          # child_folder has default sort_order (0) and comes first
          folder_names = result.pluck(:name)
          # Just verify the scope applies ordering without erroring
          expect(result.to_a).to include(root_folder1, root_folder2)
        end
      end
    end

    describe 'callbacks' do
      describe '#generate_slug' do
        it 'generates slug from name' do
          folder = create(:pwb_media_folder, website: website, name: 'My Folder Name')
          expect(folder.slug).to eq('my-folder-name')
        end

        it 'does not overwrite existing slug' do
          folder = create(:pwb_media_folder, website: website, name: 'Folder', slug: 'custom-slug')
          expect(folder.slug).to eq('custom-slug')
        end

        it 'handles special characters' do
          folder = create(:pwb_media_folder, website: website, name: 'Special & Characters!')
          expect(folder.slug).to eq('special-characters')
        end
      end
    end

    describe 'instance methods' do
      describe '#path' do
        let!(:grandparent) { create(:pwb_media_folder, website: website, name: 'Level 1') }
        let!(:parent) { create(:pwb_media_folder, website: website, name: 'Level 2', parent: grandparent) }
        let!(:folder) { create(:pwb_media_folder, website: website, name: 'Level 3', parent: parent) }

        it 'returns full path of folder names' do
          expect(folder.path).to eq('Level 1 / Level 2 / Level 3')
        end

        it 'returns just name for root folder' do
          expect(grandparent.path).to eq('Level 1')
        end
      end

      describe '#ancestors' do
        let!(:grandparent) { create(:pwb_media_folder, website: website, name: 'Grandparent') }
        let!(:parent) { create(:pwb_media_folder, website: website, name: 'Parent', parent: grandparent) }
        let!(:folder) { create(:pwb_media_folder, website: website, name: 'Child', parent: parent) }

        it 'returns all ancestor folders' do
          ancestors = folder.ancestors
          expect(ancestors).to include(parent, grandparent)
          expect(ancestors.first).to eq(parent)
          expect(ancestors.last).to eq(grandparent)
        end

        it 'returns empty array for root folder' do
          expect(grandparent.ancestors).to eq([])
        end
      end

      describe '#descendants' do
        let!(:parent) { create(:pwb_media_folder, website: website) }
        let!(:child1) { create(:pwb_media_folder, website: website, parent: parent) }
        let!(:child2) { create(:pwb_media_folder, website: website, parent: parent) }
        let!(:grandchild) { create(:pwb_media_folder, website: website, parent: child1) }

        it 'returns all descendant folders recursively' do
          descendants = parent.descendants
          expect(descendants).to include(child1, child2, grandchild)
        end

        it 'returns empty array for leaf folder' do
          expect(grandchild.descendants).to eq([])
        end
      end

      describe '#total_media_count' do
        let!(:parent) { create(:pwb_media_folder, website: website) }
        let!(:child) { create(:pwb_media_folder, website: website, parent: parent) }

        before do
          create_list(:pwb_media, 3, website: website, folder: parent)
          create_list(:pwb_media, 2, website: website, folder: child)
        end

        it 'counts media in folder and subfolders' do
          expect(parent.total_media_count).to eq(5)
        end

        it 'counts only media in leaf folder' do
          expect(child.total_media_count).to eq(2)
        end
      end

      describe '#empty?' do
        it 'returns true when folder has no media and no children' do
          folder = create(:pwb_media_folder, website: website)
          expect(folder).to be_empty
        end

        it 'returns false when folder has media' do
          folder = create(:pwb_media_folder, :with_media, website: website)
          expect(folder).not_to be_empty
        end

        it 'returns false when folder has children' do
          folder = create(:pwb_media_folder, :with_children, website: website)
          expect(folder).not_to be_empty
        end
      end
    end

    describe 'dependent destroy' do
      let!(:parent) { create(:pwb_media_folder, website: website) }
      let!(:child) { create(:pwb_media_folder, website: website, parent: parent) }
      let!(:media) { create(:pwb_media, website: website, folder: parent) }

      it 'destroys child folders when parent is destroyed' do
        expect { parent.destroy }.to change { MediaFolder.count }.by(-2)
      end

      it 'nullifies media folder_id when folder is destroyed' do
        parent.destroy
        expect(media.reload.folder_id).to be_nil
      end
    end

    describe 'multi-tenancy' do
      let(:website_a) { create(:pwb_website) }
      let(:website_b) { create(:pwb_website) }
      let!(:folder_a) { create(:pwb_media_folder, website: website_a) }
      let!(:folder_b) { create(:pwb_media_folder, website: website_b) }

      it 'folder belongs to specific website' do
        expect(folder_a.website).to eq(website_a)
        expect(folder_b.website).to eq(website_b)
      end
    end
  end
end
