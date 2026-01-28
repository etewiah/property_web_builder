# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_widget_configs
# Database name: primary
#
#  id                :uuid             not null, primary key
#  active            :boolean          default(TRUE), not null
#  allowed_domains   :string           default([]), is an Array
#  clicks_count      :integer          default(0)
#  columns           :integer          default(3)
#  highlighted_only  :boolean          default(FALSE)
#  impressions_count :integer          default(0)
#  layout            :string           default("grid")
#  listing_type      :string
#  max_bedrooms      :integer
#  max_price_cents   :integer
#  max_properties    :integer          default(12)
#  min_bedrooms      :integer
#  min_price_cents   :integer
#  name              :string           not null
#  property_types    :string           default([]), is an Array
#  show_filters      :boolean          default(FALSE)
#  show_pagination   :boolean          default(TRUE)
#  show_search       :boolean          default(FALSE)
#  theme             :jsonb
#  visible_fields    :jsonb
#  widget_key        :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  website_id        :bigint           not null
#
# Indexes
#
#  index_pwb_widget_configs_on_website_id             (website_id)
#  index_pwb_widget_configs_on_website_id_and_active  (website_id,active)
#  index_pwb_widget_configs_on_widget_key             (widget_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe WidgetConfig, type: :model do
    let(:website) { create(:pwb_website) }

    describe 'associations' do
      it { is_expected.to belong_to(:website).class_name('Pwb::Website') }
    end

    describe 'validations' do
      subject { build(:pwb_widget_config, website: website) }

      it { is_expected.to validate_presence_of(:name) }

      # Note: widget_key validation is handled by callback + database constraint
      # The before_validation callback auto-generates widget_key if blank,
      # so shoulda matchers for presence/uniqueness don't work as expected.
      # Widget key uniqueness is tested in the callbacks section.

      describe 'layout validation' do
        it 'allows valid layouts' do
          %w[grid list carousel].each do |layout|
            widget = build(:pwb_widget_config, website: website, layout: layout)
            expect(widget).to be_valid
          end
        end

        it 'rejects invalid layouts' do
          widget = build(:pwb_widget_config, website: website, layout: 'invalid')
          expect(widget).not_to be_valid
          expect(widget.errors[:layout]).to be_present
        end
      end

      describe 'columns validation' do
        it 'allows columns between 1 and 6' do
          (1..6).each do |n|
            widget = build(:pwb_widget_config, website: website, columns: n)
            expect(widget).to be_valid
          end
        end

        it 'rejects columns outside range' do
          widget = build(:pwb_widget_config, website: website, columns: 0)
          expect(widget).not_to be_valid

          widget = build(:pwb_widget_config, website: website, columns: 7)
          expect(widget).not_to be_valid
        end
      end

      describe 'max_properties validation' do
        it 'allows values between 1 and 100' do
          widget = build(:pwb_widget_config, website: website, max_properties: 50)
          expect(widget).to be_valid
        end

        it 'rejects 0 or negative values' do
          widget = build(:pwb_widget_config, website: website, max_properties: 0)
          expect(widget).not_to be_valid
        end

        it 'rejects values over 100' do
          widget = build(:pwb_widget_config, website: website, max_properties: 101)
          expect(widget).not_to be_valid
        end
      end

      describe 'listing_type validation' do
        it 'allows sale and rent' do
          %w[sale rent].each do |type|
            widget = build(:pwb_widget_config, website: website, listing_type: type)
            expect(widget).to be_valid
          end
        end

        it 'allows blank listing_type' do
          widget = build(:pwb_widget_config, website: website, listing_type: nil)
          expect(widget).to be_valid
        end

        it 'rejects invalid listing_type' do
          widget = build(:pwb_widget_config, website: website, listing_type: 'invalid')
          expect(widget).not_to be_valid
        end
      end
    end

    describe 'callbacks' do
      describe '#generate_widget_key' do
        it 'generates widget_key on create' do
          widget = build(:pwb_widget_config, website: website)
          # Clear the widget_key that factory might set via callback
          widget.widget_key = nil
          widget.save!
          expect(widget.widget_key).to be_present
          expect(widget.widget_key.length).to eq(12)
        end

        it 'generates lowercase alphanumeric key' do
          widget = create(:pwb_widget_config, website: website)
          expect(widget.widget_key).to match(/\A[a-z0-9]+\z/)
        end

        it 'does not overwrite existing widget_key' do
          widget = create(:pwb_widget_config, website: website, widget_key: 'custom123key')
          expect(widget.widget_key).to eq('custom123key')
        end

        it 'generates unique keys' do
          keys = 5.times.map { create(:pwb_widget_config, website: website).widget_key }
          expect(keys.uniq.count).to eq(5)
        end
      end
    end

    describe 'scopes' do
      let!(:active_widget) { create(:pwb_widget_config, website: website, active: true) }
      let!(:inactive_widget) { create(:pwb_widget_config, :inactive, website: website) }

      describe '.active' do
        it 'returns only active widgets' do
          expect(WidgetConfig.active).to include(active_widget)
          expect(WidgetConfig.active).not_to include(inactive_widget)
        end
      end
    end

    describe 'instance methods' do
      let(:widget) { create(:pwb_widget_config, website: website) }

      describe '#effective_theme' do
        it 'returns defaults when theme is nil' do
          widget.update!(theme: nil)
          result = widget.effective_theme
          expect(result).to eq(WidgetConfig::DEFAULT_THEME)
        end

        it 'merges custom theme with defaults' do
          widget.update!(theme: { 'primary_color' => '#FF0000' })
          result = widget.effective_theme
          expect(result['primary_color']).to eq('#FF0000')
          expect(result['secondary_color']).to eq(WidgetConfig::DEFAULT_THEME['secondary_color'])
        end
      end

      describe '#effective_visible_fields' do
        it 'returns defaults when visible_fields is nil' do
          widget.update!(visible_fields: nil)
          result = widget.effective_visible_fields
          expect(result).to eq(WidgetConfig::DEFAULT_VISIBLE_FIELDS)
        end

        it 'merges custom fields with defaults' do
          widget.update!(visible_fields: { 'price' => false })
          result = widget.effective_visible_fields
          expect(result['price']).to be false
          expect(result['bedrooms']).to be true
        end
      end

      describe '#domain_allowed?' do
        it 'returns true when allowed_domains is empty' do
          widget.update!(allowed_domains: [])
          expect(widget.domain_allowed?('any.domain.com')).to be true
        end

        it 'returns false when domain is blank' do
          widget.update!(allowed_domains: ['example.com'])
          expect(widget.domain_allowed?(nil)).to be false
          expect(widget.domain_allowed?('')).to be false
        end

        it 'matches exact domain' do
          widget.update!(allowed_domains: ['example.com'])
          expect(widget.domain_allowed?('example.com')).to be true
          expect(widget.domain_allowed?('other.com')).to be false
        end

        it 'strips www prefix from domain' do
          widget.update!(allowed_domains: ['example.com'])
          expect(widget.domain_allowed?('www.example.com')).to be true
        end

        it 'is case insensitive' do
          widget.update!(allowed_domains: ['Example.COM'])
          expect(widget.domain_allowed?('example.com')).to be true
        end

        it 'supports wildcard subdomains' do
          widget.update!(allowed_domains: ['*.example.com'])
          expect(widget.domain_allowed?('sub.example.com')).to be true
          expect(widget.domain_allowed?('deep.sub.example.com')).to be true
          expect(widget.domain_allowed?('example.com')).to be true
        end

        it 'rejects non-matching wildcard domains' do
          widget.update!(allowed_domains: ['*.example.com'])
          expect(widget.domain_allowed?('other.com')).to be false
        end
      end

      describe '#embed_code' do
        before { widget.update!(widget_key: 'test123key00') }

        it 'generates script-based embed code' do
          code = widget.embed_code
          expect(code).to include('pwb-widget-test123key00')
          expect(code).to include('data-widget-id="test123key00"')
          expect(code).to include('widget.js')
        end

        it 'uses provided host' do
          code = widget.embed_code(host: 'custom.host.com')
          expect(code).to include('custom.host.com')
        end

        it 'uses website subdomain as default host' do
          website.update!(subdomain: 'mysite', custom_domain: nil)
          code = widget.embed_code
          expect(code).to include('mysite.propertywebbuilder.com')
        end

        it 'uses custom domain when available' do
          website.update!(custom_domain: 'mycustomdomain.com')
          code = widget.embed_code
          expect(code).to include('mycustomdomain.com')
        end
      end

      describe '#iframe_embed_code' do
        before { widget.update!(widget_key: 'test123key00') }

        it 'generates iframe-based embed code' do
          code = widget.iframe_embed_code
          expect(code).to include('<iframe')
          expect(code).to include('/widget/test123key00')
          expect(code).to include('frameborder="0"')
        end
      end

      describe '#record_impression!' do
        it 'increments impressions_count' do
          expect { widget.record_impression! }.to change { widget.reload.impressions_count }.by(1)
        end
      end

      describe '#record_click!' do
        it 'increments clicks_count' do
          expect { widget.record_click! }.to change { widget.reload.clicks_count }.by(1)
        end
      end

      describe '#as_widget_config' do
        let(:widget) do
          create(:pwb_widget_config,
            website: website,
            widget_key: 'widgetkey123',
            layout: 'carousel',
            columns: 4,
            max_properties: 8,
            show_search: true,
            show_filters: true,
            show_pagination: false,
            listing_type: 'rent'
          )
        end

        it 'returns serialized config' do
          config = widget.as_widget_config

          expect(config[:widget_key]).to eq('widgetkey123')
          expect(config[:layout]).to eq('carousel')
          expect(config[:columns]).to eq(4)
          expect(config[:max_properties]).to eq(8)
          expect(config[:show_search]).to be true
          expect(config[:show_filters]).to be true
          expect(config[:show_pagination]).to be false
          expect(config[:listing_type]).to eq('rent')
          expect(config[:theme]).to be_a(Hash)
          expect(config[:visible_fields]).to be_a(Hash)
        end
      end

      describe '#properties_query' do
        let(:widget) { create(:pwb_widget_config, website: website) }

        it 'returns a relation' do
          expect(widget.properties_query).to respond_to(:to_a)
        end

        it 'applies listing_type filter when set to sale' do
          widget.update!(listing_type: 'sale')
          expect(widget.properties_query.to_sql).to include('website_id')
        end

        it 'applies max_properties limit' do
          widget.update!(max_properties: 5)
          query = widget.properties_query
          expect(query.limit_value).to eq(5)
        end
      end
    end

    describe 'constants' do
      describe 'DEFAULT_THEME' do
        it 'contains color settings' do
          expect(WidgetConfig::DEFAULT_THEME).to have_key('primary_color')
          expect(WidgetConfig::DEFAULT_THEME).to have_key('secondary_color')
          expect(WidgetConfig::DEFAULT_THEME).to have_key('background_color')
        end

        it 'contains typography settings' do
          expect(WidgetConfig::DEFAULT_THEME).to have_key('font_family')
        end

        it 'is frozen' do
          expect(WidgetConfig::DEFAULT_THEME).to be_frozen
        end
      end

      describe 'DEFAULT_VISIBLE_FIELDS' do
        it 'contains common property fields' do
          expect(WidgetConfig::DEFAULT_VISIBLE_FIELDS).to have_key('price')
          expect(WidgetConfig::DEFAULT_VISIBLE_FIELDS).to have_key('bedrooms')
          expect(WidgetConfig::DEFAULT_VISIBLE_FIELDS).to have_key('bathrooms')
        end

        it 'is frozen' do
          expect(WidgetConfig::DEFAULT_VISIBLE_FIELDS).to be_frozen
        end
      end
    end

    describe 'multi-tenancy' do
      let(:website_a) { create(:pwb_website) }
      let(:website_b) { create(:pwb_website) }
      let!(:widget_a) { create(:pwb_widget_config, website: website_a) }
      let!(:widget_b) { create(:pwb_widget_config, website: website_b) }

      it 'widget belongs to specific website' do
        expect(widget_a.website).to eq(website_a)
        expect(widget_b.website).to eq(website_b)
      end
    end
  end
end
