# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_tenant_settings
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  configuration            :jsonb
#  default_available_themes :text             default([]), is an Array
#  singleton_key            :string           default("default"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_pwb_tenant_settings_on_singleton_key  (singleton_key) UNIQUE
#
require 'rails_helper'

module Pwb
  RSpec.describe TenantSettings, type: :model do
    describe '.instance' do
      it 'creates a singleton instance if none exists' do
        TenantSettings.delete_all
        expect { TenantSettings.instance }.to change { TenantSettings.count }.by(1)
      end

      it 'returns existing instance if one exists' do
        TenantSettings.delete_all
        first_instance = TenantSettings.instance
        second_instance = TenantSettings.instance

        expect(first_instance.id).to eq(second_instance.id)
      end

      it 'returns the same instance on subsequent calls' do
        instance1 = TenantSettings.instance
        instance2 = TenantSettings.instance

        expect(instance1.id).to eq(instance2.id)
      end
    end

    describe '.default_themes' do
      before { TenantSettings.delete_all }

      it 'returns empty array when no themes configured' do
        TenantSettings.create!(singleton_key: 'default', default_available_themes: [])
        expect(TenantSettings.default_themes).to eq([])
      end

      it 'returns configured themes' do
        TenantSettings.create!(singleton_key: 'default', default_available_themes: %w[default brisbane])
        expect(TenantSettings.default_themes).to eq(%w[default brisbane])
      end
    end

    describe '.update_default_themes' do
      before { TenantSettings.delete_all }

      it 'updates the default themes' do
        TenantSettings.update_default_themes(%w[default bologna])
        expect(TenantSettings.default_themes).to eq(%w[default bologna])
      end

      it 'rejects blank values' do
        TenantSettings.update_default_themes(['default', '', 'brisbane', nil])
        expect(TenantSettings.default_themes).to eq(%w[default brisbane])
      end
    end

    describe '#effective_default_themes' do
      before { TenantSettings.delete_all }

      it 'returns configured themes when present' do
        settings = TenantSettings.create!(
          singleton_key: 'default',
          default_available_themes: %w[default brisbane bologna]
        )
        expect(settings.effective_default_themes).to eq(%w[default brisbane bologna])
      end

      it 'returns only default theme when no themes configured' do
        settings = TenantSettings.create!(singleton_key: 'default', default_available_themes: [])
        expect(settings.effective_default_themes).to eq(['default'])
      end

      it 'returns only default theme when themes is nil' do
        settings = TenantSettings.create!(singleton_key: 'default', default_available_themes: nil)
        expect(settings.effective_default_themes).to eq(['default'])
      end

      it 'removes duplicates' do
        settings = TenantSettings.create!(
          singleton_key: 'default',
          default_available_themes: %w[default brisbane default]
        )
        expect(settings.effective_default_themes).to eq(%w[default brisbane])
      end
    end

    describe '#theme_available?' do
      before { TenantSettings.delete_all }

      let(:settings) do
        TenantSettings.create!(
          singleton_key: 'default',
          default_available_themes: %w[default brisbane bologna]
        )
      end

      it 'returns true for available themes' do
        expect(settings.theme_available?('default')).to be true
        expect(settings.theme_available?('brisbane')).to be true
        expect(settings.theme_available?('bologna')).to be true
      end

      it 'returns false for unavailable themes' do
        expect(settings.theme_available?('barcelona')).to be false
        expect(settings.theme_available?('biarritz')).to be false
      end

      it 'handles symbol input' do
        expect(settings.theme_available?(:brisbane)).to be true
      end
    end
  end
end
