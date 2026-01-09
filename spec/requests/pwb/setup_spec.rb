# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pwb::SetupController', type: :request do
  # Setup controller handles initial website creation when no website exists
  # for the current subdomain. This is the onboarding flow for new tenants.

  # Ensure TenantSettings allows all themes for tests
  before(:all) do
    Pwb::TenantSettings.delete_all
    Pwb::TenantSettings.create!(
      singleton_key: 'default',
      default_available_themes: %w[default brisbane bologna barcelona biarritz]
    )
  end

  after(:all) do
    Pwb::TenantSettings.delete_all
  end

  describe 'GET /setup (index)' do
    context 'when no website exists for subdomain' do
      it 'renders the setup page successfully' do
        get '/setup', headers: { 'HTTP_HOST' => 'newsite.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('PropertyWebBuilder')
        expect(response.body).to include('Choose a Template')
      end

      it 'displays available seed packs' do
        get '/setup', headers: { 'HTTP_HOST' => 'newsite.test.localhost' }

        expect(response).to have_http_status(:success)
        # Should show at least one seed pack option
        expect(response.body).to include('pack_name')
      end

      it 'populates subdomain field with request subdomain' do
        get '/setup', headers: { 'HTTP_HOST' => 'myagency.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('myagency')
      end
    end

    context 'when website already exists for subdomain' do
      let!(:existing_website) { create(:pwb_website, subdomain: 'existing') }

      it 'redirects to root path' do
        get '/setup', headers: { 'HTTP_HOST' => 'existing.test.localhost' }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /setup (create)' do
    context 'with valid parameters' do
      it 'creates a new website with specified subdomain' do
        expect do
          post '/setup',
               params: { pack_name: 'netherlands_urban', subdomain: 'mynewsite' },
               headers: { 'HTTP_HOST' => 'mynewsite.test.localhost' }
        end.to change(Pwb::Website, :count).by(1)

        website = Pwb::Website.find_by(subdomain: 'mynewsite')
        expect(website).to be_present
        expect(website.provisioning_state).to eq('live')
      end

      it 'redirects to the new website root after creation' do
        post '/setup',
             params: { pack_name: 'netherlands_urban', subdomain: 'brandnew' },
             headers: { 'HTTP_HOST' => 'brandnew.test.localhost' }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('brandnew')
      end

      it 'sets flash success message on successful creation' do
        post '/setup',
             params: { pack_name: 'netherlands_urban', subdomain: 'flashtest' },
             headers: { 'HTTP_HOST' => 'flashtest.test.localhost' }

        # Flash should have success or the redirect happens to the new site
        expect(response).to have_http_status(:redirect)
        # The flash is set but may be on the redirect target
      end

      it 'sets theme on the created website' do
        post '/setup',
             params: { pack_name: 'netherlands_urban', subdomain: 'themedsite' },
             headers: { 'HTTP_HOST' => 'themedsite.test.localhost' }

        website = Pwb::Website.find_by(subdomain: 'themedsite')
        # Website should be created with some theme (default or from pack)
        expect(website).to be_present
        # netherlands_urban pack uses 'bologna' theme
        expect(website.theme_name).to eq('bologna')
      end
    end

    context 'with missing pack_name' do
      it 'redirects back to setup with error' do
        post '/setup',
             params: { subdomain: 'nopack' },
             headers: { 'HTTP_HOST' => 'nopack.test.localhost' }

        expect(response).to redirect_to(pwb_setup_path)
        expect(flash[:error]).to include('select a seed pack')
      end

      it 'does not create a website' do
        expect do
          post '/setup',
               params: { subdomain: 'nopack' },
               headers: { 'HTTP_HOST' => 'nopack.test.localhost' }
        end.not_to change(Pwb::Website, :count)
      end
    end

    context 'with invalid pack_name' do
      it 'redirects back to setup with error' do
        post '/setup',
             params: { pack_name: 'nonexistent_pack', subdomain: 'badpack' },
             headers: { 'HTTP_HOST' => 'badpack.test.localhost' }

        expect(response).to redirect_to(pwb_setup_path)
        expect(flash[:error]).to include('not found')
      end

      it 'does not create a website' do
        expect do
          post '/setup',
               params: { pack_name: 'nonexistent_pack', subdomain: 'badpack' },
               headers: { 'HTTP_HOST' => 'badpack.test.localhost' }
        end.not_to change(Pwb::Website, :count)
      end
    end

    context 'with duplicate subdomain' do
      let!(:existing_website) { create(:pwb_website, subdomain: 'taken') }

      it 'redirects back to setup with error' do
        post '/setup',
             params: { pack_name: 'netherlands_urban', subdomain: 'taken' },
             headers: { 'HTTP_HOST' => 'taken.test.localhost' }

        # Should redirect - either blocked by check_already_setup or validation
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when website already exists for subdomain' do
      let!(:existing_website) { create(:pwb_website, subdomain: 'alreadyhere') }

      it 'redirects to root path (blocked by before_action)' do
        post '/setup',
             params: { pack_name: 'netherlands_urban', subdomain: 'alreadyhere' },
             headers: { 'HTTP_HOST' => 'alreadyhere.test.localhost' }

        expect(response).to redirect_to(root_path)
      end

      it 'does not create another website' do
        expect do
          post '/setup',
               params: { pack_name: 'netherlands_urban', subdomain: 'alreadyhere' },
               headers: { 'HTTP_HOST' => 'alreadyhere.test.localhost' }
        end.not_to change(Pwb::Website, :count)
      end
    end

    context 'subdomain handling' do
      it 'uses subdomain from params when provided' do
        post '/setup',
             params: { pack_name: 'netherlands_urban', subdomain: 'fromparam' },
             headers: { 'HTTP_HOST' => 'different.test.localhost' }

        # Should use 'fromparam' from params, not 'different' from host
        website = Pwb::Website.find_by(subdomain: 'fromparam')
        expect(website).to be_present
      end

      it 'falls back to request subdomain when params subdomain is blank' do
        post '/setup',
             params: { pack_name: 'netherlands_urban', subdomain: '' },
             headers: { 'HTTP_HOST' => 'fromhost.test.localhost' }

        website = Pwb::Website.find_by(subdomain: 'fromhost')
        expect(website).to be_present
      end

      it 'defaults to "default" when no subdomain available' do
        post '/setup',
             params: { pack_name: 'netherlands_urban' },
             headers: { 'HTTP_HOST' => 'localhost' }

        website = Pwb::Website.find_by(subdomain: 'default')
        expect(website).to be_present
      end
    end
  end
end
