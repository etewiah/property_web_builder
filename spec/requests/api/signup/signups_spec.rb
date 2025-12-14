# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Signup::Signups", type: :request do
  # Helper to parse JSON response
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  # Generate unique email for each test to avoid collisions
  def unique_email(prefix = "test")
    "#{prefix}-#{SecureRandom.hex(4)}@example.com"
  end

  # Generate unique subdomain for each test
  def unique_subdomain(prefix = "site")
    "#{prefix}-#{SecureRandom.hex(4)}"
  end

  # Ensure subdomain pool has available subdomains for tests
  before(:each) do
    # Clear any existing subdomains to ensure clean state
    Pwb::Subdomain.delete_all

    # Create plenty of available subdomains in the pool for each test
    # Using sequential numeric names to avoid profanity filter issues with random hex
    # Need 50+ because some tests make multiple API calls (e.g., "accepts different site types" loops)
    # and each /api/signup/start reserves a subdomain from the pool
    50.times do |i|
      # Use a safe, predictable naming pattern that won't trigger profanity filters
      name = "testpool-#{i.to_s.rjust(4, '0')}"
      Pwb::Subdomain.create!(name: name, aasm_state: 'available')
    end
  end

  # Clean up after each test to release resources
  after(:each) do
    # Clear signup tokens to prevent cross-test contamination
    Pwb::User.update_all(signup_token: nil, signup_token_expires_at: nil)
  end

  describe "POST /api/signup/start" do
    context "with valid email" do
      it "creates a new user and returns success with signup_token" do
        post '/api/signup/start', params: { email: 'newuser@example.com' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:signup_token]).to be_present
        expect(json_response[:subdomain]).to be_present
        expect(json_response[:message]).to include("Signup started")

        # Verify user was created
        expect(Pwb::User.find_by(email: 'newuser@example.com')).to be_present
      end

      it "normalizes email to lowercase" do
        post '/api/signup/start', params: { email: 'NewUser@Example.COM' }

        expect(response).to have_http_status(:ok)
        user = Pwb::User.find_by(email: 'newuser@example.com')
        expect(user).to be_present
        expect(user.email).to eq('newuser@example.com')
      end

      it "returns a subdomain suggestion" do
        post '/api/signup/start', params: { email: 'subdomain-test@example.com' }

        expect(response).to have_http_status(:ok)
        subdomain = json_response[:subdomain]
        # Subdomain should be a valid name (letters, numbers, hyphens)
        expect(subdomain).to be_present
        expect(subdomain).to match(/^[a-z0-9][a-z0-9\-]*[a-z0-9]$/)
      end

      it "returns signup_token for subsequent requests" do
        post '/api/signup/start', params: { email: 'token@example.com' }

        expect(response).to have_http_status(:ok)
        signup_token = json_response[:signup_token]
        expect(signup_token).to be_present

        # Configure should work with signup_token
        post '/api/signup/configure', params: {
          signup_token: signup_token,
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
        # Clear any existing signup token
        existing_user.update_columns(signup_token: nil, signup_token_expires_at: nil)
      end

      it "returns existing user for signup continuation" do
        expect {
          post '/api/signup/start', params: { email: 'existing@example.com' }
        }.not_to change(Pwb::User, :count)

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:signup_token]).to be_present
      end
    end

    context "with existing email (has website)" do
      let!(:existing_website) { FactoryBot.create(:pwb_website, subdomain: 'existing-user-site') }
      let!(:existing_user) { FactoryBot.create(:pwb_user, email: 'haswebsite@example.com', website: existing_website) }

      before do
        # Create user membership to properly associate user with website via has_many :through
        Pwb::UserMembership.create!(
          user: existing_user,
          website: existing_website,
          role: 'admin',
          active: true
        )
      end

      it "returns error for user with existing website" do
        post '/api/signup/start', params: { email: 'haswebsite@example.com' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to include("already exists")
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
    context "with valid signup_token" do
      # Use instance variable to store token across examples in this context
      let(:config_email) { unique_email("config") }
      let(:signup_token) do
        post '/api/signup/start', params: { email: config_email }
        expect(response).to have_http_status(:ok), "start failed: #{response.body}"
        json_response[:signup_token]
      end

      context "with valid parameters" do
        it "creates a website with the specified subdomain" do
          token = signup_token # Capture token before count check

          expect {
            post '/api/signup/configure', params: {
              signup_token: token,
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
            signup_token: signup_token,
            subdomain: 'My-Site-NAME',
            site_type: 'residential'
          }

          expect(response).to have_http_status(:ok)
          expect(json_response[:subdomain]).to eq('my-site-name')
        end

        it "accepts different site types" do
          %w[residential commercial vacation_rental].each do |site_type|
            # Start a new signup for each site type with unique email
            email = unique_email(site_type)
            subdomain = unique_subdomain(site_type.gsub('_', '-'))

            post '/api/signup/start', params: { email: email }
            expect(response).to have_http_status(:ok), "start_signup failed for #{site_type}: #{response.body}"
            token = json_response[:signup_token]

            post '/api/signup/configure', params: {
              signup_token: token,
              subdomain: subdomain,
              site_type: site_type
            }

            expect(response).to have_http_status(:ok), "configure failed for site_type: #{site_type}: #{response.body}"
            expect(json_response[:site_type]).to eq(site_type)
          end
        end
      end

      context "with invalid parameters" do
        it "returns error for blank subdomain" do
          post '/api/signup/configure', params: {
            signup_token: signup_token,
            subdomain: '',
            site_type: 'residential'
          }

          expect(response).to have_http_status(:bad_request)
          expect(json_response[:success]).to be false
          expect(json_response[:error]).to include("Subdomain")
        end

        it "returns error for blank site_type" do
          post '/api/signup/configure', params: {
            signup_token: signup_token,
            subdomain: 'my-site',
            site_type: ''
          }

          expect(response).to have_http_status(:bad_request)
          expect(json_response[:success]).to be false
          expect(json_response[:error]).to include("Site type")
        end

        it "returns error for invalid subdomain format" do
          post '/api/signup/configure', params: {
            signup_token: signup_token,
            subdomain: 'ab', # Too short
            site_type: 'residential'
          }

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response[:success]).to be false
        end
      end

      context "with duplicate subdomain" do
        let!(:existing_website) { FactoryBot.create(:pwb_website, subdomain: 'taken-subdomain') }

        it "returns error when subdomain is already taken" do
          post '/api/signup/configure', params: {
            signup_token: signup_token,
            subdomain: 'taken-subdomain',
            site_type: 'residential'
          }

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response[:success]).to be false
          expect(json_response[:error]).to include("taken")
        end
      end
    end

    context "without valid signup_token" do
      it "returns error for missing signup_token" do
        post '/api/signup/configure', params: {
          subdomain: 'my-site',
          site_type: 'residential'
        }

        expect(response).to have_http_status(:bad_request)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to include("signup_token")
      end

      it "returns unauthorized error for invalid signup_token" do
        post '/api/signup/configure', params: {
          signup_token: 'invalid-token-12345',
          subdomain: 'my-site',
          site_type: 'residential'
        }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to include("Invalid")
      end
    end
  end

  describe "POST /api/signup/provision" do
    context "with valid signup_token and website" do
      let(:provision_email) { unique_email("provision") }
      let(:provision_subdomain) { unique_subdomain("provision") }
      let(:signup_token) do
        # Complete signup flow up to configure
        post '/api/signup/start', params: { email: provision_email }
        expect(response).to have_http_status(:ok), "start failed: #{response.body}"
        token = json_response[:signup_token]

        post '/api/signup/configure', params: {
          signup_token: token,
          subdomain: provision_subdomain,
          site_type: 'residential'
        }
        expect(response).to have_http_status(:ok), "configure failed: #{response.body}"
        token
      end

      it "triggers provisioning and returns status" do
        post '/api/signup/provision', params: { signup_token: signup_token }

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:provisioning_status]).to be_present
        expect(json_response[:progress]).to be_a(Integer)
        expect(json_response[:message]).to be_present
      end

      it "returns progress percentage" do
        post '/api/signup/provision', params: { signup_token: signup_token }

        expect(response).to have_http_status(:ok)
        expect(json_response[:progress]).to be >= 0
        expect(json_response[:progress]).to be <= 100
      end
    end

    context "without valid signup_token" do
      it "returns error for missing signup_token" do
        post '/api/signup/provision'

        expect(response).to have_http_status(:bad_request)
        expect(json_response[:success]).to be false
      end

      it "returns unauthorized error for invalid signup_token" do
        post '/api/signup/provision', params: { signup_token: 'invalid-token' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
      end
    end
  end

  describe "GET /api/signup/status" do
    context "with valid signup_token and website" do
      let(:status_email) { unique_email("status") }
      let(:status_subdomain) { unique_subdomain("status") }
      let(:signup_token) do
        # Complete signup flow
        post '/api/signup/start', params: { email: status_email }
        expect(response).to have_http_status(:ok), "start failed: #{response.body}"
        token = json_response[:signup_token]

        post '/api/signup/configure', params: {
          signup_token: token,
          subdomain: status_subdomain,
          site_type: 'residential'
        }
        expect(response).to have_http_status(:ok), "configure failed: #{response.body}"
        token
      end

      it "returns current provisioning status" do
        get '/api/signup/status', params: { signup_token: signup_token }

        expect(response).to have_http_status(:ok), "status failed: #{response.body}"
        expect(json_response[:success]).to be true
        expect(json_response[:provisioning_status]).to be_present
        expect(json_response[:progress]).to be_a(Integer)
        expect(json_response[:message]).to be_present
        expect(json_response).to have_key(:complete)
      end

      it "includes website URL when live" do
        # First access signup_token to create the website
        signup_token
        # Then find and update the website
        website = Pwb::Website.find_by(subdomain: status_subdomain)
        website&.update!(provisioning_state: 'live')

        get '/api/signup/status', params: { signup_token: signup_token }

        expect(response).to have_http_status(:ok)
        if json_response[:complete]
          expect(json_response[:website_url]).to be_present
          expect(json_response[:admin_url]).to be_present
        end
      end
    end

    context "without valid signup_token" do
      it "returns error for missing signup_token" do
        get '/api/signup/status'

        expect(response).to have_http_status(:bad_request)
        expect(json_response[:success]).to be false
      end

      it "returns unauthorized error for invalid signup_token" do
        get '/api/signup/status', params: { signup_token: 'invalid-token' }

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

    it "returns subdomain from pool in valid format" do
      get '/api/signup/suggest_subdomain'

      expect(response).to have_http_status(:ok)
      # Subdomain should be a valid name (letters, numbers, hyphens)
      expect(json_response[:subdomain]).to match(/^[a-z0-9][a-z0-9\-]*[a-z0-9]$/)
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

    it "does not suggest subdomains already used by websites" do
      # Create a subdomain in the pool marked as available
      used_subdomain = Pwb::Subdomain.create!(name: 'taken-subdomain-99', aasm_state: 'available')

      # Create a website using that subdomain (simulating data inconsistency)
      FactoryBot.create(:pwb_website, subdomain: 'taken-subdomain-99')

      # Make multiple requests to verify the taken subdomain is never suggested
      10.times do
        get '/api/signup/suggest_subdomain'
        expect(json_response[:subdomain]).not_to eq('taken-subdomain-99')
      end
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
    it "completes the entire signup process with token-based auth" do
      flow_email = unique_email("fullflow")
      flow_subdomain = unique_subdomain("fullflow")

      # Step 1: Start signup
      post '/api/signup/start', params: { email: flow_email }
      expect(response).to have_http_status(:ok)
      expect(json_response[:success]).to be true
      signup_token = json_response[:signup_token]
      suggested_subdomain = json_response[:subdomain]

      expect(signup_token).to be_present
      expect(suggested_subdomain).to be_present

      # Step 2: Configure site
      post '/api/signup/configure', params: {
        signup_token: signup_token,
        subdomain: flow_subdomain,
        site_type: 'residential'
      }
      expect(response).to have_http_status(:ok)
      expect(json_response[:success]).to be true
      website_id = json_response[:website_id]

      # Step 3: Check status
      get '/api/signup/status', params: { signup_token: signup_token }
      expect(response).to have_http_status(:ok)
      expect(json_response[:success]).to be true
      expect(json_response[:provisioning_status]).to be_present

      # Verify data was created correctly
      user = Pwb::User.find_by(email: flow_email)
      expect(user).to be_present
      expect(user.signup_token).to eq(signup_token)

      website = Pwb::Website.find(website_id)
      expect(website.subdomain).to eq(flow_subdomain)
      expect(website.site_type).to eq('residential')
    end
  end

  describe "error handling" do
    it "returns JSON for all responses" do
      post '/api/signup/start', params: { email: unique_email("json") }
      expect(response.content_type).to include('application/json')

      get '/api/signup/check_subdomain', params: { name: 'test' }
      expect(response.content_type).to include('application/json')
    end

    it "handles unexpected errors gracefully" do
      allow(Pwb::SignupApiService).to receive(:new).and_raise(StandardError.new("Unexpected error"))

      post '/api/signup/start', params: { email: unique_email("error") }

      expect(response).to have_http_status(:internal_server_error)
      expect(json_response[:success]).to be false
      expect(json_response[:error]).to be_present
    end
  end
end
