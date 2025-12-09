require 'rails_helper'

RSpec.describe "Pwb::Tls", type: :request do
  describe "GET /tls/check" do
    # Use the platform domain from test environment
    let(:platform_domain) { Pwb::Website.platform_domains.first }

    let!(:live_website) do
      FactoryBot.create(:pwb_website,
        subdomain: 'active-tenant',
        provisioning_state: 'live')
    end

    let!(:suspended_website) do
      FactoryBot.create(:pwb_website,
        subdomain: 'suspended-tenant',
        provisioning_state: 'suspended')
    end

    let!(:custom_domain_website) do
      FactoryBot.create(:pwb_website,
        subdomain: 'custom-tenant',
        custom_domain: 'myrealestate.com',
        custom_domain_verified: true,
        provisioning_state: 'live')
    end

    let!(:unverified_domain_website) do
      FactoryBot.create(:pwb_website,
        subdomain: 'unverified-tenant',
        custom_domain: 'unverified.com',
        custom_domain_verified: false,
        provisioning_state: 'live')
    end

    describe "missing domain parameter" do
      it "returns 400 bad request" do
        get '/tls/check'
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "platform subdomain verification" do
      context "when subdomain exists and is live" do
        it "returns 200 OK" do
          get '/tls/check', params: { domain: "active-tenant.#{platform_domain}" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq('OK')
        end
      end

      context "when subdomain exists but is suspended" do
        it "returns 403 Forbidden" do
          get '/tls/check', params: { domain: "suspended-tenant.#{platform_domain}" }
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('suspended')
        end
      end

      context "when subdomain does not exist" do
        it "returns 404 Not Found" do
          get '/tls/check', params: { domain: "nonexistent.#{platform_domain}" }
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when subdomain is reserved (www, admin, api)" do
        it "returns 200 OK for www" do
          get '/tls/check', params: { domain: "www.#{platform_domain}" }
          expect(response).to have_http_status(:ok)
        end

        it "returns 200 OK for admin" do
          get '/tls/check', params: { domain: "admin.#{platform_domain}" }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when it's the bare platform domain" do
        it "returns 200 OK" do
          get '/tls/check', params: { domain: platform_domain }
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe "custom domain verification" do
      context "when custom domain is registered and verified" do
        it "returns 200 OK" do
          get '/tls/check', params: { domain: 'myrealestate.com' }
          expect(response).to have_http_status(:ok)
        end

        it "returns 200 OK for www variant" do
          get '/tls/check', params: { domain: 'www.myrealestate.com' }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when custom domain is registered but not verified" do
        it "returns 403 Forbidden in production-like environment" do
          # In test/development, unverified domains are allowed
          # This test documents the expected behavior
          allow(Rails.env).to receive(:development?).and_return(false)
          allow(Rails.env).to receive(:test?).and_return(false)

          get '/tls/check', params: { domain: 'unverified.com' }
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('not verified')
        end
      end

      context "when custom domain is not registered" do
        it "returns 404 Not Found" do
          get '/tls/check', params: { domain: 'unknown-domain.com' }
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe "with secret authentication" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('TLS_CHECK_SECRET').and_return('super-secret-token')
      end

      context "with valid secret" do
        it "returns 200 OK" do
          get '/tls/check',
            params: { domain: "active-tenant.#{platform_domain}" },
            headers: { 'X-TLS-Secret' => 'super-secret-token' }
          expect(response).to have_http_status(:ok)
        end

        it "accepts secret as query parameter" do
          get '/tls/check',
            params: { domain: "active-tenant.#{platform_domain}", secret: 'super-secret-token' }
          expect(response).to have_http_status(:ok)
        end
      end

      context "with invalid secret" do
        it "returns 401 Unauthorized" do
          get '/tls/check',
            params: { domain: "active-tenant.#{platform_domain}" },
            headers: { 'X-TLS-Secret' => 'wrong-secret' }
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "with missing secret" do
        it "returns 401 Unauthorized" do
          get '/tls/check', params: { domain: "active-tenant.#{platform_domain}" }
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    describe "provisioning states" do
      it "allows 'ready' state" do
        live_website.update!(provisioning_state: 'ready')
        get '/tls/check', params: { domain: "active-tenant.#{platform_domain}" }
        expect(response).to have_http_status(:ok)
      end

      it "allows websites still provisioning" do
        live_website.update!(provisioning_state: 'configuring')
        get '/tls/check', params: { domain: "active-tenant.#{platform_domain}" }
        expect(response).to have_http_status(:ok)
      end

      it "forbids 'terminated' state" do
        live_website.update!(provisioning_state: 'terminated')
        get '/tls/check', params: { domain: "active-tenant.#{platform_domain}" }
        expect(response).to have_http_status(:forbidden)
      end

      it "forbids 'failed' state" do
        live_website.update!(provisioning_state: 'failed')
        get '/tls/check', params: { domain: "active-tenant.#{platform_domain}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
