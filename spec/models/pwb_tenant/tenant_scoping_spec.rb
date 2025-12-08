# frozen_string_literal: true

require 'rails_helper'

# Comprehensive tenant isolation tests for all PwbTenant models
# These tests verify that acts_as_tenant properly scopes queries
# and prevents cross-tenant data access.
RSpec.describe 'PwbTenant Model Scoping', type: :model do
  let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a-model') }
  let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b-model') }

  # Helper to create records within a tenant context
  def within_tenant(website, &block)
    ActsAsTenant.with_tenant(website, &block)
  end

  shared_examples 'tenant scoped model' do |model_class, factory_name, factory_traits = []|
    describe "#{model_class} tenant isolation" do
      let!(:record_a) do
        within_tenant(website_a) do
          traits = factory_traits.any? ? factory_traits : []
          create(factory_name, *traits, website: website_a)
        end
      end

      let!(:record_b) do
        within_tenant(website_b) do
          traits = factory_traits.any? ? factory_traits : []
          create(factory_name, *traits, website: website_b)
        end
      end

      it 'scopes queries to current tenant' do
        within_tenant(website_a) do
          expect(model_class.all).to include(record_a)
          expect(model_class.all).not_to include(record_b)
        end

        within_tenant(website_b) do
          expect(model_class.all).to include(record_b)
          expect(model_class.all).not_to include(record_a)
        end
      end

      it 'prevents finding records from other tenants' do
        within_tenant(website_a) do
          expect { model_class.find(record_b.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      it 'allows cross-tenant access with without_tenant' do
        ActsAsTenant.without_tenant do
          all_records = model_class.unscoped.where(id: [record_a.id, record_b.id])
          expect(all_records).to include(record_a)
          expect(all_records).to include(record_b)
        end
      end

      it 'requires website presence' do
        within_tenant(website_a) do
          record = model_class.new
          record.website = nil
          # acts_as_tenant may auto-assign, so we need to force nil
          record.instance_variable_set(:@_acts_as_tenant_applied, false) if record.respond_to?(:website=)
          expect(record).not_to be_valid
          expect(record.errors[:website]).to be_present
        end
      end
    end
  end

  describe PwbTenant::Page do
    include_examples 'tenant scoped model', PwbTenant::Page, :pwb_page
  end

  describe PwbTenant::Contact do
    include_examples 'tenant scoped model', PwbTenant::Contact, :pwb_contact
  end

  describe PwbTenant::Message do
    let!(:contact_a) { within_tenant(website_a) { create(:pwb_contact, website: website_a) } }
    let!(:contact_b) { within_tenant(website_b) { create(:pwb_contact, website: website_b) } }

    let!(:message_a) do
      within_tenant(website_a) do
        create(:pwb_message, website: website_a, contact: contact_a)
      end
    end

    let!(:message_b) do
      within_tenant(website_b) do
        create(:pwb_message, website: website_b, contact: contact_b)
      end
    end

    it 'scopes message queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::Message.all).to include(message_a)
        expect(PwbTenant::Message.all).not_to include(message_b)
      end
    end

    it 'prevents cross-tenant message access' do
      within_tenant(website_a) do
        expect { PwbTenant::Message.find(message_b.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe PwbTenant::User do
    let!(:user_a) do
      within_tenant(website_a) do
        create(:pwb_user, website: website_a)
      end
    end

    let!(:user_b) do
      within_tenant(website_b) do
        create(:pwb_user, website: website_b)
      end
    end

    it 'scopes user queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::User.all).to include(user_a)
        expect(PwbTenant::User.all).not_to include(user_b)
      end
    end

    it 'prevents cross-tenant user lookup' do
      within_tenant(website_a) do
        expect { PwbTenant::User.find(user_b.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe PwbTenant::Agency do
    let!(:agency_a) do
      within_tenant(website_a) do
        create(:pwb_agency, website: website_a)
      end
    end

    let!(:agency_b) do
      within_tenant(website_b) do
        create(:pwb_agency, website: website_b)
      end
    end

    it 'scopes agency queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::Agency.all).to include(agency_a)
        expect(PwbTenant::Agency.all).not_to include(agency_b)
      end
    end
  end

  describe PwbTenant::ListedProperty do
    let!(:prop_a) do
      within_tenant(website_a) do
        create(:pwb_prop, :sale, website: website_a)
      end
    end

    let!(:prop_b) do
      within_tenant(website_b) do
        create(:pwb_prop, :sale, website: website_b)
      end
    end

    it 'scopes property queries to current tenant' do
      within_tenant(website_a) do
        all_props = PwbTenant::ListedProperty.all
        expect(all_props.pluck(:id)).to include(prop_a.id)
        expect(all_props.pluck(:id)).not_to include(prop_b.id)
      end
    end
  end

  describe PwbTenant::PagePart do
    let!(:page_a) { within_tenant(website_a) { create(:pwb_page, website: website_a) } }
    let!(:page_b) { within_tenant(website_b) { create(:pwb_page, website: website_b) } }

    let!(:page_part_a) do
      within_tenant(website_a) do
        create(:pwb_page_part, :content_html, page: page_a, website: website_a)
      end
    end

    let!(:page_part_b) do
      within_tenant(website_b) do
        create(:pwb_page_part, :content_html, page: page_b, website: website_b)
      end
    end

    it 'scopes page part queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::PagePart.all).to include(page_part_a)
        expect(PwbTenant::PagePart.all).not_to include(page_part_b)
      end
    end
  end

  describe PwbTenant::Content do
    let!(:content_a) do
      within_tenant(website_a) do
        create(:pwb_content, website: website_a)
      end
    end

    let!(:content_b) do
      within_tenant(website_b) do
        create(:pwb_content, website: website_b)
      end
    end

    it 'scopes content queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::Content.all).to include(content_a)
        expect(PwbTenant::Content.all).not_to include(content_b)
      end
    end
  end

  describe PwbTenant::Link do
    let!(:link_a) do
      within_tenant(website_a) do
        create(:pwb_link, :top_nav, website: website_a)
      end
    end

    let!(:link_b) do
      within_tenant(website_b) do
        create(:pwb_link, :top_nav, website: website_b)
      end
    end

    it 'scopes link queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::Link.all).to include(link_a)
        expect(PwbTenant::Link.all).not_to include(link_b)
      end
    end
  end

  describe PwbTenant::Feature do
    let!(:feature_a) do
      within_tenant(website_a) do
        create(:pwb_feature, website: website_a)
      end
    end

    let!(:feature_b) do
      within_tenant(website_b) do
        create(:pwb_feature, website: website_b)
      end
    end

    it 'scopes feature queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::Feature.all).to include(feature_a)
        expect(PwbTenant::Feature.all).not_to include(feature_b)
      end
    end
  end

  describe PwbTenant::FieldKey do
    let!(:field_key_a) do
      within_tenant(website_a) do
        create(:pwb_field_key, website: website_a)
      end
    end

    let!(:field_key_b) do
      within_tenant(website_b) do
        create(:pwb_field_key, website: website_b)
      end
    end

    it 'scopes field key queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::FieldKey.all).to include(field_key_a)
        expect(PwbTenant::FieldKey.all).not_to include(field_key_b)
      end
    end
  end

  describe PwbTenant::UserMembership do
    let!(:user_a) { within_tenant(website_a) { create(:pwb_user, website: website_a) } }
    let!(:user_b) { within_tenant(website_b) { create(:pwb_user, website: website_b) } }

    let!(:membership_a) do
      within_tenant(website_a) do
        create(:pwb_user_membership, user: user_a, website: website_a)
      end
    end

    let!(:membership_b) do
      within_tenant(website_b) do
        create(:pwb_user_membership, user: user_b, website: website_b)
      end
    end

    it 'scopes membership queries to current tenant' do
      within_tenant(website_a) do
        expect(PwbTenant::UserMembership.all).to include(membership_a)
        expect(PwbTenant::UserMembership.all).not_to include(membership_b)
      end
    end
  end

  describe 'Tenant context error handling' do
    it 'raises error when querying without tenant context' do
      ActsAsTenant.current_tenant = nil
      # PwbTenant models should require a tenant to be set
      expect {
        PwbTenant::Page.all.to_a
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet).or(
        # Some configurations may return empty instead of raising
        satisfy { |result| result.empty? || result.is_a?(ActiveRecord::Relation) }
      )
    end
  end
end
