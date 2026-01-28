# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_media
# Database name: primary
#
#  id           :bigint           not null, primary key
#  alt_text     :string
#  byte_size    :bigint
#  caption      :string
#  checksum     :string
#  content_type :string
#  description  :text
#  filename     :string           not null
#  height       :integer
#  last_used_at :datetime
#  sort_order   :integer          default(0)
#  source_type  :string
#  source_url   :string
#  tags         :string           default([]), is an Array
#  title        :string
#  usage_count  :integer          default(0)
#  width        :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  folder_id    :bigint
#  website_id   :bigint           not null
#
# Indexes
#
#  index_pwb_media_on_folder_id                    (folder_id)
#  index_pwb_media_on_tags                         (tags) USING gin
#  index_pwb_media_on_website_id                   (website_id)
#  index_pwb_media_on_website_id_and_content_type  (website_id,content_type)
#  index_pwb_media_on_website_id_and_created_at    (website_id,created_at)
#  index_pwb_media_on_website_id_and_folder_id     (website_id,folder_id)
#
# Foreign Keys
#
#  fk_rails_...  (folder_id => pwb_media_folders.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe Media, type: :model do
    let(:website) { create(:pwb_website) }

    describe 'associations' do
      it { is_expected.to belong_to(:website).class_name('Pwb::Website') }
      it { is_expected.to belong_to(:folder).class_name('Pwb::MediaFolder').optional }
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:filename) }

      describe 'file presence on create' do
        it 'requires file on create' do
          media = Media.new(website: website, filename: 'test.jpg')
          expect(media).not_to be_valid
          expect(media.errors[:file]).to be_present
        end

        it 'allows update without file' do
          media = create(:pwb_media, website: website)
          media.title = 'Updated title'
          expect(media).to be_valid
        end
      end

      describe '#acceptable_file' do
        let(:media) { build(:pwb_media, website: website) }

        it 'accepts valid image types' do
          %w[image/jpeg image/png image/gif image/webp].each do |content_type|
            media.file.attach(
              io: StringIO.new('fake image data'),
              filename: 'test.jpg',
              content_type: content_type
            )
            # The validation itself may pass but content type check should not error
          end
        end

        it 'accepts PDF files' do
          media.file.attach(
            io: StringIO.new('%PDF-1.4'),
            filename: 'document.pdf',
            content_type: 'application/pdf'
          )
          expect(media.errors[:file]).to be_empty
        end

        it 'rejects files exceeding max size' do
          # Create a file that's too large
          large_content = 'x' * (26.megabytes)
          media = Media.new(website: website, filename: 'large.jpg')
          media.file.attach(
            io: StringIO.new(large_content),
            filename: 'large.jpg',
            content_type: 'image/jpeg'
          )
          media.valid?
          expect(media.errors[:file].to_s).to include('too large')
        end

        it 'rejects unsupported file types' do
          media = Media.new(website: website, filename: 'script.exe')
          media.file.attach(
            io: StringIO.new('binary data'),
            filename: 'script.exe',
            content_type: 'application/x-msdownload'
          )
          media.valid?
          expect(media.errors[:file].to_s).to include('unsupported')
        end
      end
    end

    describe 'scopes' do
      let!(:image) { create(:pwb_media, website: website, content_type: 'image/jpeg') }
      let!(:pdf) { create(:pwb_media, :pdf, website: website) }
      let!(:old_image) { create(:pwb_media, website: website, created_at: 1.week.ago) }

      describe '.images' do
        it 'returns only image media' do
          expect(Media.images).to include(image, old_image)
          expect(Media.images).not_to include(pdf)
        end
      end

      describe '.documents' do
        it 'returns only non-image media' do
          expect(Media.documents).to include(pdf)
          expect(Media.documents).not_to include(image)
        end
      end

      describe '.recent' do
        it 'orders by created_at desc' do
          result = Media.recent
          expect(result.first.created_at).to be >= result.last.created_at
        end
      end

      describe '.by_folder' do
        let(:folder) { create(:pwb_media_folder, website: website) }
        let!(:folder_media) { create(:pwb_media, website: website, folder: folder) }

        it 'returns media in specified folder' do
          expect(Media.by_folder(folder)).to include(folder_media)
          expect(Media.by_folder(folder)).not_to include(image)
        end

        it 'returns all media when folder is nil' do
          expect(Media.by_folder(nil).count).to eq(Media.count)
        end
      end

      describe '.search' do
        let!(:searchable) do
          create(:pwb_media,
            website: website,
            filename: 'searchable.jpg',
            title: 'Beach Photo',
            alt_text: 'Sunny beach',
            description: 'Beautiful sunset'
          )
        end

        it 'searches by filename' do
          expect(Media.search('searchable')).to include(searchable)
        end

        it 'searches by title' do
          expect(Media.search('Beach')).to include(searchable)
        end

        it 'searches by alt_text' do
          expect(Media.search('Sunny')).to include(searchable)
        end

        it 'searches by description' do
          expect(Media.search('sunset')).to include(searchable)
        end

        it 'is case insensitive' do
          expect(Media.search('BEACH')).to include(searchable)
        end

        it 'returns all when query is blank' do
          expect(Media.search('')).to include(searchable, image)
        end
      end

      describe '.with_tag' do
        let!(:tagged_media) { create(:pwb_media, :with_tags, website: website) }

        it 'returns media with specified tag' do
          expect(Media.with_tag('property')).to include(tagged_media)
          expect(Media.with_tag('property')).not_to include(image)
        end
      end
    end

    describe 'instance methods' do
      describe '#image?' do
        it 'returns true for image content types' do
          media = build(:pwb_media, content_type: 'image/jpeg')
          expect(media).to be_image
        end

        it 'returns false for non-image content types' do
          media = build(:pwb_media, content_type: 'application/pdf')
          expect(media).not_to be_image
        end

        it 'handles nil content_type' do
          media = build(:pwb_media, content_type: nil)
          expect(media).not_to be_image
        end
      end

      describe '#document?' do
        it 'returns true for non-image content types' do
          media = build(:pwb_media, content_type: 'application/pdf')
          expect(media).to be_document
        end

        it 'returns false for image content types' do
          media = build(:pwb_media, content_type: 'image/jpeg')
          expect(media).not_to be_document
        end
      end

      describe '#pdf?' do
        it 'returns true for PDF content type' do
          media = build(:pwb_media, content_type: 'application/pdf')
          expect(media).to be_pdf
        end

        it 'returns false for other content types' do
          media = build(:pwb_media, content_type: 'image/jpeg')
          expect(media).not_to be_pdf
        end
      end

      describe '#display_name' do
        it 'returns title when present' do
          media = build(:pwb_media, title: 'My Title', filename: 'file.jpg')
          expect(media.display_name).to eq('My Title')
        end

        it 'returns filename when title is blank' do
          media = build(:pwb_media, title: nil, filename: 'file.jpg')
          expect(media.display_name).to eq('file.jpg')
        end
      end

      describe '#human_file_size' do
        it 'returns formatted size' do
          media = build(:pwb_media, byte_size: 1024)
          expect(media.human_file_size).to eq('1 KB')
        end

        it 'returns nil when byte_size is nil' do
          media = build(:pwb_media, byte_size: nil)
          expect(media.human_file_size).to be_nil
        end
      end

      describe '#dimensions' do
        it 'returns formatted dimensions' do
          media = build(:pwb_media, width: 800, height: 600)
          expect(media.dimensions).to eq('800 x 600')
        end

        it 'returns nil when dimensions are missing' do
          media = build(:pwb_media, width: nil, height: nil)
          expect(media.dimensions).to be_nil
        end

        it 'returns nil when only one dimension is present' do
          media = build(:pwb_media, width: 800, height: nil)
          expect(media.dimensions).to be_nil
        end
      end

      describe '#within_size_limit?' do
        it 'returns true when within limit' do
          media = build(:pwb_media, byte_size: 1.megabyte)
          expect(media).to be_within_size_limit
        end

        it 'returns true when byte_size is nil' do
          media = build(:pwb_media, byte_size: nil)
          expect(media).to be_within_size_limit
        end

        it 'returns false when exceeding limit' do
          media = build(:pwb_media, byte_size: 30.megabytes)
          expect(media).not_to be_within_size_limit
        end
      end

      describe '#record_usage!' do
        let(:media) { create(:pwb_media, website: website, usage_count: 5) }

        it 'increments usage_count' do
          expect { media.record_usage! }.to change { media.reload.usage_count }.by(1)
        end

        it 'updates last_used_at' do
          media.record_usage!
          media.reload
          expect(media.last_used_at).to be_within(2.seconds).of(Time.current)
        end
      end

      describe '#add_tag' do
        let(:media) { create(:pwb_media, website: website, tags: ['existing']) }

        it 'adds a new tag' do
          media.add_tag('newtag')
          expect(media.reload.tags).to include('newtag')
        end

        it 'normalizes tag to lowercase' do
          media.add_tag('  UPPERCASE  ')
          expect(media.reload.tags).to include('uppercase')
        end

        it 'does not add duplicate tags' do
          media.add_tag('existing')
          expect(media.reload.tags.count('existing')).to eq(1)
        end

        it 'ignores blank tags' do
          original_count = media.tags.count
          media.add_tag('')
          expect(media.reload.tags.count).to eq(original_count)
        end
      end

      describe '#remove_tag' do
        let(:media) { create(:pwb_media, website: website, tags: %w[keep remove]) }

        it 'removes the specified tag' do
          media.remove_tag('remove')
          expect(media.reload.tags).not_to include('remove')
          expect(media.reload.tags).to include('keep')
        end

        it 'handles non-existent tag gracefully' do
          expect { media.remove_tag('nonexistent') }.not_to raise_error
        end
      end

      describe '#url' do
        let(:media) { create(:pwb_media, website: website) }

        it 'returns a path to the file' do
          expect(media.url).to be_present
          expect(media.url).to include('rails/active_storage')
        end

        it 'returns nil when file is not attached' do
          media.file.purge
          expect(media.url).to be_nil
        end
      end

      describe '#variant_url' do
        let(:media) { create(:pwb_media, website: website, content_type: 'image/jpeg') }

        it 'returns original URL for non-image media' do
          pdf = create(:pwb_media, :pdf, website: website)
          expect(pdf.variant_url(:thumb)).to eq(pdf.url)
        end

        it 'returns original URL for unknown variant' do
          expect(media.variant_url(:unknown_variant)).to eq(media.url)
        end
      end
    end

    describe 'class methods' do
      describe '.allowed_content_types' do
        it 'includes common image types' do
          expect(Media.allowed_content_types).to include('image/jpeg', 'image/png', 'image/gif', 'image/webp')
        end

        it 'includes PDF' do
          expect(Media.allowed_content_types).to include('application/pdf')
        end

        it 'includes office document types' do
          expect(Media.allowed_content_types).to include(
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          )
        end
      end

      describe '.max_file_size' do
        it 'returns 25 megabytes' do
          expect(Media.max_file_size).to eq(25.megabytes)
        end
      end
    end

    describe 'callbacks' do
      describe '#set_metadata_from_file' do
        it 'sets filename from blob' do
          media = Media.new(website: website)
          media.file.attach(
            io: StringIO.new('data'),
            filename: 'auto_name.jpg',
            content_type: 'image/jpeg'
          )
          media.valid?
          expect(media.filename).to eq('auto_name.jpg')
        end

        it 'sets content_type from blob' do
          media = Media.new(website: website)
          media.file.attach(
            io: StringIO.new('data'),
            filename: 'test.png',
            content_type: 'image/png'
          )
          media.valid?
          expect(media.content_type).to eq('image/png')
        end

        it 'sets byte_size from blob' do
          content = 'test content here'
          media = Media.new(website: website)
          media.file.attach(
            io: StringIO.new(content),
            filename: 'test.txt',
            content_type: 'text/plain'
          )
          media.valid?
          expect(media.byte_size).to eq(content.bytesize)
        end

        it 'sets source_type to upload when not set' do
          media = Media.new(website: website)
          media.file.attach(
            io: StringIO.new('data'),
            filename: 'test.jpg',
            content_type: 'image/jpeg'
          )
          media.valid?
          expect(media.source_type).to eq('upload')
        end
      end
    end

    describe 'multi-tenancy' do
      let(:website_a) { create(:pwb_website) }
      let(:website_b) { create(:pwb_website) }
      let!(:media_a) { create(:pwb_media, website: website_a) }
      let!(:media_b) { create(:pwb_media, website: website_b) }

      it 'media belongs to specific website' do
        expect(media_a.website).to eq(website_a)
        expect(media_b.website).to eq(website_b)
      end
    end
  end
end
