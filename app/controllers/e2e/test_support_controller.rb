# frozen_string_literal: true

module E2e
  # Controller providing test support endpoints for E2E testing
  # Only available in e2e environment when BYPASS_ADMIN_AUTH is set
  #
  # These endpoints allow Playwright tests to reset database state
  # between tests to ensure proper test isolation.
  class TestSupportController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_e2e_environment

    # POST /e2e/reset_website_settings
    # Resets the current website's settings to their seed values
    def reset_website_settings
      website = Pwb::Current.website
      return render json: { error: 'No website found' }, status: :not_found unless website

      # Reset to seed values
      website.update!(
        company_display_name: seed_company_name(website),
        default_client_locale: 'en-UK',
        default_currency: 'USD',
        default_area_unit: 'sqmt',
        theme_name: 'default',
        external_image_mode: false,
        supported_locales: ['en']
      )

      render json: {
        success: true,
        message: 'Website settings reset to seed values',
        website: {
          subdomain: website.subdomain,
          company_display_name: website.company_display_name,
          default_currency: website.default_currency,
          default_area_unit: website.default_area_unit,
          theme_name: website.theme_name
        }
      }
    end

    # POST /e2e/reset_all
    # Resets all test data to seed state (more comprehensive but slower)
    def reset_all
      website = Pwb::Current.website
      return render json: { error: 'No website found' }, status: :not_found unless website

      # Reset website settings
      website.update!(
        company_display_name: seed_company_name(website),
        default_client_locale: 'en-UK',
        default_currency: 'USD',
        default_area_unit: 'sqmt',
        theme_name: 'default',
        external_image_mode: false,
        supported_locales: ['en']
      )

      # Reset agency
      if website.agency
        website.agency.update!(
          company_name: seed_company_name(website),
          display_name: seed_company_name(website)
        )
      end

      render json: {
        success: true,
        message: 'All test data reset to seed values'
      }
    end

    # GET /e2e/health
    # Simple health check for E2E test environment
    def health
      render json: {
        success: true,
        environment: Rails.env,
        bypass_auth: ENV['BYPASS_ADMIN_AUTH'] == 'true',
        website: Pwb::Current.website&.subdomain
      }
    end

    private

    def verify_e2e_environment
      unless Rails.env.e2e? && ENV['BYPASS_ADMIN_AUTH'] == 'true'
        render json: {
          error: 'E2E test endpoints only available in e2e environment with BYPASS_ADMIN_AUTH=true'
        }, status: :forbidden
      end
    end

    def seed_company_name(website)
      case website.subdomain
      when 'tenant-a'
        'Tenant A Real Estate'
      when 'tenant-b'
        'Tenant B Real Estate'
      else
        "#{website.subdomain.titleize} Real Estate"
      end
    end
  end
end
