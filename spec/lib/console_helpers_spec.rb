# frozen_string_literal: true

require 'rails_helper'

# Load the console helpers module
require Rails.root.join('config/initializers/console_helpers')

RSpec.describe Pwb::ConsoleHelpers do
  # Include the helpers in the test context
  include described_class

  let!(:website_a) { create(:pwb_website, subdomain: 'alpha') }
  let!(:website_b) { create(:pwb_website, subdomain: 'beta') }

  after do
    # Clean up tenant state after each test
    ActsAsTenant.current_tenant = nil
    Pwb::Current.website = nil
  end

  describe '#tenant' do
    context 'with valid integer ID' do
      it 'sets ActsAsTenant.current_tenant' do
        tenant(website_a.id)
        expect(ActsAsTenant.current_tenant).to eq(website_a)
      end

      it 'sets Pwb::Current.website' do
        tenant(website_a.id)
        expect(Pwb::Current.website).to eq(website_a)
      end

      it 'returns the website' do
        result = tenant(website_a.id)
        expect(result).to eq(website_a)
      end

      it 'allows PwbTenant queries after setting' do
        Pwb::Contact.create!(first_name: 'Test', website: website_a)

        tenant(website_a.id)

        expect { PwbTenant::Contact.count }.not_to raise_error
        expect(PwbTenant::Contact.count).to eq(1)
      end
    end

    context 'with valid subdomain string' do
      it 'sets tenant by subdomain' do
        tenant('alpha')
        expect(ActsAsTenant.current_tenant).to eq(website_a)
      end

      it 'returns the website' do
        result = tenant('beta')
        expect(result).to eq(website_b)
      end
    end

    context 'with invalid ID or subdomain' do
      it 'returns nil for non-existent ID' do
        result = tenant(99999)
        expect(result).to be_nil
      end

      it 'returns nil for non-existent subdomain' do
        result = tenant('nonexistent')
        expect(result).to be_nil
      end

      it 'does not set tenant for invalid input' do
        tenant(99999)
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end

    context 'switching between tenants' do
      it 'correctly switches from one tenant to another' do
        tenant(website_a.id)
        expect(ActsAsTenant.current_tenant).to eq(website_a)

        tenant(website_b.id)
        expect(ActsAsTenant.current_tenant).to eq(website_b)
      end
    end
  end

  describe '#current_tenant' do
    context 'when tenant is set via ActsAsTenant' do
      before { ActsAsTenant.current_tenant = website_a }

      it 'returns the current tenant' do
        expect(current_tenant).to eq(website_a)
      end
    end

    context 'when tenant is set via Pwb::Current only' do
      before do
        ActsAsTenant.current_tenant = nil
        Pwb::Current.website = website_b
      end

      it 'falls back to Pwb::Current.website' do
        expect(current_tenant).to eq(website_b)
      end
    end

    context 'when no tenant is set' do
      before do
        ActsAsTenant.current_tenant = nil
        Pwb::Current.website = nil
      end

      it 'returns nil' do
        expect(current_tenant).to be_nil
      end
    end
  end

  describe '#clear_tenant' do
    before do
      tenant(website_a.id)
    end

    it 'clears ActsAsTenant.current_tenant' do
      clear_tenant
      expect(ActsAsTenant.current_tenant).to be_nil
    end

    it 'clears Pwb::Current.website' do
      clear_tenant
      expect(Pwb::Current.website).to be_nil
    end

    it 'returns nil' do
      expect(clear_tenant).to be_nil
    end

    it 'causes PwbTenant queries to fail after clearing' do
      expect { PwbTenant::Contact.count }.not_to raise_error

      clear_tenant

      expect { PwbTenant::Contact.count }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end
  end

  describe '#list_tenants' do
    it 'returns nil' do
      expect(list_tenants).to be_nil
    end

    it 'does not raise errors' do
      expect { list_tenants }.not_to raise_error
    end
  end

  describe 'integration with RequiresTenant' do
    let!(:contact_a) { Pwb::Contact.create!(first_name: 'Alice', website: website_a) }
    let!(:contact_b) { Pwb::Contact.create!(first_name: 'Bob', website: website_b) }

    it 'allows PwbTenant queries after tenant() is called' do
      expect { PwbTenant::Contact.count }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

      tenant(website_a.id)

      expect(PwbTenant::Contact.count).to eq(1)
      expect(PwbTenant::Contact.first.first_name).to eq('Alice')
    end

    it 'scopes queries to correct tenant' do
      tenant(website_a.id)
      expect(PwbTenant::Contact.pluck(:first_name)).to eq(['Alice'])

      tenant(website_b.id)
      expect(PwbTenant::Contact.pluck(:first_name)).to eq(['Bob'])
    end

    it 'Pwb:: models still return all records regardless of tenant' do
      tenant(website_a.id)

      # Pwb:: models ignore tenant context
      expect(Pwb::Contact.count).to eq(2)
      expect(Pwb::Contact.pluck(:first_name)).to contain_exactly('Alice', 'Bob')
    end
  end
end
