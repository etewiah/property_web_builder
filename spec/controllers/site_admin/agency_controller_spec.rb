# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::AgencyController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-agency') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-agency') }
  let(:user) { create(:pwb_user, :admin, website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end

  describe 'GET #edit' do
    context 'when agency exists' do
      before do
        # Create agency directly on the website to ensure proper association
        website.create_agency!(display_name: 'Test Agency', company_name: 'Test Company')
      end

      it 'returns success' do
        get :edit
        expect(response).to have_http_status(:success)
      end

      it 'assigns the existing agency' do
        get :edit
        expect(assigns(:agency)).to eq(website.agency)
      end

      it 'renders the edit template' do
        get :edit
        expect(response).to render_template(:edit)
      end
    end

    context 'when agency does not exist' do
      before do
        # Ensure no agency exists for this website
        website.agency&.destroy
        website.reload
      end

      it 'returns success' do
        get :edit
        expect(response).to have_http_status(:success)
      end

      it 'creates a new agency for the website' do
        expect(website.agency).to be_nil
        get :edit
        website.reload
        expect(website.agency).to be_present
      end

      it 'assigns the newly created agency' do
        get :edit
        expect(assigns(:agency)).to be_persisted
        expect(assigns(:agency).website).to eq(website)
      end
    end
  end

  describe 'PATCH #update' do
    before do
      # Create agency directly on the website
      website.create_agency!(display_name: 'Old Name', company_name: 'Old Company')
    end

    context 'with valid params' do
      let(:valid_params) do
        {
          pwb_agency: {
            display_name: 'New Display Name',
            company_name: 'New Company Ltd',
            email_primary: 'new@company.com',
            phone_number_primary: '+1234567890'
          }
        }
      end

      it 'updates the agency' do
        patch :update, params: valid_params
        website.agency.reload
        expect(website.agency.display_name).to eq('New Display Name')
        expect(website.agency.company_name).to eq('New Company Ltd')
        expect(website.agency.email_primary).to eq('new@company.com')
        expect(website.agency.phone_number_primary).to eq('+1234567890')
      end

      it 'redirects to edit page with success notice' do
        patch :update, params: valid_params
        expect(response).to redirect_to(edit_site_admin_agency_path)
        expect(flash[:notice]).to include('successfully')
      end
    end

    context 'with all permitted params' do
      let(:full_params) do
        {
          pwb_agency: {
            display_name: 'Full Agency',
            company_name: 'Full Company Inc',
            email_primary: 'primary@example.com',
            email_for_general_contact_form: 'general@example.com',
            email_for_property_contact_form: 'property@example.com',
            phone_number_primary: '+1111111111',
            phone_number_mobile: '+2222222222',
            phone_number_other: '+3333333333',
            skype: 'agency.skype',
            url: 'https://www.agency-website.com'
          }
        }
      end

      it 'updates all permitted fields' do
        patch :update, params: full_params
        website.agency.reload

        expect(website.agency.display_name).to eq('Full Agency')
        expect(website.agency.company_name).to eq('Full Company Inc')
        expect(website.agency.email_primary).to eq('primary@example.com')
        expect(website.agency.email_for_general_contact_form).to eq('general@example.com')
        expect(website.agency.email_for_property_contact_form).to eq('property@example.com')
        expect(website.agency.phone_number_primary).to eq('+1111111111')
        expect(website.agency.phone_number_mobile).to eq('+2222222222')
        expect(website.agency.phone_number_other).to eq('+3333333333')
        expect(website.agency.skype).to eq('agency.skype')
        expect(website.agency.url).to eq('https://www.agency-website.com')
      end
    end

    context 'with invalid params' do
      before do
        # Add validation to agency model for testing
        allow_any_instance_of(Pwb::Agency).to receive(:update).and_return(false)
      end

      let(:invalid_params) do
        {
          pwb_agency: {
            display_name: ''
          }
        }
      end

      it 'renders edit template' do
        patch :update, params: invalid_params
        expect(response).to render_template(:edit)
      end

      it 'returns unprocessable_entity status' do
        patch :update, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when agency does not exist' do
      before { website.agency&.destroy }

      it 'creates a new agency and updates it' do
        # First, make sure no agency exists
        website.reload
        params = { pwb_agency: { display_name: 'Brand New Agency' } }

        patch :update, params: params
        website.reload
        expect(website.agency).to be_present
        expect(website.agency.display_name).to eq('Brand New Agency')
      end
    end
  end

  describe 'multi-tenant isolation' do
    before do
      # Create agencies directly on websites
      website.create_agency!(display_name: 'My Agency', company_name: 'My Company')
      other_website.create_agency!(display_name: 'Other Agency', company_name: 'Other Company')
    end

    it 'only shows current website agency' do
      get :edit
      expect(assigns(:agency)).to eq(website.agency)
      expect(assigns(:agency).display_name).to eq('My Agency')
    end

    it 'does not update other website agency' do
      patch :update, params: { pwb_agency: { display_name: 'Updated Name' } }

      expect(website.agency.reload.display_name).to eq('Updated Name')
      expect(other_website.agency.reload.display_name).to eq('Other Agency')
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'denies access to edit' do
        get :edit
        expect(response.status).to eq(302).or eq(403)
      end

      it 'denies access to update' do
        patch :update, params: { pwb_agency: { display_name: 'Test' } }
        expect(response.status).to eq(302).or eq(403)
      end
    end
  end
end
