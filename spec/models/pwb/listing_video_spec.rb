# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::ListingVideo, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  let(:website) { create(:pwb_website) }
  let(:realty_asset) { create(:pwb_realty_asset, website: website) }
  let(:user) { create(:pwb_user, website: website) }

  describe 'associations' do
    it { should belong_to(:website) }
    it { should belong_to(:realty_asset).class_name('Pwb::RealtyAsset') }
    it { should belong_to(:user).class_name('Pwb::User').optional }
  end

  describe 'validations' do
    subject { build(:listing_video, website: website, realty_asset: realty_asset) }

    it { should validate_presence_of(:title) }
    it { should validate_inclusion_of(:status).in_array(Pwb::ListingVideo::STATUSES) }
    it { should validate_inclusion_of(:format).in_array(Pwb::ListingVideo::FORMATS) }
    it { should validate_inclusion_of(:style).in_array(Pwb::ListingVideo::STYLES) }
    it { should validate_inclusion_of(:voice).in_array(Pwb::ListingVideo::VOICES) }

    describe 'share_token uniqueness' do
      let!(:existing_video) { create(:listing_video, :shared, website: website, realty_asset: realty_asset) }

      it 'allows nil share_token' do
        video = build(:listing_video, website: website, realty_asset: realty_asset, share_token: nil)
        expect(video).to be_valid
      end

      it 'rejects duplicate share_token' do
        video = build(:listing_video, website: website, realty_asset: realty_asset, share_token: existing_video.share_token)
        expect(video).not_to be_valid
        expect(video.errors[:share_token]).to be_present
      end
    end
  end

  describe 'constants' do
    it 'defines valid formats' do
      expect(Pwb::ListingVideo::FORMATS).to eq(%w[vertical_9_16 horizontal_16_9 square_1_1])
    end

    it 'defines valid styles' do
      expect(Pwb::ListingVideo::STYLES).to eq(%w[professional luxury casual energetic minimal])
    end

    it 'defines valid voices' do
      expect(Pwb::ListingVideo::VOICES).to eq(%w[alloy echo fable onyx nova shimmer])
    end

    it 'defines valid statuses' do
      expect(Pwb::ListingVideo::STATUSES).to eq(%w[pending generating completed failed])
    end
  end

  describe 'callbacks' do
    describe '#generate_reference_number' do
      it 'generates reference number on create' do
        video = create(:listing_video, website: website, realty_asset: realty_asset)
        expect(video.reference_number).to match(/^VID-\d{8}-[A-Z0-9]{6}$/)
      end

      it 'does not override existing reference number' do
        video = create(:listing_video, website: website, realty_asset: realty_asset, reference_number: 'CUSTOM-123')
        expect(video.reference_number).to eq('CUSTOM-123')
      end
    end

    describe '#set_default_branding' do
      it 'sets default branding from website on create' do
        video = create(:listing_video, website: website, realty_asset: realty_asset, user: user)
        expect(video.branding).to be_present
        expect(video.branding['primary_color']).to eq('#2563eb')
      end

      it 'does not override existing branding' do
        custom_branding = { 'company_name' => 'Custom Co', 'primary_color' => '#ff0000' }
        video = create(:listing_video, website: website, realty_asset: realty_asset, branding: custom_branding)
        expect(video.branding['primary_color']).to eq('#ff0000')
      end
    end
  end

  describe 'scopes' do
    let!(:pending_video) { create(:listing_video, website: website, realty_asset: realty_asset, status: 'pending') }
    let!(:generating_video) { create(:listing_video, :generating, website: website, realty_asset: realty_asset) }
    let!(:completed_video) { create(:listing_video, :completed, website: website, realty_asset: realty_asset) }
    let!(:failed_video) { create(:listing_video, :failed, website: website, realty_asset: realty_asset) }

    describe '.pending' do
      it 'returns only pending videos' do
        expect(Pwb::ListingVideo.pending).to contain_exactly(pending_video)
      end
    end

    describe '.generating' do
      it 'returns only generating videos' do
        expect(Pwb::ListingVideo.generating).to contain_exactly(generating_video)
      end
    end

    describe '.completed' do
      it 'returns only completed videos' do
        expect(Pwb::ListingVideo.completed).to contain_exactly(completed_video)
      end
    end

    describe '.failed' do
      it 'returns only failed videos' do
        expect(Pwb::ListingVideo.failed).to contain_exactly(failed_video)
      end
    end

    describe '.recent' do
      it 'orders by created_at descending' do
        videos = Pwb::ListingVideo.recent
        expect(videos.first).to eq(failed_video)
      end
    end

    describe '.for_property' do
      let(:other_asset) { create(:pwb_realty_asset, website: website) }
      let!(:other_video) { create(:listing_video, website: website, realty_asset: other_asset) }

      it 'returns videos for specific property' do
        expect(Pwb::ListingVideo.for_property(realty_asset.id)).to contain_exactly(
          pending_video, generating_video, completed_video, failed_video
        )
      end
    end
  end

  describe 'state transitions' do
    let(:video) { create(:listing_video, website: website, realty_asset: realty_asset) }

    describe '#mark_generating!' do
      it 'updates status to generating' do
        video.mark_generating!
        expect(video.reload.status).to eq('generating')
      end
    end

    describe '#mark_completed!' do
      it 'updates status to completed' do
        video.mark_completed!
        expect(video.reload.status).to eq('completed')
      end

      it 'sets generated_at timestamp' do
        travel_to Time.current do
          video.mark_completed!
          expect(video.reload.generated_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'clears error fields' do
        video.update!(error_message: 'Previous error', failed_at: 1.hour.ago)
        video.mark_completed!
        expect(video.reload.error_message).to be_nil
        expect(video.reload.failed_at).to be_nil
      end

      it 'accepts additional attributes' do
        video.mark_completed!(video_url: 'https://example.com/video.mp4', duration_seconds: 45)
        video.reload
        expect(video.video_url).to eq('https://example.com/video.mp4')
        expect(video.duration_seconds).to eq(45)
      end
    end

    describe '#mark_failed!' do
      it 'updates status to failed' do
        video.mark_failed!('API Error')
        expect(video.reload.status).to eq('failed')
      end

      it 'sets error message' do
        video.mark_failed!('Render timeout')
        expect(video.reload.error_message).to eq('Render timeout')
      end

      it 'sets failed_at timestamp' do
        travel_to Time.current do
          video.mark_failed!('Error')
          expect(video.reload.failed_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    describe '#mark_shared!' do
      let(:video) { create(:listing_video, :completed, website: website, realty_asset: realty_asset) }

      it 'sets shared_at timestamp' do
        travel_to Time.current do
          video.mark_shared!
          expect(video.reload.shared_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'generates share_token' do
        video.mark_shared!
        expect(video.reload.share_token).to be_present
        expect(video.share_token.length).to be >= 20
      end
    end
  end

  describe 'status helpers' do
    describe '#pending?' do
      it 'returns true when status is pending' do
        video = build(:listing_video, status: 'pending')
        expect(video.pending?).to be true
      end

      it 'returns false when status is not pending' do
        video = build(:listing_video, status: 'completed')
        expect(video.pending?).to be false
      end
    end

    describe '#generating?' do
      it 'returns true when status is generating' do
        video = build(:listing_video, status: 'generating')
        expect(video.generating?).to be true
      end
    end

    describe '#completed?' do
      it 'returns true when status is completed' do
        video = build(:listing_video, status: 'completed')
        expect(video.completed?).to be true
      end
    end

    describe '#failed?' do
      it 'returns true when status is failed' do
        video = build(:listing_video, status: 'failed')
        expect(video.failed?).to be true
      end
    end
  end

  describe 'video helpers' do
    describe '#video_ready?' do
      it 'returns true when video_url is present' do
        video = build(:listing_video, video_url: 'https://example.com/video.mp4')
        expect(video.video_ready?).to be true
      end

      it 'returns true when video_file is attached' do
        video = create(:listing_video, website: website, realty_asset: realty_asset)
        video.video_file.attach(
          io: StringIO.new('fake video content'),
          filename: 'test.mp4',
          content_type: 'video/mp4'
        )
        expect(video.video_ready?).to be true
      end

      it 'returns false when neither is present' do
        video = build(:listing_video, video_url: nil)
        expect(video.video_ready?).to be false
      end
    end

    describe '#thumbnail_ready?' do
      it 'returns true when thumbnail_url is present' do
        video = build(:listing_video, thumbnail_url: 'https://example.com/thumb.jpg')
        expect(video.thumbnail_ready?).to be true
      end

      it 'returns false when thumbnail is not present' do
        video = build(:listing_video, thumbnail_url: nil)
        expect(video.thumbnail_ready?).to be false
      end
    end

    describe '#video_filename' do
      it 'generates filename from reference number' do
        video = build(:listing_video, reference_number: 'VID-20240101-ABC123')
        expect(video.video_filename).to eq('listing_video_VID-20240101-ABC123.mp4')
      end
    end
  end

  describe '#record_view!' do
    let(:video) { create(:listing_video, :completed, website: website, realty_asset: realty_asset, view_count: 5) }

    it 'increments view count' do
      expect { video.record_view! }.to change { video.reload.view_count }.from(5).to(6)
    end
  end

  describe 'format helpers' do
    describe '#format_label' do
      it 'returns correct label for vertical format' do
        video = build(:listing_video, format: 'vertical_9_16')
        expect(video.format_label).to eq('Vertical (9:16)')
      end

      it 'returns correct label for horizontal format' do
        video = build(:listing_video, format: 'horizontal_16_9')
        expect(video.format_label).to eq('Horizontal (16:9)')
      end

      it 'returns correct label for square format' do
        video = build(:listing_video, format: 'square_1_1')
        expect(video.format_label).to eq('Square (1:1)')
      end
    end

    describe '#aspect_ratio' do
      it 'returns 9:16 for vertical format' do
        video = build(:listing_video, format: 'vertical_9_16')
        expect(video.aspect_ratio).to eq('9:16')
      end

      it 'returns 16:9 for horizontal format' do
        video = build(:listing_video, format: 'horizontal_16_9')
        expect(video.aspect_ratio).to eq('16:9')
      end

      it 'returns 1:1 for square format' do
        video = build(:listing_video, format: 'square_1_1')
        expect(video.aspect_ratio).to eq('1:1')
      end
    end
  end

  describe 'duration helpers' do
    describe '#duration_formatted' do
      it 'formats duration as minutes:seconds' do
        video = build(:listing_video, duration_seconds: 125)
        expect(video.duration_formatted).to eq('2:05')
      end

      it 'returns nil when duration is not set' do
        video = build(:listing_video, duration_seconds: nil)
        expect(video.duration_formatted).to be_nil
      end

      it 'handles zero seconds' do
        video = build(:listing_video, duration_seconds: 60)
        expect(video.duration_formatted).to eq('1:00')
      end
    end
  end

  describe 'cost helpers' do
    describe '#cost_formatted' do
      it 'formats cost as dollars' do
        video = build(:listing_video, cost_cents: 1250)
        expect(video.cost_formatted).to eq('$12.5')
      end

      it 'returns nil when cost is not set' do
        video = build(:listing_video, cost_cents: nil)
        expect(video.cost_formatted).to be_nil
      end
    end
  end

  describe 'branding accessors' do
    let(:video) { build(:listing_video, :with_branding) }

    describe '#logo_url' do
      it 'returns logo_url from branding' do
        expect(video.logo_url).to eq('https://example.com/logo.png')
      end

      it 'returns nil when branding is empty' do
        video = build(:listing_video, branding: nil)
        expect(video.logo_url).to be_nil
      end
    end

    describe '#company_name' do
      it 'returns company_name from branding' do
        expect(video.company_name).to eq('Premier Realty')
      end

      it 'falls back to website company_display_name' do
        video = build(:listing_video, branding: {}, website: website)
        allow(website).to receive(:company_display_name).and_return('Default Co')
        expect(video.company_name).to eq('Default Co')
      end
    end

    describe '#primary_color' do
      it 'returns primary_color from branding' do
        expect(video.primary_color).to eq('#2563eb')
      end

      it 'returns default color when branding is empty' do
        video = build(:listing_video, branding: nil)
        expect(video.primary_color).to eq('#2563eb')
      end
    end
  end

  describe 'scene accessors' do
    describe '#scene_count' do
      it 'returns number of scenes' do
        video = build(:listing_video, :with_script)
        expect(video.scene_count).to eq(5)
      end

      it 'returns 0 when scenes is nil' do
        video = build(:listing_video, scenes: nil)
        expect(video.scene_count).to eq(0)
      end
    end

    describe '#total_scene_duration' do
      it 'sums duration of all scenes' do
        video = build(:listing_video, :with_script)
        expect(video.total_scene_duration).to eq(25) # 5+6+5+5+4
      end

      it 'returns 0 when scenes is nil' do
        video = build(:listing_video, scenes: nil)
        expect(video.total_scene_duration).to eq(0)
      end
    end
  end
end
