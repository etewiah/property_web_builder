# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteSocialLinkable, type: :model do
  let(:website) { create(:pwb_website) }

  describe 'social media accessors' do
    let!(:facebook_link) do
      create(:pwb_link, website: website, slug: 'social_media_facebook', link_url: 'https://facebook.com/test')
    end
    let!(:twitter_link) do
      create(:pwb_link, website: website, slug: 'social_media_twitter', link_url: 'https://twitter.com/test')
    end
    let!(:linkedin_link) do
      create(:pwb_link, website: website, slug: 'social_media_linkedin', link_url: 'https://linkedin.com/test')
    end
    let!(:youtube_link) do
      create(:pwb_link, website: website, slug: 'social_media_youtube', link_url: 'https://youtube.com/test')
    end
    let!(:pinterest_link) do
      create(:pwb_link, website: website, slug: 'social_media_pinterest', link_url: 'https://pinterest.com/test')
    end

    describe '#social_media_facebook' do
      it 'returns the Facebook URL' do
        expect(website.social_media_facebook).to eq('https://facebook.com/test')
      end

      it 'returns nil when no Facebook link exists' do
        facebook_link.destroy
        expect(website.social_media_facebook).to be_nil
      end
    end

    describe '#social_media_twitter' do
      it 'returns the Twitter URL' do
        expect(website.social_media_twitter).to eq('https://twitter.com/test')
      end

      it 'returns nil when no Twitter link exists' do
        twitter_link.destroy
        expect(website.social_media_twitter).to be_nil
      end
    end

    describe '#social_media_linkedin' do
      it 'returns the LinkedIn URL' do
        expect(website.social_media_linkedin).to eq('https://linkedin.com/test')
      end

      it 'returns nil when no LinkedIn link exists' do
        linkedin_link.destroy
        expect(website.social_media_linkedin).to be_nil
      end
    end

    describe '#social_media_youtube' do
      it 'returns the YouTube URL' do
        expect(website.social_media_youtube).to eq('https://youtube.com/test')
      end

      it 'returns nil when no YouTube link exists' do
        youtube_link.destroy
        expect(website.social_media_youtube).to be_nil
      end
    end

    describe '#social_media_pinterest' do
      it 'returns the Pinterest URL' do
        expect(website.social_media_pinterest).to eq('https://pinterest.com/test')
      end

      it 'returns nil when no Pinterest link exists' do
        pinterest_link.destroy
        expect(website.social_media_pinterest).to be_nil
      end
    end
  end
end
