# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Website Settings', type: :request do
  # Set up tenant settings to allow all themes used in tests
  before(:all) do
    Pwb::TenantSettings.delete_all
    Pwb::TenantSettings.create!(
      singleton_key: "default",
      default_available_themes: %w[default brisbane bologna barcelona biarritz]
    )
  end

  after(:all) do
    Pwb::TenantSettings.delete_all
  end

  let!(:website) { create(:pwb_website, subdomain: 'settings-test') }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@settings-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET /site_admin/website/settings/general' do
    it 'renders the general settings tab successfully' do
      get site_admin_website_settings_path(tab: 'general'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('General Settings')
      expect(response.body).to include('Supported Languages')
      expect(response.body).to include('Primary Currency')
    end
  end

  describe 'PATCH /site_admin/website/settings (general tab)' do
    it 'updates supported locales successfully' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'general',
              pwb_website: {
                company_display_name: 'Test Company',
                default_client_locale: 'es',
                supported_locales: ['es', 'fr', 'de', '']
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      website.reload
      # Should filter out empty strings from hidden form field
      expect(website.supported_locales).to include('es', 'fr', 'de')
      expect(website.supported_locales).not_to include('')
    end

    it 'filters out blank entries from supported locales' do
      # First set some locales, then clear them
      website.update!(supported_locales: ['en', 'es'])

      patch site_admin_website_settings_path,
            params: {
              tab: 'general',
              pwb_website: {
                company_display_name: 'Test Company',
                default_client_locale: 'de', # Must include a valid locale
                supported_locales: ['de', ''] # de plus blank
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      website.reload
      # Should have de but not the empty string
      expect(website.supported_locales).to include('de')
      expect(website.supported_locales).not_to include('')
    end
  end

  describe 'GET /site_admin/website/settings/appearance' do
    it 'renders the appearance settings tab successfully' do
      get site_admin_website_settings_path(tab: 'appearance'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Appearance Settings')
      expect(response.body).to include('Theme')
    end
  end

  describe 'GET /site_admin/website/settings/navigation' do
    it 'renders the navigation settings tab successfully' do
      get site_admin_website_settings_path(tab: 'navigation'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Navigation Settings')
    end
  end

  describe 'GET /site_admin/website/settings/notifications' do
    it 'renders the notifications settings tab successfully' do
      get site_admin_website_settings_path(tab: 'notifications'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Push Notifications')
    end
  end

  describe 'GET /site_admin/website/settings/social' do
    it 'renders the social settings tab successfully' do
      get site_admin_website_settings_path(tab: 'social'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Social Media Links')
    end

    it 'displays all 6 social media platforms' do
      get site_admin_website_settings_path(tab: 'social'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response.body).to include('Facebook')
      expect(response.body).to include('Instagram')
      expect(response.body).to include('Linkedin')
      expect(response.body).to include('Youtube')
      expect(response.body).to include('Twitter')
      expect(response.body).to include('Whatsapp')
    end

    it 'shows existing social media link URLs' do
      website.links.create!(
        slug: 'social_media_facebook',
        link_url: 'https://facebook.com/existingpage',
        placement: :social_media
      )

      get site_admin_website_settings_path(tab: 'social'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response.body).to include('https://facebook.com/existingpage')
    end
  end

  describe 'PATCH /site_admin/website/settings (social tab)' do
    it 'creates new social media links' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                facebook: 'https://facebook.com/newpage',
                instagram: 'https://instagram.com/newhandle'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(site_admin_website_settings_tab_path('social'))

      facebook_link = website.links.find_by(slug: 'social_media_facebook')
      expect(facebook_link.link_url).to eq('https://facebook.com/newpage')

      instagram_link = website.links.find_by(slug: 'social_media_instagram')
      expect(instagram_link.link_url).to eq('https://instagram.com/newhandle')
    end

    it 'updates existing social media links' do
      website.links.create!(
        slug: 'social_media_facebook',
        link_url: 'https://facebook.com/oldpage',
        placement: :social_media
      )

      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                facebook: 'https://facebook.com/updatedpage'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      facebook_link = website.links.find_by(slug: 'social_media_facebook')
      expect(facebook_link.link_url).to eq('https://facebook.com/updatedpage')
    end

    it 'sets link visibility based on URL presence' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                facebook: 'https://facebook.com/page',
                twitter: ''
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      facebook_link = website.links.find_by(slug: 'social_media_facebook')
      twitter_link = website.links.find_by(slug: 'social_media_twitter')

      expect(facebook_link.visible).to be true
      expect(twitter_link.visible).to be false
    end

    it 'shows success notice after update' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                whatsapp: 'https://wa.me/1234567890'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(flash[:notice]).to eq('Social media links updated successfully')
    end
  end

  # ==========================================================================
  # SEO Tab Tests - Verify the fix for missing hidden tab field
  # ==========================================================================
  describe 'GET /site_admin/website/settings/seo' do
    it 'renders the SEO settings tab successfully' do
      get site_admin_website_settings_path(tab: 'seo'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('SEO')
      expect(response.body).to include('Default Page Title')
      expect(response.body).to include('Default Meta Description')
    end
  end

  describe 'PATCH /site_admin/website/settings (seo tab)' do
    it 'updates SEO title and meta description' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'seo',
              pwb_website: {
                default_seo_title: 'My Real Estate Agency | Find Your Dream Home',
                default_meta_description: 'Browse premium properties in the city center.'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(site_admin_website_settings_tab_path('seo'))

      website.reload
      expect(website.default_seo_title).to eq('My Real Estate Agency | Find Your Dream Home')
      expect(website.default_meta_description).to eq('Browse premium properties in the city center.')
    end

    it 'updates favicon and logo URLs' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'seo',
              pwb_website: {
                favicon_url: 'https://example.com/favicon.ico',
                main_logo_url: 'https://example.com/logo.png'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      expect(website.favicon_url).to eq('https://example.com/favicon.ico')
      expect(website.main_logo_url).to eq('https://example.com/logo.png')
    end

    it 'updates social media/Open Graph settings' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'seo',
              pwb_website: { default_seo_title: 'Test' },
              social_media: {
                og_image: 'https://example.com/og-image.jpg',
                twitter_card: 'summary_large_image',
                twitter_handle: '@testcompany'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      expect(website.social_media['og_image']).to eq('https://example.com/og-image.jpg')
      expect(website.social_media['twitter_card']).to eq('summary_large_image')
      expect(website.social_media['twitter_handle']).to eq('@testcompany')
    end

    it 'shows success notice after save' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'seo',
              pwb_website: { default_seo_title: 'Updated Title' }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(flash[:notice]).to eq('SEO settings updated successfully')
    end

    # This test specifically verifies the bug we fixed
    it 'does NOT save when tab parameter is missing (regression test)' do
      original_title = website.default_seo_title

      # Simulate form submission WITHOUT tab parameter
      # This should default to 'general' tab and NOT update SEO
      patch site_admin_website_settings_path,
            params: {
              # tab: 'seo', # MISSING - this was the bug
              pwb_website: {
                default_seo_title: 'This should NOT be saved'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      website.reload
      # Without tab param, it goes to general tab, so SEO title should NOT change
      expect(website.default_seo_title).to eq(original_title)
    end
  end

  # ==========================================================================
  # Appearance Tab Tests
  # ==========================================================================
  describe 'PATCH /site_admin/website/settings (appearance tab)' do
    it 'updates theme name' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'appearance',
              website: {
                theme_name: 'brisbane'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(site_admin_website_settings_tab_path('appearance'))

      website.reload
      expect(website.theme_name).to eq('brisbane')
    end

    it 'updates selected palette' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'appearance',
              website: {
                theme_name: 'default',
                selected_palette: 'ocean'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      expect(website.selected_palette).to eq('ocean')
    end

    it 'updates custom CSS' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'appearance',
              website: {
                raw_css: '.custom-class { color: red; }'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      expect(website.raw_css).to eq('.custom-class { color: red; }')
    end

    it 'shows success notice after save' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'appearance',
              website: { theme_name: 'default' }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(flash[:notice]).to eq('Appearance settings updated successfully')
    end
  end

  # ==========================================================================
  # Notifications Tab Tests
  # ==========================================================================
  describe 'PATCH /site_admin/website/settings (notifications tab)' do
    it 'enables notifications with topic prefix' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'notifications',
              pwb_website: {
                ntfy_enabled: true,
                ntfy_topic_prefix: 'myagency-notifications',
                ntfy_server_url: 'https://ntfy.sh'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(site_admin_website_settings_tab_path('notifications'))

      website.reload
      expect(website.ntfy_enabled).to be true
      expect(website.ntfy_topic_prefix).to eq('myagency-notifications')
      expect(website.ntfy_server_url).to eq('https://ntfy.sh')
    end

    it 'updates notification channel preferences' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'notifications',
              pwb_website: {
                ntfy_notify_inquiries: true,
                ntfy_notify_listings: false,
                ntfy_notify_security: true
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      expect(website.ntfy_notify_inquiries).to be true
      expect(website.ntfy_notify_listings).to be false
      expect(website.ntfy_notify_security).to be true
    end

    it 'preserves existing access token when placeholder submitted' do
      website.update!(ntfy_access_token: 'real_secret_token')

      patch site_admin_website_settings_path,
            params: {
              tab: 'notifications',
              pwb_website: {
                ntfy_enabled: true,
                ntfy_access_token: '••••••••••••' # Placeholder from form
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      website.reload
      expect(website.ntfy_access_token).to eq('real_secret_token')
    end

    it 'shows success notice after save' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'notifications',
              pwb_website: { ntfy_enabled: false }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(flash[:notice]).to eq('Notification settings updated successfully')
    end
  end

  # ==========================================================================
  # Home Tab Tests
  # ==========================================================================
  describe 'GET /site_admin/website/settings/home' do
    it 'renders the home settings tab successfully' do
      get site_admin_website_settings_path(tab: 'home'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Home Page Settings')
    end
  end

  describe 'PATCH /site_admin/website/settings (home tab)' do
    context 'with home page existing' do
      let!(:home_page) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_page, website: website, slug: 'home', page_title: 'Old Title')
        end
      end

      it 'updates home page title' do
        patch site_admin_website_settings_path,
              params: {
                tab: 'home',
                page: {
                  page_title: 'Welcome to Our Agency'
                }
              },
              headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(site_admin_website_settings_tab_path('home'))

        home_page.reload
        expect(home_page.page_title).to eq('Welcome to Our Agency')
      end
    end

    it 'updates landing page display options' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'home',
              website: {
                landing_hide_for_rent: true,
                landing_hide_for_sale: false,
                landing_hide_search_bar: true
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      expect(website.landing_hide_for_rent).to be true
      expect(website.landing_hide_for_sale).to be false
      expect(website.landing_hide_search_bar).to be true
    end
  end

  # ==========================================================================
  # Search Tab Tests
  # ==========================================================================
  describe 'GET /site_admin/website/settings/search' do
    it 'renders the search settings tab successfully' do
      get site_admin_website_settings_path(tab: 'search'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Search Configuration')
      expect(response.body).to include('Display Options')
      expect(response.body).to include('Listing Types')
      expect(response.body).to include('Price Filter')
      expect(response.body).to include('Bedrooms Filter')
      expect(response.body).to include('Bathrooms Filter')
      expect(response.body).to include('Area Filter')
    end

    it 'loads existing search configuration' do
      website.update!(search_config: {
        'display' => { 'show_results_map' => true, 'default_results_per_page' => 24 },
        'filters' => { 'price' => { 'enabled' => true, 'input_type' => 'manual' } }
      })

      get site_admin_website_settings_path(tab: 'search'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      # Verify config is loaded - the form should have checkboxes checked
      expect(response.body).to include('Show Results Map')
    end
  end

  describe 'PATCH /site_admin/website/settings (search tab)' do
    it 'updates display options' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                display: {
                  show_results_map: '1',
                  show_active_filters: '1',
                  show_save_search: '0',
                  show_favorites: '1',
                  default_sort: 'price_asc',
                  default_results_per_page: '24'
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(site_admin_website_settings_tab_path('search'))

      website.reload
      config = website.search_config
      expect(config.dig('display', 'show_results_map')).to be true
      expect(config.dig('display', 'show_active_filters')).to be true
      expect(config.dig('display', 'show_save_search')).to be false
      expect(config.dig('display', 'show_favorites')).to be true
      expect(config.dig('display', 'default_sort')).to eq('price_asc')
      expect(config.dig('display', 'default_results_per_page')).to eq(24)
    end

    it 'updates listing types configuration' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                listing_types: {
                  sale: { enabled: '1', is_default: '0' },
                  rental: { enabled: '1', is_default: '1' }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      config = website.search_config
      expect(config.dig('listing_types', 'sale', 'enabled')).to be true
      expect(config.dig('listing_types', 'sale', 'is_default')).to be false
      expect(config.dig('listing_types', 'rental', 'enabled')).to be true
      expect(config.dig('listing_types', 'rental', 'is_default')).to be true
    end

    it 'updates price filter configuration' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                filters: {
                  price: {
                    enabled: '1',
                    position: '1',
                    input_type: 'dropdown_with_manual',
                    sale: {
                      default_min: '100000',
                      default_max: '1000000',
                      step: '25000',
                      presets: '100000, 200000, 500000, 750000, 1000000'
                    },
                    rental: {
                      default_min: '500',
                      default_max: '5000',
                      step: '100',
                      presets: '500, 1000, 1500, 2000, 3000, 5000'
                    }
                  }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      price_config = website.search_config.dig('filters', 'price')
      expect(price_config['enabled']).to be true
      expect(price_config['input_type']).to eq('dropdown_with_manual')
      expect(price_config.dig('sale', 'default_min')).to eq(100_000)
      expect(price_config.dig('sale', 'default_max')).to eq(1_000_000)
      expect(price_config.dig('sale', 'step')).to eq(25_000)
      expect(price_config.dig('sale', 'presets')).to eq([100_000, 200_000, 500_000, 750_000, 1_000_000])
      expect(price_config.dig('rental', 'default_min')).to eq(500)
      expect(price_config.dig('rental', 'presets')).to eq([500, 1000, 1500, 2000, 3000, 5000])
    end

    it 'updates bedrooms filter configuration with separate min/max options' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                filters: {
                  bedrooms: {
                    enabled: '1',
                    position: '2',
                    min_options: 'Any, 1, 2, 3, 4, 5+',
                    max_options: '1, 2, 3, 4, 5, 6, No max',
                    default_min: '2',
                    default_max: '4',
                    show_max_filter: '1'
                  }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      bedrooms_config = website.search_config.dig('filters', 'bedrooms')
      expect(bedrooms_config['enabled']).to be true
      expect(bedrooms_config['min_options']).to eq(['Any', 1, 2, 3, 4, '5+'])
      expect(bedrooms_config['max_options']).to eq([1, 2, 3, 4, 5, 6, 'No max'])
      expect(bedrooms_config['default_min']).to eq(2)
      expect(bedrooms_config['default_max']).to eq(4)
      expect(bedrooms_config['show_max_filter']).to be true
    end

    it 'updates bathrooms filter configuration with separate min/max options' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                filters: {
                  bathrooms: {
                    enabled: '1',
                    position: '3',
                    min_options: 'Any, 1, 2, 3, 4+',
                    max_options: '1, 2, 3, 4, 5, No max',
                    default_min: '1',
                    default_max: '3',
                    show_max_filter: '1'
                  }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      bathrooms_config = website.search_config.dig('filters', 'bathrooms')
      expect(bathrooms_config['enabled']).to be true
      expect(bathrooms_config['min_options']).to eq(['Any', 1, 2, 3, '4+'])
      expect(bathrooms_config['max_options']).to eq([1, 2, 3, 4, 5, 'No max'])
      expect(bathrooms_config['default_min']).to eq(1)
      expect(bathrooms_config['default_max']).to eq(3)
      expect(bathrooms_config['show_max_filter']).to be true
    end

    it 'updates area filter configuration' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                filters: {
                  area: {
                    enabled: '1',
                    position: '4',
                    unit: 'sqft',
                    default_min: '500',
                    default_max: '5000',
                    presets: '500, 1000, 2000, 3000, 5000'
                  }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      area_config = website.search_config.dig('filters', 'area')
      expect(area_config['enabled']).to be true
      expect(area_config['unit']).to eq('sqft')
      expect(area_config['default_min']).to eq(500)
      expect(area_config['default_max']).to eq(5000)
      expect(area_config['presets']).to eq([500, 1000, 2000, 3000, 5000])
    end

    it 'updates other filters (reference, property_type, location, features)' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                filters: {
                  reference: { enabled: '1', position: '0', input_type: 'text' },
                  property_type: { enabled: '1', position: '5' },
                  location: { enabled: '0', position: '6' },
                  features: { enabled: '1', position: '7' }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      website.reload
      config = website.search_config['filters']
      expect(config.dig('reference', 'enabled')).to be true
      expect(config.dig('property_type', 'enabled')).to be true
      expect(config.dig('location', 'enabled')).to be false
      expect(config.dig('features', 'enabled')).to be true
    end

    it 'shows success notice after save' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                display: { show_results_map: '1' }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(flash[:notice]).to eq('Search configuration updated successfully')
    end

    it 'handles empty/blank price presets gracefully' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                filters: {
                  price: {
                    enabled: '1',
                    sale: { presets: '' },
                    rental: { presets: '' }
                  }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      website.reload
      # Empty presets should result in nil, not an empty array
      expect(website.search_config.dig('filters', 'price', 'sale', 'presets')).to be_nil
    end

    it 'filters out zero values from presets' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                filters: {
                  price: {
                    enabled: '1',
                    sale: { presets: '0, 100000, 0, 500000' }
                  }
                }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      website.reload
      presets = website.search_config.dig('filters', 'price', 'sale', 'presets')
      expect(presets).to eq([100_000, 500_000])
      expect(presets).not_to include(0)
    end

    it 'preserves existing config when only updating partial settings' do
      # Set up initial configuration
      website.update!(search_config: {
        'display' => { 'show_results_map' => true, 'default_sort' => 'price_desc' },
        'filters' => {
          'bedrooms' => { 'enabled' => true, 'options' => ['Any', 1, 2, 3] }
        }
      })

      # Update only display options
      patch site_admin_website_settings_path,
            params: {
              tab: 'search',
              search_config: {
                display: { show_results_map: '0', default_sort: 'newest' }
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      website.reload
      # Display should be updated
      expect(website.search_config.dig('display', 'show_results_map')).to be false
      expect(website.search_config.dig('display', 'default_sort')).to eq('newest')
    end
  end

  describe 'DELETE /site_admin/website/settings/search/reset' do
    it 'resets search configuration to defaults' do
      # Set up custom configuration
      website.update!(search_config: {
        'display' => { 'show_results_map' => true, 'default_results_per_page' => 48 },
        'filters' => {
          'price' => { 'enabled' => true, 'input_type' => 'manual' },
          'bedrooms' => { 'enabled' => false }
        }
      })

      delete site_admin_website_reset_search_config_path,
             headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(site_admin_website_settings_tab_path('search'))

      website.reload
      expect(website.search_config).to eq({})
    end

    it 'shows success notice after reset' do
      website.update!(search_config: { 'display' => { 'show_results_map' => true } })

      delete site_admin_website_reset_search_config_path,
             headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(flash[:notice]).to eq('Search configuration has been reset to defaults')
    end
  end

  # ==========================================================================
  # Tab Parameter Validation
  # ==========================================================================
  describe 'invalid tab handling' do
    it 'redirects for invalid tab parameter' do
      get site_admin_website_settings_path(tab: 'invalid_tab'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to include('Invalid tab')
    end
  end
end
