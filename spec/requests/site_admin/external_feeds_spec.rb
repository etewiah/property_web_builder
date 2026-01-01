# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SiteAdmin::ExternalFeeds", type: :request do
  let(:website) { create(:website) }
  let(:admin_user) { create(:user, :admin, website: website) }

  before do
    # Set up the subdomain tenant
    allow_any_instance_of(SiteAdminController).to receive(:current_website).and_return(website)
    allow_any_instance_of(SiteAdminController).to receive(:bypass_admin_auth?).and_return(true)
  end

  describe "GET /site_admin/external_feed" do
    it "returns success" do
      get site_admin_external_feed_path
      expect(response).to have_http_status(:success)
    end

    it "renders the show template" do
      get site_admin_external_feed_path
      expect(response.body).to include("External Feed Settings")
    end

    it "shows provider options" do
      # Register a mock provider
      mock_provider_class = Class.new(Pwb::ExternalFeed::BaseProvider) do
        def self.provider_name
          :test_provider
        end

        def self.display_name
          "Test Provider"
        end

        def available?
          true
        end

        protected

        def required_config_keys
          [:api_key]
        end
      end
      Pwb::ExternalFeed::Registry.register(mock_provider_class)

      get site_admin_external_feed_path
      expect(response.body).to include("Test Provider")

      # Clean up
      Pwb::ExternalFeed::Registry.instance_variable_get(:@providers).delete(:test_provider)
    end

    context "when external feed is configured" do
      before do
        website.update!(
          external_feed_enabled: true,
          external_feed_provider: "resales_online",
          external_feed_config: { api_key: "test123", api_id_sales: "456" }
        )
      end

      it "shows the configuration status" do
        get site_admin_external_feed_path
        expect(response.body).to include("external_feed_enabled")
      end
    end
  end

  describe "PATCH /site_admin/external_feed" do
    it "enables external feed" do
      patch site_admin_external_feed_path, params: {
        website: {
          external_feed_enabled: true,
          external_feed_provider: "resales_online",
          external_feed_config: {
            api_key: "test_key",
            api_id_sales: "test_id"
          }
        }
      }

      expect(response).to redirect_to(site_admin_external_feed_path)
      expect(flash[:notice]).to be_present

      website.reload
      expect(website.external_feed_enabled).to be true
      expect(website.external_feed_provider).to eq("resales_online")
      expect(website.external_feed_config["api_key"]).to eq("test_key")
    end

    it "disables external feed" do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "resales_online"
      )

      patch site_admin_external_feed_path, params: {
        website: {
          external_feed_enabled: false
        }
      }

      expect(response).to redirect_to(site_admin_external_feed_path)
      website.reload
      expect(website.external_feed_enabled).to be false
    end

    it "preserves masked password values" do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "resales_online",
        external_feed_config: { api_key: "secret_key", api_id_sales: "123" }
      )

      patch site_admin_external_feed_path, params: {
        website: {
          external_feed_enabled: true,
          external_feed_config: {
            api_key: "••••••••••••",
            api_id_sales: "456"
          }
        }
      }

      website.reload
      # Original key should be preserved, but api_id_sales should be updated
      expect(website.external_feed_config["api_key"]).to eq("secret_key")
      expect(website.external_feed_config["api_id_sales"]).to eq("456")
    end
  end

  describe "POST /site_admin/external_feed/test_connection" do
    context "when feed is not enabled" do
      it "redirects with alert" do
        post test_connection_site_admin_external_feed_path

        expect(response).to redirect_to(site_admin_external_feed_path)
        expect(flash[:alert]).to include("not enabled")
      end
    end

    context "when feed is enabled" do
      let(:mock_provider_class) do
        Class.new(Pwb::ExternalFeed::BaseProvider) do
          def self.provider_name
            :test_provider
          end

          def self.display_name
            "Test Provider"
          end

          def search(_params)
            Pwb::ExternalFeed::NormalizedSearchResult.new(
              properties: [],
              total_count: 42
            )
          end

          def available?
            true
          end

          protected

          def required_config_keys
            [:api_key]
          end
        end
      end

      before do
        Pwb::ExternalFeed::Registry.register(mock_provider_class)
        website.update!(
          external_feed_enabled: true,
          external_feed_provider: "test_provider",
          external_feed_config: { api_key: "test123" }
        )
      end

      after do
        Pwb::ExternalFeed::Registry.instance_variable_get(:@providers).delete(:test_provider)
      end

      it "tests the connection and reports success" do
        post test_connection_site_admin_external_feed_path

        expect(response).to redirect_to(site_admin_external_feed_path)
        expect(flash[:notice]).to include("successful")
        expect(flash[:notice]).to include("42")
      end
    end
  end

  describe "POST /site_admin/external_feed/clear_cache" do
    context "when feed is not enabled" do
      it "redirects with alert" do
        post clear_cache_site_admin_external_feed_path

        expect(response).to redirect_to(site_admin_external_feed_path)
        expect(flash[:alert]).to include("not enabled")
      end
    end

    context "when feed is enabled" do
      let(:mock_provider_class) do
        Class.new(Pwb::ExternalFeed::BaseProvider) do
          def self.provider_name
            :cache_test_provider
          end

          def self.display_name
            "Cache Test Provider"
          end

          def available?
            true
          end

          protected

          def required_config_keys
            [:api_key]
          end
        end
      end

      before do
        Pwb::ExternalFeed::Registry.register(mock_provider_class)
        website.update!(
          external_feed_enabled: true,
          external_feed_provider: "cache_test_provider",
          external_feed_config: { api_key: "test123" }
        )
      end

      after do
        Pwb::ExternalFeed::Registry.instance_variable_get(:@providers).delete(:cache_test_provider)
      end

      it "clears the cache" do
        expect_any_instance_of(Pwb::ExternalFeed::CacheStore).to receive(:invalidate_all)

        post clear_cache_site_admin_external_feed_path

        expect(response).to redirect_to(site_admin_external_feed_path)
        expect(flash[:notice]).to include("Cache cleared")
      end
    end
  end
end
