# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::AgencyController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'agency-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@agency-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/agency/edit' do
    it 'renders the agency edit form' do
      get edit_site_admin_agency_path, headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'displays current agency information' do
      agency.update!(display_name: 'Test Real Estate', email_primary: 'test@agency.com')

      get edit_site_admin_agency_path, headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Test Real Estate')
    end

  end

  describe 'PATCH /site_admin/agency (update)' do
    let(:valid_params) do
      {
        pwb_agency: {
          display_name: 'Updated Agency Name',
          company_name: 'Updated Company LLC',
          email_primary: 'primary@agency.com',
          email_for_general_contact_form: 'contact@agency.com',
          email_for_property_contact_form: 'property@agency.com',
          phone_number_primary: '+31 20 123 4567',
          phone_number_mobile: '+31 6 1234 5678',
          phone_number_other: '+31 20 765 4321',
          url: 'https://www.agency.com',
          skype: 'agency.support'
        }
      }
    end

    it 'updates agency details' do
      patch site_admin_agency_path,
            params: valid_params,
            headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      agency.reload
      expect(agency.display_name).to eq('Updated Agency Name')
      expect(agency.company_name).to eq('Updated Company LLC')
      expect(agency.email_primary).to eq('primary@agency.com')
      expect(agency.phone_number_primary).to eq('+31 20 123 4567')
    end

    it 'updates contact form emails' do
      patch site_admin_agency_path,
            params: valid_params,
            headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      agency.reload
      expect(agency.email_for_general_contact_form).to eq('contact@agency.com')
      expect(agency.email_for_property_contact_form).to eq('property@agency.com')
    end

    it 'updates phone numbers' do
      patch site_admin_agency_path,
            params: valid_params,
            headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      agency.reload
      expect(agency.phone_number_primary).to eq('+31 20 123 4567')
      expect(agency.phone_number_mobile).to eq('+31 6 1234 5678')
      expect(agency.phone_number_other).to eq('+31 20 765 4321')
    end

    it 'updates URL and Skype' do
      patch site_admin_agency_path,
            params: valid_params,
            headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      agency.reload
      expect(agency.url).to eq('https://www.agency.com')
      expect(agency.skype).to eq('agency.support')
    end

    it 'redirects to edit page with success notice' do
      patch site_admin_agency_path,
            params: valid_params,
            headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      expect(response).to redirect_to(edit_site_admin_agency_path)
      expect(flash[:notice]).to include('updated successfully')
    end

    context 'with partial update' do
      it 'updates only specified fields' do
        original_name = agency.display_name

        patch site_admin_agency_path,
              params: { pwb_agency: { email_primary: 'new@email.com' } },
              headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

        agency.reload
        expect(agency.email_primary).to eq('new@email.com')
        expect(agency.display_name).to eq(original_name)
      end
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on edit' do
      get edit_site_admin_agency_path,
          headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on update' do
      patch site_admin_agency_path,
            params: { pwb_agency: { display_name: 'Hack' } },
            headers: { 'HTTP_HOST' => 'agency-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
