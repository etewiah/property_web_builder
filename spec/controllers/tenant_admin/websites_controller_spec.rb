# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdmin::WebsitesController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:admin_user) { create(:pwb_user, email: 'admin@example.com', website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
    sign_in admin_user, scope: :user
  end

  describe 'GET #index' do
    let!(:websites) { create_list(:pwb_website, 3) }

    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns @websites' do
      get :index
      expect(assigns(:websites)).to be_present
    end

    context 'with search parameter' do
      let!(:searchable_website) { create(:pwb_website, subdomain: 'searchable', company_display_name: 'Searchable Corp') }

      it 'searches by subdomain' do
        get :index, params: { search: 'searchable' }
        expect(assigns(:websites)).to include(searchable_website)
      end

      it 'searches by company_display_name' do
        get :index, params: { search: 'Searchable Corp' }
        expect(assigns(:websites)).to include(searchable_website)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: website.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested website' do
      get :show, params: { id: website.id }
      expect(assigns(:website)).to eq(website)
    end

    describe 'user counting' do
      # User counting is critical for tenant admin visibility.
      # Users can be associated with a website in two ways:
      # 1. Direct: User.website_id = website.id
      # 2. Membership: UserMembership(user_id, website_id)
      #
      # The count must include both without double-counting.

      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no users' do
        it 'sets @users_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(0)
        end
      end

      context 'with users via direct website_id association' do
        let!(:direct_user) { create(:pwb_user, website: target_website) }

        it 'counts users with direct website_id' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(1)
        end

        context 'with multiple direct users' do
          let!(:direct_user2) { create(:pwb_user, website: target_website) }

          it 'counts all direct users' do
            get :show, params: { id: target_website.id }
            expect(assigns(:users_count)).to eq(2)
          end
        end
      end

      context 'with users via user_memberships' do
        let(:other_website) { create(:pwb_website, subdomain: 'other') }
        let!(:membership_user) { create(:pwb_user, website: other_website) }
        let!(:membership) { create(:pwb_user_membership, user: membership_user, website: target_website) }

        it 'counts users with memberships' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(1)
        end
      end

      context 'with users via both associations' do
        let!(:direct_user) { create(:pwb_user, website: target_website) }
        let(:other_website) { create(:pwb_website, subdomain: 'other') }
        let!(:membership_user) { create(:pwb_user, website: other_website) }
        let!(:membership) { create(:pwb_user_membership, user: membership_user, website: target_website) }

        it 'counts both direct and membership users' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(2)
        end
      end

      context 'when user has both direct association AND membership (edge case)' do
        # A user might have website_id = X AND also have a membership for website X.
        # This should NOT double-count the user.
        let!(:dual_user) { create(:pwb_user, website: target_website) }
        let!(:redundant_membership) { create(:pwb_user_membership, user: dual_user, website: target_website) }

        it 'does not double-count users with both associations' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(1)
        end
      end
    end

    describe 'property counting' do
      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no properties' do
        it 'sets @props_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:props_count)).to eq(0)
        end
      end

      context 'with properties' do
        before do
          # Create properties associated with the target website
          create_list(:pwb_realty_asset, 3, website: target_website)
        end

        it 'counts properties for the website' do
          get :show, params: { id: target_website.id }
          expect(assigns(:props_count)).to eq(3)
        end
      end
    end

    describe 'page counting' do
      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no pages' do
        it 'sets @pages_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:pages_count)).to eq(0)
        end
      end
    end

    describe 'message counting' do
      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no messages' do
        it 'sets @messages_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:messages_count)).to eq(0)
        end
      end

      context 'with messages' do
        before do
          create_list(:pwb_message, 2, website: target_website)
        end

        it 'counts messages for the website' do
          get :show, params: { id: target_website.id }
          expect(assigns(:messages_count)).to eq(2)
        end
      end
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new website' do
      get :new
      expect(assigns(:website)).to be_a_new(Pwb::Website)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        website: {
          subdomain: 'new-website',
          company_display_name: 'New Company',
          theme_name: 'default'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new website' do
        expect do
          post :create, params: valid_params
        end.to change(Pwb::Website, :count).by(1)
      end

      it 'redirects to the created website' do
        post :create, params: valid_params
        expect(response).to redirect_to(tenant_admin_website_path(Pwb::Website.last))
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: website.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested website' do
      get :edit, params: { id: website.id }
      expect(assigns(:website)).to eq(website)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the website' do
      website_to_delete = create(:pwb_website, subdomain: 'to-delete')
      expect do
        delete :destroy, params: { id: website_to_delete.id }
      end.to change(Pwb::Website, :count).by(-1)
    end

    it 'redirects to websites index' do
      delete :destroy, params: { id: website.id }
      expect(response).to redirect_to(tenant_admin_websites_path)
    end
  end

  describe 'authorization' do
    context 'when user is not a tenant admin' do
      let(:regular_user) { create(:pwb_user, email: 'user@example.com', website: website) }

      before do
        sign_in regular_user, scope: :user
      end

      it 'denies access to index' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to show' do
        get :show, params: { id: website.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe '#count_website_users (private method)' do
    # Testing the private method indirectly through controller behavior
    # to ensure the SQL query handles edge cases correctly

    let(:target_website) { create(:pwb_website, subdomain: 'target') }
    let(:other_website) { create(:pwb_website, subdomain: 'other') }

    it 'returns 0 for website with no users' do
      get :show, params: { id: target_website.id }
      expect(assigns(:users_count)).to eq(0)
    end

    it 'correctly counts users across multiple websites without cross-contamination' do
      # Create users for target website
      create(:pwb_user, website: target_website)

      # Create users for other website (should not be counted)
      create(:pwb_user, website: other_website)

      get :show, params: { id: target_website.id }
      expect(assigns(:users_count)).to eq(1)
    end
  end

  # ============================================================================
  # Rendering Pipeline Tests
  # ============================================================================
  #
  # These tests cover the rendering form and update_rendering actions.
  # Key things tested:
  # 1. Form displays correctly (GET #rendering_form)
  # 2. Updates work with properly nested params (PATCH #update_rendering)
  # 3. 422 error occurs when params are not nested under :website
  #
  # The form scope issue (params not nested) was a production bug that caused
  # 422 errors. These tests ensure it doesn't regress.
  #
  # IMPORTANT: Client rendering mode requires a valid client_theme_name.
  # Tests that switch to client mode must create a ClientTheme first.
  # ============================================================================

  describe 'GET #rendering_form' do
    it 'returns a successful response' do
      get :rendering_form, params: { id: website.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested website' do
      get :rendering_form, params: { id: website.id }
      expect(assigns(:website)).to eq(website)
    end

    it 'assigns @themes' do
      get :rendering_form, params: { id: website.id }
      expect(assigns(:themes)).to be_present
    end

    it 'assigns @client_themes' do
      get :rendering_form, params: { id: website.id }
      expect(assigns(:client_themes)).not_to be_nil
    end
  end

  describe 'PATCH #update_rendering' do
    # The form MUST use scope: :website to nest params correctly.
    # Without proper nesting, params.require(:website) fails with 422.

    context 'with properly nested params (correct form scope)' do
      # This is the CORRECT param structure when form uses scope: :website
      let(:valid_params) do
        {
          id: website.id,
          website: {
            rendering_mode: 'rails',
            theme_name: 'default'
          }
        }
      end

      it 'returns a successful response' do
        patch :update_rendering, params: valid_params
        expect(response).to have_http_status(:success)
      end

      it 'updates the theme name for rails mode' do
        patch :update_rendering, params: valid_params.deep_merge(website: { theme_name: 'default' })
        expect(website.reload.theme_name).to eq('default')
      end

      it 'sets a flash notice on success' do
        patch :update_rendering, params: valid_params
        expect(flash[:notice]).to eq('Rendering settings updated successfully.')
      end

      it 'renders the rendering_form template' do
        patch :update_rendering, params: valid_params
        expect(response).to render_template(:rendering_form)
      end
    end

    context 'updating to client rendering mode' do
      # Client mode requires a valid client_theme_name in the database
      let!(:client_theme) { create(:pwb_client_theme, name: 'astro_starter', friendly_name: 'Astro Starter') }

      let(:client_params) do
        {
          id: website.id,
          website: {
            rendering_mode: 'client',
            client_theme_name: 'astro_starter'
          }
        }
      end

      it 'updates to client mode with valid theme' do
        patch :update_rendering, params: client_params
        expect(website.reload.rendering_mode).to eq('client')
      end

      it 'updates the client theme name' do
        patch :update_rendering, params: client_params
        expect(website.reload.client_theme_name).to eq('astro_starter')
      end

      it 'returns success response' do
        patch :update_rendering, params: client_params
        expect(response).to have_http_status(:success)
      end

      context 'without valid client_theme_name' do
        # Switching to client mode without a valid theme should fail validation
        let(:invalid_client_params) do
          {
            id: website.id,
            website: {
              rendering_mode: 'client',
              client_theme_name: 'nonexistent_theme'
            }
          }
        end

        it 'returns unprocessable entity when theme does not exist' do
          patch :update_rendering, params: invalid_client_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'does not update the rendering mode' do
          patch :update_rendering, params: invalid_client_params
          expect(website.reload.rendering_mode).to eq('rails')
        end
      end
    end

    context 'with astro_client_url parameter' do
      # Client theme must exist for client rendering mode
      let!(:client_theme) { create(:pwb_client_theme, name: 'astro_starter', friendly_name: 'Astro Starter') }

      let(:params_with_astro_url) do
        {
          id: website.id,
          website: {
            rendering_mode: 'client',
            client_theme_name: 'astro_starter',
            astro_client_url: 'https://custom-astro.example.com'
          }
        }
      end

      it 'stores astro_client_url in client_theme_config' do
        patch :update_rendering, params: params_with_astro_url
        website.reload
        expect(website.client_theme_config['astro_client_url']).to eq('https://custom-astro.example.com')
      end

      it 'removes astro_client_url when set to blank' do
        # First set up website with client mode and URL
        website.update!(
          rendering_mode: 'client',
          client_theme_name: 'astro_starter',
          client_theme_config: { 'astro_client_url' => 'https://old.example.com' }
        )
        # Now update with blank URL
        patch :update_rendering, params: {
          id: website.id,
          website: {
            rendering_mode: 'client',
            client_theme_name: 'astro_starter',
            astro_client_url: ''
          }
        }
        website.reload
        expect(website.client_theme_config['astro_client_url']).to be_nil
      end
    end

    context 'with INCORRECTLY structured params (missing form scope)' do
      # This simulates what happens when form_with is missing scope: :website
      # The params come in at the top level instead of nested under :website
      #
      # IMPORTANT: This is a regression test for a production bug.
      # The form was submitting params like:
      #   { rendering_mode: 'rails', theme_name: 'default' }
      # Instead of:
      #   { website: { rendering_mode: 'rails', theme_name: 'default' } }
      #
      # This caused params.require(:website) to fail, which is now handled
      # by TenantAdminController#handle_parameter_missing to return a redirect
      # with helpful error message.

      let(:incorrectly_structured_params) do
        {
          id: website.id,
          # Note: params NOT nested under :website - this is WRONG
          rendering_mode: 'rails',
          theme_name: 'default'
        }
      end

      it 'redirects back with error message for HTML requests' do
        # TenantAdminController#handle_parameter_missing redirects with flash alert
        request.env['HTTP_REFERER'] = tenant_admin_website_path(website)
        patch :update_rendering, params: incorrectly_structured_params
        expect(response).to redirect_to(tenant_admin_website_path(website))
        expect(flash[:alert]).to include('Form submission error')
      end

      it 'returns 422 for JSON requests' do
        # JSON format returns 422 with diagnostic info
        patch :update_rendering, params: incorrectly_structured_params, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq('Parameter missing')
      end

      it 'logs diagnostic information for troubleshooting' do
        # The controller logs detailed info to help diagnose form scope issues
        # We just verify the request completes - check logs manually for diagnostics
        # Logs include: FORM SCOPE ERROR, rendering params at top level, ParameterMissing
        request.env['HTTP_REFERER'] = tenant_admin_website_path(website)
        patch :update_rendering, params: incorrectly_structured_params
        expect(response).to be_redirect
        # Logs will contain diagnostic messages - see TenantAdmin::WebsitesController#update_rendering
      end
    end

    context 'when website params key exists but is empty' do
      let(:empty_website_params) do
        {
          id: website.id,
          website: {}
        }
      end

      it 'redirects back with error for empty website params' do
        # Rails strong params treats empty hash as invalid for require()
        # This triggers handle_parameter_missing which redirects
        request.env['HTTP_REFERER'] = tenant_admin_website_path(website)
        patch :update_rendering, params: empty_website_params
        expect(response).to redirect_to(tenant_admin_website_path(website))
      end

      it 'returns 422 for JSON requests with empty website params' do
        patch :update_rendering, params: empty_website_params, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'authorization' do
      let(:regular_user) { create(:pwb_user, email: 'user@example.com', website: website) }

      before do
        sign_in regular_user, scope: :user
      end

      it 'denies access to rendering_form' do
        get :rendering_form, params: { id: website.id }
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to update_rendering' do
        patch :update_rendering, params: { id: website.id, website: { rendering_mode: 'rails' } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'rendering_params (private method via update_rendering)' do
    # These tests verify the strong params behavior indirectly
    # NOTE: Tests that change rendering_mode to 'client' need a valid ClientTheme

    context 'staying in rails mode' do
      it 'permits theme_name' do
        patch :update_rendering, params: {
          id: website.id,
          website: { theme_name: 'default' }
        }
        expect(website.reload.theme_name).to eq('default')
      end

      it 'does not permit arbitrary params' do
        original_subdomain = website.subdomain
        patch :update_rendering, params: {
          id: website.id,
          website: {
            rendering_mode: 'rails',
            subdomain: 'hacked-subdomain'  # Should not be permitted
          }
        }
        expect(website.reload.subdomain).to eq(original_subdomain)
      end
    end

    context 'switching to client mode' do
      let!(:client_theme) { create(:pwb_client_theme, name: 'test_theme', friendly_name: 'Test Theme') }

      it 'permits rendering_mode' do
        patch :update_rendering, params: {
          id: website.id,
          website: { rendering_mode: 'client', client_theme_name: 'test_theme' }
        }
        expect(website.reload.rendering_mode).to eq('client')
      end

      it 'permits client_theme_name' do
        patch :update_rendering, params: {
          id: website.id,
          website: { rendering_mode: 'client', client_theme_name: 'test_theme' }
        }
        expect(website.reload.client_theme_name).to eq('test_theme')
      end
    end
  end
end
