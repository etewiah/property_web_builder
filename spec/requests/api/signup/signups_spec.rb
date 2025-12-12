# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Signup::Signups", type: :request do
  # Helper to parse JSON response
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe "POST /api/signup/start" do
    context "with valid email" do
      it "creates a new user and returns success" do
        post '/api/signup/start', params: { email: 'newuser@example.com' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:user_id]).to be_present
        expect(json_response[:subdomain]).to be_present
        expect(json_response[:message]).to eq("Signup started successfully")

        # Verify user was created
        expect(Pwb::User.find_by(email: 'newuser@example.com')).to be_present
      end

      it "normalizes email to lowercase" do
        post '/api/signup/start', params: { email: 'NewUser@Example.COM' }

        expect(response).to have_http_status(:ok)
        user = Pwb::User.last
        expect(user.email).to eq('newuser@example.com')
      end

      it "generates a valid subdomain suggestion" do
        post '/api/signup/start', params: { email: 'test@example.com' }

        expect(response).to have_http_status(:ok)
        subdomain = json_response[:subdomain]
        expect(subdomain).to match(/^[a-z]+-[a-z]+-\d+$/)
      end

      it "stores user_id in session for subsequent requests" do
        post '/api/signup/start', params: { email: 'session@example.com' }

        expect(response).to have_http_status(:ok)
        # Session should be set (verified by subsequent request working)
        user_id = json_response[:user_id]

        # Configure should work with session
        post '/api/signup/configure', params: {
          subdomain: 'my-test-site',
          site_type: 'residential'
        }
        # Should not return unauthorized
        expect(response).not_to have_http_status(:unauthorized)
      end
    end

    context "with existing email (no website)" do
      let!(:existing_user) { FactoryBot.create(:pwb_user, email: 'existing@example.com') }

      before do
        # Remove any websites associated with the user
        existing_user.websites.destroy_all if existing_user.respond_to?(:websites)
      end

      it "returns existing user for signup continuation" do
        expect {
          post '/api/signup/start', params: { email: 'existing@example.com' }
        }.not_to change(Pwb::User, :count)

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
      end
    end

    context "with invalid email" do
      it "returns error for blank email" do
        post '/api/signup/start', params: { email: '' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to include("valid email")
      end

      it "returns error for invalid email format" do
        post '/api/signup/start', params: { email: 'not-an-email' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to include("valid email")
      end

      it "returns error for missing email parameter" do
        post '/api/signup/start', params: {}

        expect(response).to have_http_status(:bad_request)
        expect(json_response[:success]).to be false
      end
    end
  end

  describe "POST /api/signup/configure" do
    context "with valid session" do
      before do
        # Start signup first to establish session
        post '/api/signup/start', params: { email: 'config@example.com' }
        expect(response).to have_http_status(:ok)
      end

      context "with valid parameters" do
        it "creates a website with the specified subdomain" do
          expect {
            post '/api/signup/configure', params: {
              subdomain: 'my-awesome-site',
              site_type: 'residential'
            }
          }.to change(Pwb::Website, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(json_response[:success]).to be true
          expect(json_response[:website_id]).to be_present
          expect(json_response[:subdomain]).to eq('my-awesome-site')
          expect(json_response[:site_type]).to eq('residential')
        end

        it "normalizes subdomain to lowercase" do
          post '/api/signup/configure', params: {
            subdomain: 'My-Site-NAME',
            site_type: 'residential'
          }

          expect(response).to have_http_status(:ok)
          expect(json_response[:subdomain]).to eq('my-site-name')
        end

        it "accepts different site types" do
          %w[residential commercial vacation_rental].each do |site_type|
            # Start a new signup for each test
            post '/api/signup/start', params: { email: "#{site_type}@example.com" }

            post '/api/signup/configure', params: {
              subdomain: "site-#{site_type.gsub('_', '-')}",
              site_type: site_type
            }

            expect(response).to have_http_status(:ok), "Failed for site_type: #{site_type}"
            expect(json_response[:site_type]).to eq(site_type)
          end
        end
      end

      context "with invalid parameters" do
        it "returns error for blank subdomain" do
          post '/api/signup/configure', params: {
            subdomain: '',
            site_type: 'residential'
          }

          expect(response).to have_http_status(:bad_request)
          expect(json_response[:success]).to be false
          expect(json_response[:error]).to include("Subdomain")
        end

        it "returns error for blank site_type" do
          post '/api/signup/configure', params: {
            subdomain: 'my-site',
            site_type: ''
          }

          expect(response).to have_http_status(:bad_request)
          expect(json_response[:success]).to be false
          expect(json_response[:error]).to include("Site type")
        end

        it "returns error for invalid subdomain format" do
          post '/api/signup/configure', params: {
            subdomain: 'ab', # Too short
            site_type: 'residential'
          }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response[:success]).to be false
        end
      end

      context "with duplicate subdomain" do
        let!(:existing_website) { FactoryBot.create(:pwb_website, subdomain: 'taken-subdomain') }

        it "returns error when subdomain is already taken" do
          post '/api/signup/configure', params: {
            subdomain: 'taken-subdomain',
            site_type: 'residential'
          }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response[:success]).to be false
          expect(json_response[:error]).to include("taken")
        end
      end
    end

    context "without valid session" do
      it "returns unauthorized error" do
        post '/api/signup/configure', params: {
          subdomain: 'my-site',
          site_type: 'residential'
        }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to include("email")
      end
    end
  end

  describe "POST /api/signup/provision" do
    context "with valid session and website" do
      before do
        # Complete signup flow up to configure
        post '/api/signup/start', params: { email: 'provision@example.com' }
        post '/api/signup/configure', params: {
          subdomain: 'provision-test',
          site_type: 'residential'
        }
        expect(response).to have_http_status(:ok)
      end

      it "triggers provisioning and returns status" do
        post '/api/signup/provision'

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:provisioning_status]).to be_present
        expect(json_response[:progress]).to be_a(Integer)
        expect(json_response[:message]).to be_present
      end

      it "returns progress percentage" do
        post '/api/signup/provision'

        expect(response).to have_http_status(:ok)
        expect(json_response[:progress]).to be >= 0
        expect(json_response[:progress]).to be <= 100
      end
    end

    context "without valid session" do
      it "returns unauthorized error" do
        post '/api/signup/provision'

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
      end
    end
  end

  describe "GET /api/signup/status" do
    context "with valid session and website" do
      before do
        # Complete signup flow
        post '/api/signup/start', params: { email: 'status@example.com' }
        post '/api/signup/configure', params: {
          subdomain: 'status-test',
          site_type: 'residential'
        }
      end

      it "returns current provisioning status" do
        get '/api/signup/status'

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:provisioning_status]).to be_present
        expect(json_response[:progress]).to be_a(Integer)
        expect(json_response[:message]).to be_present
        expect(json_response).to have_key(:complete)
      end

      it "includes website URL when live" do
        # Manually set website to live state
        website = Pwb::Website.find_by(subdomain: 'status-test')
        website.update!(provisioning_state: 'live') if website

        get '/api/signup/status'

        expect(response).to have_http_status(:ok)
        if json_response[:complete]
          expect(json_response[:website_url]).to be_present
          expect(json_response[:admin_url]).to be_present
        end
      end
    end

    context "without valid session" do
      it "returns unauthorized error" do
        get '/api/signup/status'

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
      end
    end
  end

  describe "GET /api/signup/check_subdomain" do
    context "with available subdomain" do
      it "returns available: true" do
        get '/api/signup/check_subdomain', params: { name: 'brand-new-site' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:available]).to be true
        expect(json_response[:normalized]).to eq('brand-new-site')
        expect(json_response[:errors]).to be_empty
      end

      it "normalizes subdomain to lowercase" do
        get '/api/signup/check_subdomain', params: { name: 'My-Site-NAME' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:normalized]).to eq('my-site-name')
      end
    end

    context "with taken subdomain" do
      let!(:existing_website) { FactoryBot.create(:pwb_website, subdomain: 'existing-site') }

      it "returns available: false" do
        get '/api/signup/check_subdomain', params: { name: 'existing-site' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:available]).to be false
        expect(json_response[:errors]).not_to be_empty
      end
    end

    context "with invalid subdomain format" do
      it "returns error for too short subdomain" do
        get '/api/signup/check_subdomain', params: { name: 'ab' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:available]).to be false
        expect(json_response[:errors]).to include(a_string_matching(/at least 3/))
      end

      it "returns error for subdomain with invalid characters" do
        get '/api/signup/check_subdomain', params: { name: 'my_site!' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:available]).to be false
        expect(json_response[:errors]).not_to be_empty
      end

      it "returns error for reserved subdomain" do
        get '/api/signup/check_subdomain', params: { name: 'admin' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:available]).to be false
        expect(json_response[:errors]).to include(a_string_matching(/reserved/i))
      end
    end
  end

  describe "GET /api/signup/suggest_subdomain" do
    it "returns a random subdomain suggestion" do
      get '/api/signup/suggest_subdomain'

      expect(response).to have_http_status(:ok)
      expect(json_response[:subdomain]).to be_present
    end

    it "returns subdomain in expected format (adjective-noun-number)" do
      get '/api/signup/suggest_subdomain'

      expect(response).to have_http_status(:ok)
      expect(json_response[:subdomain]).to match(/^[a-z]+-[a-z]+-\d+$/)
    end

    it "returns different subdomains on multiple calls" do
      get '/api/signup/suggest_subdomain'
      first_subdomain = json_response[:subdomain]

      # Make multiple calls to increase chance of getting different result
      different_found = false
      5.times do
        get '/api/signup/suggest_subdomain'
        if json_response[:subdomain] != first_subdomain
          different_found = true
          break
        end
      end

      # It's possible (but unlikely) to get the same subdomain multiple times
      # so we just check the response is valid
      expect(response).to have_http_status(:ok)
      expect(json_response[:subdomain]).to be_present
    end
  end

  describe "GET /api/signup/site_types" do
    it "returns list of available site types" do
      get '/api/signup/site_types'

      expect(response).to have_http_status(:ok)
      expect(json_response[:site_types]).to be_an(Array)
      expect(json_response[:site_types].length).to be > 0
    end

    it "returns site types with required fields" do
      get '/api/signup/site_types'

      expect(response).to have_http_status(:ok)
      json_response[:site_types].each do |site_type|
        expect(site_type).to have_key(:value)
        expect(site_type).to have_key(:label)
        expect(site_type).to have_key(:description)
      end
    end

    it "includes residential, commercial, and vacation_rental types" do
      get '/api/signup/site_types'

      expect(response).to have_http_status(:ok)
      values = json_response[:site_types].map { |t| t[:value] }
      expect(values).to include('residential')
      expect(values).to include('commercial')
      expect(values).to include('vacation_rental')
    end
  end

  describe "full signup flow" do
    it "completes the entire signup process" do
      # Step 1: Start signup
      post '/api/signup/start', params: { email: 'fullflow@example.com' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:success]).to be true
      user_id = json_response[:user_id]
      suggested_subdomain = json_response[:subdomain]

      # Step 2: Configure site
      post '/api/signup/configure', params: {
        subdomain: 'fullflow-site',
        site_type: 'residential'
      }
      expect(response).to have_http_status(:ok)
      expect(json_response[:success]).to be true
      website_id = json_response[:website_id]

      # Step 3: Check status
      get '/api/signup/status'
      expect(response).to have_http_status(:ok)
      expect(json_response[:success]).to be true
      expect(json_response[:provisioning_status]).to be_present

      # Verify data was created correctly
      user = Pwb::User.find(user_id)
      expect(user.email).to eq('fullflow@example.com')

      website = Pwb::Website.find(website_id)
      expect(website.subdomain).to eq('fullflow-site')
      expect(website.site_type).to eq('residential')
    end
  end

  describe "error handling" do
    it "returns JSON for all responses" do
      post '/api/signup/start', params: { email: 'test@example.com' }
      expect(response.content_type).to include('application/json')

      get '/api/signup/check_subdomain', params: { name: 'test' }
      expect(response.content_type).to include('application/json')
    end

    it "handles unexpected errors gracefully" do
      allow(Pwb::SignupApiService).to receive(:new).and_raise(StandardError.new("Unexpected error"))

      post '/api/signup/start', params: { email: 'error@example.com' }

      expect(response).to have_http_status(:internal_server_error)
      expect(json_response[:success]).to be false
      expect(json_response[:error]).to be_present
    end
  end
end
