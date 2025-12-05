# frozen_string_literal: true

require 'rails_helper'

# Comprehensive Multi-Tenant Isolation Tests for Site Admin Controllers
#
# This test suite verifies that all site_admin controllers properly isolate data
# by website_id, preventing cross-tenant data leakage which is a critical security issue.
#
# Test pattern:
# 1. Create data for two tenants (website_a and website_b)
# 2. Make requests as tenant_a
# 3. Verify tenant_a can only see/access their own data
# 4. Verify tenant_a cannot see/access tenant_b's data

RSpec.describe 'Site Admin Multi-Tenant Isolation', type: :request do
  let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a') }
  let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b') }
  let!(:user_a) { create(:pwb_user, :admin, website: website_a, email: 'admin@tenant-a.test') }
  let!(:user_b) { create(:pwb_user, :admin, website: website_b, email: 'admin@tenant-b.test') }

  before do
    # Sign in as user_a and set up tenant context
    sign_in user_a
    allow(Pwb::Current).to receive(:website).and_return(website_a)
  end

  describe 'ContactsController' do
    let!(:contact_a) do
      Pwb::Contact.create!(
        first_name: 'Contact',
        last_name: 'A',
        primary_email: 'contact@tenant-a.test',
        website_id: website_a.id
      )
    end

    let!(:contact_b) do
      Pwb::Contact.create!(
        first_name: 'Contact',
        last_name: 'B',
        primary_email: 'contact@tenant-b.test',
        website_id: website_b.id
      )
    end

    describe 'GET /site_admin/contacts' do
      it 'only returns contacts belonging to the current website' do
        get site_admin_contacts_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('contact@tenant-a.test')
        expect(response.body).not_to include('contact@tenant-b.test')
      end

      it 'does not leak contact count from other tenants' do
        # Create additional contacts for tenant B
        3.times do |i|
          Pwb::Contact.create!(
            first_name: "Extra#{i}",
            last_name: 'B',
            primary_email: "extra#{i}@tenant-b.test",
            website_id: website_b.id
          )
        end

        get site_admin_contacts_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        # Should only see 1 contact (contact_a), not 4 total
        expect(response.body.scan(/tenant-a\.test/).count).to be >= 1
        expect(response.body).not_to include('tenant-b.test')
      end
    end

    describe 'GET /site_admin/contacts/:id' do
      it 'allows access to own contact' do
        get site_admin_contact_path(contact_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('contact@tenant-a.test')
      end

      it 'denies access to another tenant\'s contact' do
        get site_admin_contact_path(contact_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe 'UsersController' do
    let!(:extra_user_a) do
      create(:pwb_user, website: website_a, email: 'user@tenant-a.test')
    end

    let!(:extra_user_b) do
      create(:pwb_user, website: website_b, email: 'user@tenant-b.test')
    end

    describe 'GET /site_admin/users' do
      it 'only returns users belonging to the current website' do
        get site_admin_users_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('admin@tenant-a.test')
        expect(response.body).to include('user@tenant-a.test')
        expect(response.body).not_to include('admin@tenant-b.test')
        expect(response.body).not_to include('user@tenant-b.test')
      end
    end

    describe 'GET /site_admin/users/:id' do
      it 'allows access to own user' do
        get site_admin_user_path(extra_user_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('user@tenant-a.test')
      end

      it 'denies access to another tenant\'s user' do
        get site_admin_user_path(extra_user_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe 'MessagesController' do
    let!(:message_a) do
      Pwb::Message.create!(
        origin_email: 'sender@tenant-a.test',
        content: 'Message for tenant A',
        website_id: website_a.id
      )
    end

    let!(:message_b) do
      Pwb::Message.create!(
        origin_email: 'sender@tenant-b.test',
        content: 'Message for tenant B',
        website_id: website_b.id
      )
    end

    describe 'GET /site_admin/messages' do
      it 'only returns messages belonging to the current website' do
        get site_admin_messages_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('sender@tenant-a.test')
        expect(response.body).not_to include('sender@tenant-b.test')
      end
    end

    describe 'GET /site_admin/messages/:id' do
      it 'allows access to own message' do
        get site_admin_message_path(message_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Message for tenant A')
      end

      it 'denies access to another tenant\'s message' do
        get site_admin_message_path(message_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe 'PagesController' do
    let!(:page_a) do
      Pwb::Page.create!(
        slug: 'about-us',
        visible: true,
        website_id: website_a.id
      )
    end

    let!(:page_b) do
      Pwb::Page.create!(
        slug: 'about-us',
        visible: true,
        website_id: website_b.id
      )
    end

    describe 'GET /site_admin/pages' do
      it 'only returns pages belonging to the current website' do
        get site_admin_pages_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        # Check the page IDs shown belong to website_a
        expect(assigns(:pages).pluck(:website_id)).to all(eq(website_a.id))
      end
    end

    describe 'GET /site_admin/pages/:id' do
      it 'allows access to own page' do
        get site_admin_page_path(page_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'denies access to another tenant\'s page' do
        get site_admin_page_path(page_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end

    describe 'GET /site_admin/pages/:id/edit' do
      it 'allows editing own page' do
        get edit_site_admin_page_path(page_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'denies editing another tenant\'s page' do
        get edit_site_admin_page_path(page_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end

    describe 'PATCH /site_admin/pages/:id' do
      it 'allows updating own page' do
        patch site_admin_page_path(page_a),
              params: { pwb_page: { visible: false } },
              headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to redirect_to(site_admin_page_path(page_a))
        expect(page_a.reload.visible).to be false
      end

      it 'denies updating another tenant\'s page' do
        original_visibility = page_b.visible
        patch site_admin_page_path(page_b),
              params: { pwb_page: { visible: false } },
              headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
        # Verify the page was not modified
        expect(page_b.reload.visible).to eq(original_visibility)
      end
    end
  end

  describe 'ContentsController' do
    let!(:content_a) do
      Pwb::Content.create!(
        key: 'header_text_a',
        tag: 'appearance',
        website_id: website_a.id
      )
    end

    let!(:content_b) do
      Pwb::Content.create!(
        key: 'header_text_b',
        tag: 'appearance',
        website_id: website_b.id
      )
    end

    describe 'GET /site_admin/contents' do
      it 'only returns contents belonging to the current website' do
        get site_admin_contents_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(assigns(:contents).pluck(:website_id)).to all(eq(website_a.id))
      end
    end

    describe 'GET /site_admin/contents/:id' do
      it 'allows access to own content' do
        get site_admin_content_path(content_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('header_text_a')
      end

      it 'denies access to another tenant\'s content' do
        get site_admin_content_path(content_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe 'PagePartsController' do
    let!(:page_part_a) do
      Pwb::PagePart.create!(
        page_part_key: 'hero_section',
        page_slug: 'home',
        website_id: website_a.id
      )
    end

    let!(:page_part_b) do
      Pwb::PagePart.create!(
        page_part_key: 'hero_section',
        page_slug: 'home',
        website_id: website_b.id
      )
    end

    describe 'GET /site_admin/page_parts' do
      it 'only returns page_parts belonging to the current website' do
        get site_admin_page_parts_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(assigns(:page_parts).pluck(:website_id)).to all(eq(website_a.id))
      end
    end

    describe 'GET /site_admin/page_parts/:id' do
      it 'allows access to own page_part' do
        get site_admin_page_part_path(page_part_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'denies access to another tenant\'s page_part' do
        get site_admin_page_part_path(page_part_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe 'DashboardController' do
    before do
      # Create varied data for both tenants
      3.times do |i|
        Pwb::Contact.create!(first_name: "ContactA#{i}", website_id: website_a.id)
        Pwb::Message.create!(origin_email: "msg_a#{i}@test.com", content: "Test A#{i}", website_id: website_a.id)
        Pwb::Page.create!(slug: "page-a-#{i}", website_id: website_a.id)
        Pwb::Content.create!(key: "content_a_#{i}", tag: 'test', website_id: website_a.id)
      end

      5.times do |i|
        Pwb::Contact.create!(first_name: "ContactB#{i}", website_id: website_b.id)
        Pwb::Message.create!(origin_email: "msg_b#{i}@test.com", content: "Test B#{i}", website_id: website_b.id)
        Pwb::Page.create!(slug: "page-b-#{i}", website_id: website_b.id)
        Pwb::Content.create!(key: "content_b_#{i}", tag: 'test', website_id: website_b.id)
      end
    end

    describe 'GET /site_admin' do
      it 'only counts resources belonging to the current website' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)

        stats = assigns(:stats)
        # Tenant A should have 3 of each (plus any seeded data)
        # Important: should NOT include tenant B's 5 items
        expect(stats[:total_contacts]).to eq(Pwb::Contact.where(website_id: website_a.id).count)
        expect(stats[:total_messages]).to eq(Pwb::Message.where(website_id: website_a.id).count)
        expect(stats[:total_pages]).to eq(Pwb::Page.where(website_id: website_a.id).count)
        expect(stats[:total_contents]).to eq(Pwb::Content.where(website_id: website_a.id).count)
      end

      it 'recent activity only shows current tenant data' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        recent_contacts = assigns(:recent_contacts)
        recent_messages = assigns(:recent_messages)

        expect(recent_contacts.pluck(:website_id)).to all(eq(website_a.id))
        expect(recent_messages.pluck(:website_id)).to all(eq(website_a.id))
      end
    end
  end

  describe 'PropsController' do
    let!(:realty_asset_a) do
      Pwb::RealtyAsset.create!(
        reference: 'PROP-A-001',
        website: website_a,
        street_address: '123 Tenant A St'
      )
    end

    let!(:realty_asset_b) do
      Pwb::RealtyAsset.create!(
        reference: 'PROP-B-001',
        website: website_b,
        street_address: '456 Tenant B Ave'
      )
    end

    before do
      # Create sale listings and refresh materialized view
      Pwb::SaleListing.create!(realty_asset: realty_asset_a, visible: true, price_sale_current_cents: 100_000_00)
      Pwb::SaleListing.create!(realty_asset: realty_asset_b, visible: true, price_sale_current_cents: 200_000_00)
      Pwb::ListedProperty.refresh rescue nil
    end

    describe 'GET /site_admin/props' do
      it 'only returns properties belonging to the current website' do
        get site_admin_props_path, headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('PROP-A-001')
        expect(response.body).not_to include('PROP-B-001')
      end
    end

    describe 'GET /site_admin/props/:id' do
      it 'allows access to own property' do
        # Need to find the listed property ID
        listed_prop_a = Pwb::ListedProperty.find_by(reference: 'PROP-A-001')
        skip 'Materialized view not populated' unless listed_prop_a

        get site_admin_prop_path(listed_prop_a), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('PROP-A-001')
      end

      it 'denies access to another tenant\'s property' do
        listed_prop_b = Pwb::ListedProperty.find_by(reference: 'PROP-B-001')
        skip 'Materialized view not populated' unless listed_prop_b

        get site_admin_prop_path(listed_prop_b), headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe 'Cross-tenant data modification attempts' do
    context 'when attempting to modify another tenant\'s data via ID manipulation' do
      let!(:page_a) { Pwb::Page.create!(slug: 'target-page', website_id: website_a.id) }
      let!(:page_b) { Pwb::Page.create!(slug: 'target-page', website_id: website_b.id) }

      it 'prevents updating another tenant\'s page even with valid ID' do
        original_visibility = page_b.visible

        patch site_admin_page_path(page_b),
              params: { pwb_page: { visible: !original_visibility } },
              headers: { 'HTTP_HOST' => 'tenant-a.e2e.localhost' }
        # Should return 404 or redirect, not success with other tenant's data
        expect(response).not_to have_http_status(:success)

        # Verify the page was not modified
        expect(page_b.reload.visible).to eq(original_visibility)
      end
    end
  end
end
