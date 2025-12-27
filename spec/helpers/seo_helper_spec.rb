# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeoHelper, type: :helper do
  let(:website) { create(:pwb_website, subdomain: 'test-seo') }

  before do
    allow(helper).to receive(:current_website).and_return(website)
  end

  # NOTE: verification_meta_tags is currently DISABLED (returns nil stub)
  # See: docs/TODO_SEARCH_ENGINE_VERIFICATION.md
  #
  # When re-enabling, uncomment the full test suite below and remove the
  # "disabled stub" test.

  describe '#verification_meta_tags' do
    context 'when feature is disabled (current state)' do
      it 'returns nil (stubbed)' do
        website.update!(social_media: { 'google_site_verification' => 'test123' })
        expect(helper.verification_meta_tags).to be_nil
      end
    end

    # TODO: Uncomment these tests when re-enabling the feature
    #
    # context 'when no verification codes are set' do
    #   before do
    #     website.update!(social_media: {})
    #   end
    #
    #   it 'returns nil' do
    #     expect(helper.verification_meta_tags).to be_nil
    #   end
    # end
    #
    # context 'when Google verification is set' do
    #   before do
    #     website.update!(social_media: { 'google_site_verification' => 'google123abc' })
    #   end
    #
    #   it 'returns Google verification meta tag' do
    #     result = helper.verification_meta_tags
    #     expect(result).to include('google-site-verification')
    #     expect(result).to include('google123abc')
    #   end
    # end
    #
    # context 'when Bing verification is set' do
    #   before do
    #     website.update!(social_media: { 'bing_site_verification' => 'bing456def' })
    #   end
    #
    #   it 'returns Bing verification meta tag' do
    #     result = helper.verification_meta_tags
    #     expect(result).to include('msvalidate.01')
    #     expect(result).to include('bing456def')
    #   end
    # end
    #
    # context 'when both verification codes are set' do
    #   before do
    #     website.update!(social_media: {
    #       'google_site_verification' => 'google123',
    #       'bing_site_verification' => 'bing456'
    #     })
    #   end
    #
    #   it 'returns both verification meta tags' do
    #     result = helper.verification_meta_tags
    #     expect(result).to include('google-site-verification')
    #     expect(result).to include('google123')
    #     expect(result).to include('msvalidate.01')
    #     expect(result).to include('bing456')
    #   end
    # end
    #
    # context 'when website is nil' do
    #   before do
    #     allow(helper).to receive(:current_website).and_return(nil)
    #   end
    #
    #   it 'returns nil' do
    #     expect(helper.verification_meta_tags).to be_nil
    #   end
    # end
  end
end
