# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClientRenderingConstraint, type: :constraint do
  let(:constraint) { described_class.new }

  # Set up tenant settings
  before(:all) do
    Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |ts|
      ts.default_available_themes = %w[default brisbane]
    end
  end

  describe '#matches?' do
    let!(:client_theme) { create(:pwb_client_theme, :amsterdam) }

    context 'with rails-rendered website' do
      let!(:website) { create(:pwb_website, subdomain: 'rails-site', rendering_mode: 'rails') }

      it 'returns false' do
        request = mock_request('rails-site.example.com', '/')
        expect(constraint.matches?(request)).to be false
      end
    end

    context 'with client-rendered website' do
      let!(:website) do
        create(:pwb_website, subdomain: 'client-site', rendering_mode: 'client', client_theme_name: 'amsterdam')
      end

      it 'returns true for normal paths' do
        request = mock_request('client-site.example.com', '/')
        expect(constraint.matches?(request)).to be true
      end

      it 'returns true for nested paths' do
        request = mock_request('client-site.example.com', '/properties/123')
        expect(constraint.matches?(request)).to be true
      end
    end

    context 'with excluded paths' do
      let!(:website) do
        create(:pwb_website, subdomain: 'client-site', rendering_mode: 'client', client_theme_name: 'amsterdam')
      end

      described_class::EXCLUDED_PATHS.each do |excluded_path|
        it "returns false for #{excluded_path}" do
          request = mock_request('client-site.example.com', "#{excluded_path}/something")
          expect(constraint.matches?(request)).to be false
        end
      end
    end

    context 'with custom domain' do
      let!(:website) do
        create(:pwb_website,
               subdomain: 'customdomain-site',
               custom_domain: 'myrealestate.com',
               rendering_mode: 'client',
               client_theme_name: 'amsterdam')
      end

      it 'matches by custom domain' do
        request = mock_request('myrealestate.com', '/')
        expect(constraint.matches?(request)).to be true
      end
    end

    context 'with unknown host' do
      it 'returns false' do
        request = mock_request('unknown.example.com', '/')
        expect(constraint.matches?(request)).to be false
      end
    end
  end

  private

  def mock_request(host, path)
    double('request', host: host, path: path)
  end
end
