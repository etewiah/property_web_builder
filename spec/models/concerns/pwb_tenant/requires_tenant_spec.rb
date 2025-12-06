# frozen_string_literal: true

require 'rails_helper'

module PwbTenant
  RSpec.describe RequiresTenant, type: :model do
    # RequiresTenant is a concern that enforces tenant context for PwbTenant:: models.
    # It raises an error if queries are attempted without a tenant set.

    let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a') }
    let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b') }

    # Create test data using Pwb:: models (which don't require tenant)
    let!(:contact_a) { Pwb::Contact.create!(first_name: 'Alice', website: website_a) }
    let!(:contact_b) { Pwb::Contact.create!(first_name: 'Bob', website: website_b) }

    after do
      # Clean up tenant after each test
      ActsAsTenant.current_tenant = nil
    end

    describe 'when no tenant is set' do
      before do
        ActsAsTenant.current_tenant = nil
      end

      it 'raises NoTenantSet error on .all' do
        expect {
          PwbTenant::Contact.all.to_a
        }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end

      it 'raises NoTenantSet error on .count' do
        expect {
          PwbTenant::Contact.count
        }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end

      it 'raises NoTenantSet error on .find' do
        expect {
          PwbTenant::Contact.find(contact_a.id)
        }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end

      it 'raises NoTenantSet error on .where' do
        expect {
          PwbTenant::Contact.where(first_name: 'Alice').to_a
        }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end

      it 'includes helpful message in error' do
        expect {
          PwbTenant::Contact.count
        }.to raise_error(ActsAsTenant::Errors::NoTenantSet, /Use Pwb::Contact for cross-tenant queries/)
      end
    end

    describe 'when tenant is set via ActsAsTenant.current_tenant' do
      before do
        ActsAsTenant.current_tenant = website_a
      end

      it 'allows queries' do
        expect { PwbTenant::Contact.all.to_a }.not_to raise_error
      end

      it 'returns only records for current tenant' do
        contact_ids = PwbTenant::Contact.pluck(:id)
        expect(contact_ids).to include(contact_a.id)
        expect(contact_ids).not_to include(contact_b.id)
      end

      it 'scopes .count to current tenant' do
        expect(PwbTenant::Contact.count).to eq(1)
      end

      it 'finds records within current tenant' do
        found = PwbTenant::Contact.find(contact_a.id)
        expect(found.id).to eq(contact_a.id)
        expect(found.first_name).to eq(contact_a.first_name)
      end

      it 'raises RecordNotFound for records in other tenant' do
        expect {
          PwbTenant::Contact.find(contact_b.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'when tenant is set via ActsAsTenant.with_tenant block' do
      it 'allows queries within the block' do
        result = ActsAsTenant.with_tenant(website_a) do
          PwbTenant::Contact.count
        end
        expect(result).to eq(1)
      end

      it 'scopes to correct tenant within the block' do
        ids_a = ActsAsTenant.with_tenant(website_a) { PwbTenant::Contact.pluck(:id) }
        ids_b = ActsAsTenant.with_tenant(website_b) { PwbTenant::Contact.pluck(:id) }

        expect(ids_a).to eq([contact_a.id])
        expect(ids_b).to eq([contact_b.id])
      end

      it 'raises error outside the block if no tenant set' do
        ActsAsTenant.with_tenant(website_a) do
          PwbTenant::Contact.count # Works inside block
        end

        expect {
          PwbTenant::Contact.count # Fails outside block
        }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end
    end

    describe 'Pwb:: models (base models without RequiresTenant)' do
      before do
        ActsAsTenant.current_tenant = nil
      end

      it 'allows queries without tenant' do
        expect { Pwb::Contact.all.to_a }.not_to raise_error
      end

      it 'returns all records across tenants' do
        contacts = Pwb::Contact.all
        expect(contacts).to include(contact_a)
        expect(contacts).to include(contact_b)
      end

      it 'counts all records across tenants' do
        expect(Pwb::Contact.count).to eq(2)
      end
    end

    describe 'switching between tenants' do
      it 'correctly scopes when tenant changes' do
        ActsAsTenant.current_tenant = website_a
        expect(PwbTenant::Contact.pluck(:first_name)).to eq(['Alice'])

        ActsAsTenant.current_tenant = website_b
        expect(PwbTenant::Contact.pluck(:first_name)).to eq(['Bob'])
      end
    end

    describe 'different PwbTenant models' do
      # Test that RequiresTenant works across different models

      let!(:page_a) { Pwb::Page.create!(slug: 'home', website: website_a) }
      let!(:link_a) { Pwb::Link.create!(slug: 'nav_home', placement: :top_nav, website: website_a) }

      it 'enforces tenant for PwbTenant::Page' do
        expect { PwbTenant::Page.count }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

        ActsAsTenant.current_tenant = website_a
        expect(PwbTenant::Page.count).to eq(1)
      end

      it 'enforces tenant for PwbTenant::Link' do
        expect { PwbTenant::Link.count }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

        ActsAsTenant.current_tenant = website_a
        expect(PwbTenant::Link.count).to eq(1)
      end
    end
  end
end
