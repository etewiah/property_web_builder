require 'rails_helper'

module Pwb
  RSpec.describe SubdomainGenerator do
    describe '.generate' do
      it 'generates a subdomain in adjective-noun-number format' do
        name = SubdomainGenerator.generate
        expect(name).to match(/\A[a-z]+-[a-z]+-\d{2}\z/)
      end

      it 'generates unique subdomains' do
        names = 10.times.map { SubdomainGenerator.generate }
        expect(names.uniq.count).to eq(10)
      end

      it 'does not generate existing subdomains' do
        Subdomain.create!(name: 'sunny-meadow-42')
        100.times do
          name = SubdomainGenerator.generate
          expect(name).not_to eq('sunny-meadow-42')
        end
      end
    end

    describe '.generate_batch' do
      it 'generates the specified number of unique names' do
        names = SubdomainGenerator.generate_batch(20)
        expect(names.count).to eq(20)
        expect(names.uniq.count).to eq(20)
      end

      it 'does not include existing subdomains' do
        Subdomain.create!(name: 'existing-name-99')
        names = SubdomainGenerator.generate_batch(50)
        expect(names).not_to include('existing-name-99')
      end
    end

    describe '.populate_pool' do
      it 'creates subdomains in the database' do
        expect {
          SubdomainGenerator.populate_pool(count: 10)
        }.to change(Subdomain, :count).by(10)
      end

      it 'creates subdomains in available state' do
        SubdomainGenerator.populate_pool(count: 5)
        expect(Subdomain.available.count).to be >= 5
      end
    end

    describe '.ensure_pool_minimum' do
      it 'replenishes pool when below minimum' do
        SubdomainGenerator.populate_pool(count: 5)
        expect {
          SubdomainGenerator.ensure_pool_minimum(minimum: 20)
        }.to change(Subdomain.available, :count)
        expect(Subdomain.available.count).to be >= 20
      end

      it 'does nothing when pool is above minimum' do
        SubdomainGenerator.populate_pool(count: 30)
        expect {
          SubdomainGenerator.ensure_pool_minimum(minimum: 20)
        }.not_to change(Subdomain.available, :count)
      end
    end

    describe '.validate_custom_name' do
      it 'accepts valid names' do
        result = SubdomainGenerator.validate_custom_name('my-agency-123')
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:normalized]).to eq('my-agency-123')
      end

      it 'normalizes names to lowercase' do
        result = SubdomainGenerator.validate_custom_name('My-Agency-123')
        expect(result[:normalized]).to eq('my-agency-123')
      end

      it 'normalizes uppercase names and validates them' do
        # The generator normalizes to lowercase, so 'MyAgency' becomes 'myagency' which is valid
        result = SubdomainGenerator.validate_custom_name('MyAgency')
        expect(result[:normalized]).to eq('myagency')
        expect(result[:valid]).to be true
      end

      it 'rejects names with leading hyphen' do
        result = SubdomainGenerator.validate_custom_name('-my-agency')
        expect(result[:valid]).to be false
      end

      it 'rejects names with trailing hyphen' do
        result = SubdomainGenerator.validate_custom_name('my-agency-')
        expect(result[:valid]).to be false
      end

      it 'rejects names that are too short' do
        result = SubdomainGenerator.validate_custom_name('ab')
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/at least 3 characters/))
      end

      it 'rejects names that are too long' do
        result = SubdomainGenerator.validate_custom_name('a' * 50)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/40 characters/))
      end

      it 'rejects reserved names' do
        result = SubdomainGenerator.validate_custom_name('admin')
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/reserved/))
      end

      it 'rejects names already taken by websites' do
        FactoryBot.create(:pwb_website, subdomain: 'taken-name')
        result = SubdomainGenerator.validate_custom_name('taken-name')
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/already taken/))
      end

      it 'rejects names that are allocated in subdomain pool' do
        website = FactoryBot.create(:pwb_website)
        Subdomain.create!(name: 'pool-allocated', aasm_state: 'allocated', website: website)
        result = SubdomainGenerator.validate_custom_name('pool-allocated')
        expect(result[:valid]).to be false
      end

      context 'with reserved_by_email' do
        it 'allows reserved subdomain for same email' do
          Subdomain.create!(name: 'my-reserved', aasm_state: 'reserved', reserved_by_email: 'user@example.com')
          result = SubdomainGenerator.validate_custom_name('my-reserved', reserved_by_email: 'user@example.com')
          expect(result[:valid]).to be true
        end

        it 'rejects reserved subdomain for different email' do
          Subdomain.create!(name: 'my-reserved', aasm_state: 'reserved', reserved_by_email: 'other@example.com')
          result = SubdomainGenerator.validate_custom_name('my-reserved', reserved_by_email: 'user@example.com')
          expect(result[:valid]).to be false
        end
      end
    end

    describe 'ADJECTIVES and NOUNS constants' do
      it 'has a good variety of adjectives' do
        expect(SubdomainGenerator::ADJECTIVES.count).to be > 50
      end

      it 'has a good variety of nouns' do
        expect(SubdomainGenerator::NOUNS.count).to be > 50
      end

      it 'uses only lowercase words' do
        expect(SubdomainGenerator::ADJECTIVES.all? { |w| w == w.downcase }).to be true
        expect(SubdomainGenerator::NOUNS.all? { |w| w == w.downcase }).to be true
      end
    end
  end
end
