# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdminHelper, type: :helper do
  describe '#format_date' do
    it 'formats date with month abbreviation' do
      date = Time.new(2024, 6, 15, 14, 30, 0)
      result = helper.format_date(date)
      expect(result).to eq('Jun 15, 2024 14:30')
    end

    it 'returns N/A for nil date' do
      expect(helper.format_date(nil)).to eq('N/A')
    end

    it 'returns N/A for blank date' do
      expect(helper.format_date('')).to eq('N/A')
    end
  end

  describe '#website_link' do
    let(:website) { create(:pwb_website, subdomain: 'test-site') }

    it 'returns link to website with subdomain as text' do
      result = helper.website_link(website)
      expect(result).to include('test-site')
      expect(result).to include('href')
    end

    it 'returns N/A for nil website' do
      expect(helper.website_link(nil)).to eq('N/A')
    end

    it 'handles website without subdomain' do
      website = create(:pwb_website, subdomain: nil)
      result = helper.website_link(website)
      expect(result).to include('(No subdomain)')
    end
  end

  describe '#user_link' do
    let(:website) { create(:pwb_website, subdomain: 'user-test') }
    let(:user) { create(:pwb_user, email: 'test@example.com', website: website) }

    it 'returns link to user with email as text' do
      result = helper.user_link(user)
      expect(result).to include('test@example.com')
      expect(result).to include('href')
    end

    it 'returns N/A for nil user' do
      expect(helper.user_link(nil)).to eq('N/A')
    end
  end

  describe '#flash_class' do
    it 'returns blue classes for notice' do
      result = helper.flash_class(:notice)
      expect(result).to include('bg-blue-100')
      expect(result).to include('border-blue-500')
      expect(result).to include('text-blue-700')
    end

    it 'returns green classes for success' do
      result = helper.flash_class(:success)
      expect(result).to include('bg-green-100')
      expect(result).to include('border-green-500')
      expect(result).to include('text-green-700')
    end

    it 'returns red classes for alert' do
      result = helper.flash_class(:alert)
      expect(result).to include('bg-red-100')
      expect(result).to include('border-red-500')
      expect(result).to include('text-red-700')
    end

    it 'returns red classes for error' do
      result = helper.flash_class(:error)
      expect(result).to include('bg-red-100')
      expect(result).to include('border-red-500')
      expect(result).to include('text-red-700')
    end

    it 'returns yellow classes for warning' do
      result = helper.flash_class(:warning)
      expect(result).to include('bg-yellow-100')
      expect(result).to include('border-yellow-500')
      expect(result).to include('text-yellow-700')
    end

    it 'returns gray classes for unknown type' do
      result = helper.flash_class(:unknown)
      expect(result).to include('bg-gray-100')
      expect(result).to include('border-gray-500')
      expect(result).to include('text-gray-700')
    end

    it 'handles string type' do
      result = helper.flash_class('notice')
      expect(result).to include('bg-blue-100')
    end
  end

  describe '#badge_for_status' do
    context 'when active' do
      it 'returns green Active badge' do
        result = helper.badge_for_status(true)
        expect(result).to include('Active')
        expect(result).to include('bg-green-100')
        expect(result).to include('text-green-800')
      end
    end

    context 'when inactive' do
      it 'returns gray Inactive badge' do
        result = helper.badge_for_status(false)
        expect(result).to include('Inactive')
        expect(result).to include('bg-gray-100')
        expect(result).to include('text-gray-800')
      end
    end

    it 'returns a span element' do
      result = helper.badge_for_status(true)
      expect(result).to include('<span')
    end
  end

  describe '#sortable_column' do
    before do
      allow(helper).to receive(:params).and_return({})
      # Provide a request path for link_to to work with
      allow(helper).to receive(:url_for) do |options|
        params = options.to_a.map { |k, v| "#{k}=#{v}" }.join('&')
        "?#{params}"
      end
    end

    it 'returns link with titleized column name' do
      result = helper.sortable_column('created_at')
      expect(result).to include('Created At')
    end

    it 'uses custom title when provided' do
      result = helper.sortable_column('created_at', 'Creation Date')
      expect(result).to include('Creation Date')
    end

    it 'defaults to ascending direction' do
      result = helper.sortable_column('name')
      expect(result).to include('direction=asc')
    end

    context 'when already sorted ascending' do
      before do
        allow(helper).to receive(:params).and_return({ sort: 'name', direction: 'asc' })
      end

      it 'toggles to descending' do
        result = helper.sortable_column('name')
        expect(result).to include('direction=desc')
      end
    end

    context 'when already sorted descending' do
      before do
        allow(helper).to receive(:params).and_return({ sort: 'name', direction: 'desc' })
      end

      it 'toggles to ascending' do
        result = helper.sortable_column('name')
        expect(result).to include('direction=asc')
      end
    end

    context 'when sorted by different column' do
      before do
        allow(helper).to receive(:params).and_return({ sort: 'other', direction: 'asc' })
      end

      it 'defaults to ascending' do
        result = helper.sortable_column('name')
        expect(result).to include('direction=asc')
      end
    end
  end
end
