require 'rails_helper'

module Pwb
  RSpec.describe Website, type: :model do
    describe 'custom domain functionality' do
      let(:website) { FactoryBot.create(:pwb_website, subdomain: 'tenant-a') }
      let(:website_with_domain) { FactoryBot.create(:pwb_website, subdomain: 'tenant-b', custom_domain: 'myrealestate.com') }

      describe 'validations' do
        it 'allows valid custom domains' do
          website.custom_domain = 'example.com'
          expect(website).to be_valid
        end

        it 'allows www subdomain' do
          website.custom_domain = 'www.example.com'
          expect(website).to be_valid
        end

        it 'allows multi-level subdomains' do
          website.custom_domain = 'shop.example.co.uk'
          expect(website).to be_valid
        end

        it 'rejects invalid domain format' do
          website.custom_domain = 'not-a-domain'
          expect(website).not_to be_valid
          expect(website.errors[:custom_domain]).to include(/must be a valid domain name/)
        end

        it 'rejects domain with protocol' do
          website.custom_domain = 'https://example.com'
          expect(website).not_to be_valid
        end

        it 'rejects platform domains' do
          website.custom_domain = 'tenant.propertywebbuilder.com'
          expect(website).not_to be_valid
          expect(website.errors[:custom_domain]).to include(/cannot be a platform domain/)
        end

        it 'ensures uniqueness of custom domain' do
          website_with_domain # create the first one
          duplicate = FactoryBot.build(:pwb_website, subdomain: 'tenant-c', custom_domain: 'myrealestate.com')
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:custom_domain]).to include(/has already been taken/)
        end

        it 'allows blank custom domain' do
          website.custom_domain = ''
          expect(website).to be_valid
        end

        it 'allows nil custom domain' do
          website.custom_domain = nil
          expect(website).to be_valid
        end
      end

      describe '.find_by_custom_domain' do
        before { website_with_domain }

        it 'finds website by exact domain match' do
          result = Website.find_by_custom_domain('myrealestate.com')
          expect(result).to eq(website_with_domain)
        end

        it 'finds website case-insensitively' do
          result = Website.find_by_custom_domain('MyRealEstate.COM')
          expect(result).to eq(website_with_domain)
        end

        it 'finds website with www prefix when stored without' do
          result = Website.find_by_custom_domain('www.myrealestate.com')
          expect(result).to eq(website_with_domain)
        end

        it 'finds website without www prefix when stored with www' do
          website_with_domain.update!(custom_domain: 'www.myrealestate.com')
          result = Website.find_by_custom_domain('myrealestate.com')
          expect(result).to eq(website_with_domain)
        end

        it 'returns nil for non-existent domain' do
          result = Website.find_by_custom_domain('nonexistent.com')
          expect(result).to be_nil
        end

        it 'returns nil for blank domain' do
          expect(Website.find_by_custom_domain('')).to be_nil
          expect(Website.find_by_custom_domain(nil)).to be_nil
        end
      end

      describe '.find_by_host' do
        before do
          website
          website_with_domain
        end

        context 'with custom domain' do
          it 'finds website by custom domain' do
            result = Website.find_by_host('myrealestate.com')
            expect(result).to eq(website_with_domain)
          end

          it 'finds website by custom domain with www' do
            result = Website.find_by_host('www.myrealestate.com')
            expect(result).to eq(website_with_domain)
          end
        end

        context 'with platform subdomain' do
          it 'finds website by subdomain on platform domain' do
            result = Website.find_by_host('tenant-a.propertywebbuilder.com')
            expect(result).to eq(website)
          end

          it 'finds website by subdomain on localhost' do
            result = Website.find_by_host('tenant-a.localhost')
            expect(result).to eq(website)
          end

          it 'finds website by subdomain on e2e.localhost' do
            result = Website.find_by_host('tenant-a.e2e.localhost')
            expect(result).to eq(website)
          end
        end

        it 'returns nil for non-existent host' do
          expect(Website.find_by_host('unknown.example.com')).to be_nil
        end
      end

      describe '.platform_domain?' do
        it 'returns true for platform domains' do
          expect(Website.platform_domain?('tenant.propertywebbuilder.com')).to be true
          expect(Website.platform_domain?('tenant.localhost')).to be true
          expect(Website.platform_domain?('tenant.e2e.localhost')).to be true
        end

        it 'returns false for custom domains' do
          expect(Website.platform_domain?('myrealestate.com')).to be false
          expect(Website.platform_domain?('www.example.org')).to be false
        end
      end

      describe '.normalize_domain' do
        it 'removes protocol' do
          expect(Website.normalize_domain('https://example.com')).to eq('example.com')
          expect(Website.normalize_domain('http://example.com')).to eq('example.com')
        end

        it 'removes trailing path' do
          expect(Website.normalize_domain('example.com/path/to/page')).to eq('example.com')
        end

        it 'removes port' do
          expect(Website.normalize_domain('example.com:3000')).to eq('example.com')
        end

        it 'lowercases domain' do
          expect(Website.normalize_domain('EXAMPLE.COM')).to eq('example.com')
        end

        it 'handles already normalized domains' do
          expect(Website.normalize_domain('example.com')).to eq('example.com')
        end
      end

      describe '.extract_subdomain_from_host' do
        it 'extracts subdomain from platform domain' do
          expect(Website.extract_subdomain_from_host('tenant.propertywebbuilder.com')).to eq('tenant')
        end

        it 'extracts first part for multi-level subdomains' do
          expect(Website.extract_subdomain_from_host('tenant.staging.propertywebbuilder.com')).to eq('tenant')
        end

        it 'returns nil for apex platform domain' do
          expect(Website.extract_subdomain_from_host('propertywebbuilder.com')).to be_nil
        end

        it 'returns nil for non-platform domains' do
          expect(Website.extract_subdomain_from_host('example.com')).to be_nil
        end
      end

      describe '#generate_domain_verification_token!' do
        it 'generates a verification token' do
          expect(website.custom_domain_verification_token).to be_nil
          website.generate_domain_verification_token!
          expect(website.custom_domain_verification_token).to be_present
          expect(website.custom_domain_verification_token.length).to eq(32) # hex(16) = 32 chars
        end

        it 'generates unique tokens' do
          website.generate_domain_verification_token!
          token1 = website.custom_domain_verification_token

          website.generate_domain_verification_token!
          token2 = website.custom_domain_verification_token

          expect(token1).not_to eq(token2)
        end
      end

      describe '#custom_domain_active?' do
        it 'returns false when no custom domain' do
          expect(website.custom_domain_active?).to be false
        end

        it 'returns true when custom domain is verified' do
          website_with_domain.update!(custom_domain_verified: true)
          expect(website_with_domain.custom_domain_active?).to be true
        end

        it 'returns true in development even if not verified' do
          # Test runs in test environment which also allows unverified
          expect(website_with_domain.custom_domain_active?).to be true
        end
      end

      describe '#primary_url' do
        it 'returns custom domain URL when active' do
          website_with_domain.update!(custom_domain_verified: true)
          expect(website_with_domain.primary_url).to eq('https://myrealestate.com')
        end

        it 'returns subdomain URL when no custom domain' do
          expect(website.primary_url).to eq('https://tenant-a.propertywebbuilder.com')
        end

        it 'returns nil when no subdomain or custom domain' do
          empty_website = FactoryBot.build(:pwb_website, subdomain: nil, custom_domain: nil)
          expect(empty_website.primary_url).to be_nil
        end
      end
    end
  end
end
