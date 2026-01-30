# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::SocialMediaTemplate, type: :model do
  let(:website) { create(:website) }

  describe 'associations' do
    it { is_expected.to belong_to(:website) }
  end

  describe 'validations' do
    subject { build(:pwb_social_media_template, website: website) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:platform) }
    it { is_expected.to validate_presence_of(:post_type) }
    it { is_expected.to validate_presence_of(:caption_template) }

    it 'validates platform inclusion' do
      expect(subject).to allow_value('instagram').for(:platform)
      expect(subject).to allow_value('facebook').for(:platform)
      expect(subject).not_to allow_value('myspace').for(:platform)
    end

    it 'validates category inclusion' do
      expect(subject).to allow_value('just_listed').for(:category)
      expect(subject).to allow_value('price_drop').for(:category)
      expect(subject).to allow_value('open_house').for(:category)
      expect(subject).to allow_value('sold').for(:category)
      expect(subject).to allow_value(nil).for(:category)
      expect(subject).not_to allow_value('invalid').for(:category)
    end
  end

  describe 'scopes' do
    before do
      create(:pwb_social_media_template, :instagram, website: website)
      create(:pwb_social_media_template, :facebook, website: website)
      create(:pwb_social_media_template, :instagram, :price_drop, website: website)
      create(:pwb_social_media_template, :instagram, :default, website: website)
      create(:pwb_social_media_template, :instagram, :inactive, website: website)
    end

    describe '.active' do
      it 'returns only active templates' do
        expect(Pwb::SocialMediaTemplate.active.count).to eq(4)
      end
    end

    describe '.for_platform' do
      it 'filters by platform' do
        expect(Pwb::SocialMediaTemplate.for_platform('instagram').count).to eq(4)
        expect(Pwb::SocialMediaTemplate.for_platform('facebook').count).to eq(1)
      end
    end

    describe '.for_category' do
      it 'filters by category' do
        # 4 templates have just_listed (default), 1 has price_drop
        expect(Pwb::SocialMediaTemplate.for_category('just_listed').count).to eq(4)
        expect(Pwb::SocialMediaTemplate.for_category('price_drop').count).to eq(1)
      end
    end

    describe '.default_templates' do
      it 'returns only default templates' do
        expect(Pwb::SocialMediaTemplate.default_templates.count).to eq(1)
      end
    end
  end

  describe '#render' do
    let(:template) { create(:pwb_social_media_template, website: website) }
    let(:property) do
      create(:pwb_realty_asset,
        website: website,
        prop_type_key: 'apartment',
        count_bedrooms: 3,
        count_bathrooms: 2,
        city: 'Madrid'
      )
    end

    # Create a mock listing with price
    let(:listing) do
      double(
        'listing',
        realty_asset: property,
        website: website,
        title: 'Beautiful Apartment',
        description: 'A lovely place',
        price_sale_current_cents: 250_000_00,
        price_sale_current_currency: 'EUR',
        price_rental_monthly_current_cents: nil,
        price_rental_monthly_current_currency: nil
      )
    end

    it 'renders template with property data' do
      result = template.render(listing)

      expect(result[:caption]).to include('apartment')
      expect(result[:caption]).to include('Madrid')
      expect(result[:caption]).to include('3')
    end

    it 'includes hashtags when template has them' do
      result = template.render(listing)

      expect(result[:hashtags]).to be_present
    end

    it 'handles missing properties gracefully' do
      minimal_property = double('property',
        prop_type_key: nil,
        count_bedrooms: nil,
        count_bathrooms: nil,
        city: nil,
        region: nil,
        full_address: nil,
        title: nil,
        description: nil,
        website: website,
        slug: 'test'
      )

      minimal_listing = double('listing',
        realty_asset: minimal_property,
        website: website,
        title: nil,
        description: nil,
        price_sale_current_cents: nil,
        price_sale_current_currency: nil,
        price_rental_monthly_current_cents: nil,
        price_rental_monthly_current_currency: nil
      )

      expect { template.render(minimal_listing) }.not_to raise_error
    end
  end
end
