# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteDomainConfigurable, type: :model do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }

  around do |example|
    ActsAsTenant.with_tenant(website) do
      example.run
    end
  end

  describe 'validations' do
    describe 'subdomain' do
      it 'allows valid subdomains' do
        %w[mysite my-site site123 a1b2c3].each do |subdomain|
          website.subdomain = subdomain
          expect(website).to be_valid
        end
      end

      it 'rejects invalid subdomains' do
        # Only subdomains starting or ending with hyphen are rejected
        %w[-invalid invalid-].each do |subdomain|
          website.subdomain = subdomain
          expect(website).not_to be_valid
        end
      end

      it 'rejects reserved subdomains' do
        %w[www api admin app mail].each do |subdomain|
          website.subdomain = subdomain
          expect(website).not_to be_valid
          expect(website.errors[:subdomain]).to include('is reserved and cannot be used')
        end
      end

      it 'enforces uniqueness' do
        create(:pwb_website, subdomain: 'unique-site')
        website.subdomain = 'unique-site'
        expect(website).not_to be_valid
      end

      it 'enforces length constraints' do
        website.subdomain = 'a'
        expect(website).not_to be_valid

        website.subdomain = 'a' * 64
        expect(website).not_to be_valid
      end
    end

    describe 'custom_domain' do
      it 'allows valid domains' do
        %w[example.com www.example.com sub.domain.co.uk].each do |domain|
          website.custom_domain = domain
          expect(website).to be_valid
        end
      end

      it 'rejects invalid domains' do
        %w[invalid notadomain .com example].each do |domain|
          website.custom_domain = domain
          expect(website).not_to be_valid
        end
      end

      it 'rejects platform domains' do
        website.custom_domain = 'mysite.propertywebbuilder.com'
        expect(website).not_to be_valid
        expect(website.errors[:custom_domain]).to include(match(/cannot be a platform domain/))
      end
    end
  end

  describe '.find_by_subdomain' do
    it 'finds website by subdomain case-insensitively' do
      expect(Pwb::Website.find_by(subdomain: 'TEST-SITE')).to eq(website)
      expect(Pwb::Website.find_by(subdomain: 'test-site')).to eq(website)
    end

    it 'returns nil for non-existent subdomain' do
      expect(Pwb::Website.find_by(subdomain: 'nonexistent')).to be_nil
    end

    it 'returns nil for blank subdomain' do
      expect(Pwb::Website.find_by(subdomain: '')).to be_nil
      expect(Pwb::Website.find_by(subdomain: nil)).to be_nil
    end
  end

  describe '.find_by_custom_domain' do
    before do
      website.update!(custom_domain: 'example.com')
    end

    it 'finds website by exact domain' do
      expect(Pwb::Website.find_by(custom_domain: 'example.com')).to eq(website)
    end

    it 'finds website case-insensitively' do
      expect(Pwb::Website.find_by(custom_domain: 'EXAMPLE.COM')).to eq(website)
    end

    it 'handles www prefix' do
      expect(Pwb::Website.find_by(custom_domain: 'www.example.com')).to eq(website)
    end

    it 'returns nil for non-existent domain' do
      expect(Pwb::Website.find_by(custom_domain: 'other.com')).to be_nil
    end
  end

  describe '.find_by_host' do
    it 'finds by subdomain for platform domains' do
      expect(Pwb::Website.find_by(host: 'test-site.localhost')).to eq(website)
    end

    it 'finds by custom domain for non-platform domains' do
      website.update!(custom_domain: 'myrealestate.com')
      expect(Pwb::Website.find_by(host: 'myrealestate.com')).to eq(website)
    end

    it 'returns nil for blank host' do
      expect(Pwb::Website.find_by(host: '')).to be_nil
      expect(Pwb::Website.find_by(host: nil)).to be_nil
    end
  end

  describe '.normalize_domain' do
    it 'removes protocol' do
      expect(Pwb::Website.normalize_domain('https://example.com')).to eq('example.com')
      expect(Pwb::Website.normalize_domain('http://example.com')).to eq('example.com')
    end

    it 'removes path' do
      expect(Pwb::Website.normalize_domain('example.com/path/to/page')).to eq('example.com')
    end

    it 'removes port' do
      expect(Pwb::Website.normalize_domain('example.com:3000')).to eq('example.com')
    end

    it 'lowercases and strips whitespace' do
      expect(Pwb::Website.normalize_domain('  EXAMPLE.COM  ')).to eq('example.com')
    end
  end

  describe '.platform_domain?' do
    it 'returns true for platform domains' do
      expect(Pwb::Website.platform_domain?('test.localhost')).to be true
      expect(Pwb::Website.platform_domain?('site.propertywebbuilder.com')).to be true
    end

    it 'returns false for non-platform domains' do
      expect(Pwb::Website.platform_domain?('example.com')).to be false
    end
  end

  describe '.extract_subdomain_from_host' do
    it 'extracts subdomain from platform domain host' do
      expect(Pwb::Website.extract_subdomain_from_host('mysite.localhost')).to eq('mysite')
      expect(Pwb::Website.extract_subdomain_from_host('test.pwb.localhost')).to eq('test')
    end

    it 'returns nil for non-platform domains' do
      expect(Pwb::Website.extract_subdomain_from_host('example.com')).to be_nil
    end
  end

  describe '#generate_domain_verification_token!' do
    it 'generates a unique token' do
      website.generate_domain_verification_token!
      expect(website.custom_domain_verification_token).to be_present
      expect(website.custom_domain_verification_token.length).to eq(32)
    end
  end

  describe '#custom_domain_active?' do
    it 'returns false when custom domain is blank' do
      website.custom_domain = nil
      expect(website.custom_domain_active?).to be false
    end

    it 'returns true when verified' do
      website.update!(custom_domain: 'example.com', custom_domain_verified: true)
      expect(website.custom_domain_active?).to be true
    end

    it 'returns true in development/test even if not verified' do
      website.update!(custom_domain: 'example.com', custom_domain_verified: false)
      expect(website.custom_domain_active?).to be true
    end
  end

  describe '#primary_url' do
    it 'returns custom domain URL when active' do
      website.update!(custom_domain: 'example.com', custom_domain_verified: true)
      expect(website.primary_url).to eq('https://example.com')
    end

    it 'returns subdomain URL when no custom domain' do
      website.custom_domain = nil
      expect(website.primary_url).to match(%r{https://test-site\.})
    end

    it 'returns nil when neither subdomain nor custom domain' do
      website.subdomain = nil
      website.custom_domain = nil
      expect(website.primary_url).to be_nil
    end
  end
end
