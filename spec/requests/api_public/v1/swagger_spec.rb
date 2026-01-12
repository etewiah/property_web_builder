# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API Public V1', type: :request, openapi_spec: 'v1/api_public_swagger.yaml' do
  # Helper to create properties that appear in the materialized view
  def create_listed_sale_property(website:, reference:)
    realty_asset = Pwb::RealtyAsset.create!(website: website, reference: reference)
    Pwb::SaleListing.create!(
      realty_asset: realty_asset,
      reference: reference,
      visible: true,
      archived: false,
      active: true,
      price_sale_current_cents: 250_000_00,
      price_sale_current_currency: 'EUR'
    )
    Pwb::ListedProperty.refresh
    Pwb::ListedProperty.find_by(reference: reference)
  end

  # Create website first without tenant scope
  let!(:test_website) { Pwb::Website.create!(subdomain: 'apipublic-test', slug: 'apipublic-test', company_display_name: 'API Public Test', default_client_locale: 'en-GB', supported_locales: ['en-GB']) }

  # Create agency within tenant context
  let!(:test_agency) do
    ActsAsTenant.with_tenant(test_website) do
      Pwb::Agency.create!(website: test_website, company_name: 'API Public Test Agency')
    end
  end

  before do
    host! 'apipublic-test.example.com'
    Pwb::Current.website = test_website
    ActsAsTenant.current_tenant = test_website
  end

  after do
    ActsAsTenant.current_tenant = nil
    Pwb::Current.reset
  end

  path '/api_public/v1/properties/{id}' do
    get 'Retrieves a property' do
      tags 'Properties'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'property found' do
        schema type: :object,
               properties: {
                 id: { type: :string }, # UUID
                 reference: { type: :string },
                 title: { type: %i[string null] },
                 description: { type: %i[string null] },
                 prop_photos: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       image: { type: :string }
                     }
                   }
                 },
                 price_sale_current_cents: { type: :integer },
                 price_rental_monthly_current_cents: { type: :integer },
                 currency: { type: :string },
                 area_unit: { type: :string },
                 count_bedrooms: { type: :integer },
                 count_bathrooms: { type: :number },
                 count_garages: { type: :integer },
                 for_sale: { type: :boolean },
                 for_rent: { type: :boolean }
               }

        let!(:property) { create_listed_sale_property(website: test_website, reference: 'SWAGGER-PROP-001') }
        let(:id) { property.id }
        run_test!
      end

      response '404', 'property not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end
  end

  path '/api_public/v1/properties' do
    get 'Retrieves properties' do
      tags 'Properties'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :sale_or_rental, in: :query, type: :string, required: false
      parameter name: :currency, in: :query, type: :string, required: false
      parameter name: :for_sale_price_from, in: :query, type: :string, required: false
      parameter name: :for_sale_price_till, in: :query, type: :string, required: false
      parameter name: :for_rent_price_from, in: :query, type: :string, required: false
      parameter name: :for_rent_price_till, in: :query, type: :string, required: false
      parameter name: :bedrooms_from, in: :query, type: :string, required: false
      parameter name: :bathrooms_from, in: :query, type: :string, required: false
      parameter name: :property_type, in: :query, type: :string, required: false
      parameter name: :sort_by, in: :query, type: :string, required: false
      parameter name: :sort, in: :query, type: :string, required: false, deprecated: true
      parameter name: :featured, in: :query, type: :boolean, required: false
      parameter name: :highlighted, in: :query, type: :boolean, required: false, deprecated: true

      response '200', 'properties found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string }, # UUID
                       slug: { type: :string },
                       reference: { type: :string },
                       title: { type: %i[string null] },
                       price_sale_current_cents: { type: :integer },
                       price_rental_monthly_current_cents: { type: :integer },
                       currency: { type: :string },
                       prop_photos: {
                         type: :array,
                         items: {
                           type: :object,
                           properties: {
                             image: { type: :string }
                           }
                         }
                       }
                     }
                   }
                 },
                 map_markers: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       slug: { type: :string },
                       lat: { type: :number, format: :float },
                       lng: { type: :number, format: :float },
                       title: { type: :string },
                       price: { type: :string },
                       image: { type: %i[string null] },
                       url: { type: :string }
                     }
                   }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     total: { type: :integer },
                     page: { type: :integer },
                     per_page: { type: :integer },
                     total_pages: { type: :integer }
                   }
                 }
               }

        let(:sale_or_rental) { 'sale' }
        run_test!
      end
    end
  end

  path '/api_public/v1/pages/{id}' do
    get 'Retrieves a page' do
      tags 'Pages'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string

      response '200', 'page found' do
        schema type: :object,
               properties: {
                 slug: { type: %i[string null] },
                 link_path: { type: %i[string null] },
                 visible: { type: :boolean },
                 page_title: { type: %i[string null] },
                 link_title: { type: %i[string null] },
                 raw_html: { type: %i[string null] },
                 show_in_top_nav: { type: :boolean },
                 show_in_footer: { type: :boolean },
                 page_contents: {
                   type: :array,
                   items: { type: :object }
                 }
               }

        let!(:page) { FactoryBot.create(:pwb_page, website: test_website, slug: 'test-page') }
        let(:id) { page.id }
        run_test!
      end

      response '404', 'page not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end
  end

  path '/api_public/v1/pages/by_slug/{slug}' do
    get 'Retrieves a page by slug' do
      tags 'Pages'
      produces 'application/json'
      parameter name: :slug, in: :path, type: :string
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'page found' do
        schema type: :object,
               properties: {
                 slug: { type: %i[string null] },
                 link_path: { type: %i[string null] },
                 visible: { type: :boolean },
                 page_title: { type: %i[string null] },
                 link_title: { type: %i[string null] },
                 raw_html: { type: %i[string null] },
                 show_in_top_nav: { type: :boolean },
                 show_in_footer: { type: :boolean },
                 page_contents: {
                   type: :array,
                   items: { type: :object }
                 }
               }

        let!(:page) { FactoryBot.create(:pwb_page, website: test_website, slug: 'another-page') }
        let(:slug) { page.slug }
        run_test!
      end

      response '404', 'page not found' do
        let(:slug) { 'invalid' }
        run_test!
      end
    end
  end

  path '/api_public/v1/translations' do
    get 'Retrieves translations' do
      tags 'Translations'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: true

      response '200', 'translations found' do
        schema type: :object,
               properties: {
                 locale: { type: :string },
                 result: { type: :object }
               }
        let(:locale) { 'en' }
        run_test!
      end
    end
  end

  path '/api_public/v1/links' do
    get 'Retrieves links' do
      tags 'Links'
      produces 'application/json'
      parameter name: :position, in: :query, type: :string, required: false
      parameter name: :placement, in: :query, type: :string, required: false, deprecated: true
      parameter name: :locale, in: :query, type: :string, required: false
      parameter name: :visible_only, in: :query, type: :boolean, required: false

      response '200', 'links found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       slug: { type: :string },
                       title: { type: :string },
                       url: { type: :string },
                       position: { type: :string },
                       order: { type: :integer },
                       visible: { type: :boolean },
                       external: { type: :boolean }
                     }
                   }
                 }
               }
        run_test!
      end
    end
  end

  path '/api_public/v1/site_details' do
    get 'Retrieves site details' do
      tags 'Site Details'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'site details found' do
        schema type: :object,
               properties: {
                 company_display_name: { type: :string },
                 theme_name: { type: %i[string null] },
                 default_currency: { type: :string },
                 supported_locales: { type: :array, items: { type: :string } },
                 social_media: { type: :object },
                 agency: { type: %i[object null] },
                 top_nav_display_links: { type: :array, items: { type: :object } },
                 footer_display_links: { type: :array, items: { type: :object } }
               }
        run_test!
      end
    end
  end

  path '/api_public/v1/select_values' do
    get 'Retrieves select values' do
      tags 'Select Values'
      produces 'application/json'
      parameter name: :field_names, in: :query, type: :string, required: false, description: "Comma separated list of field names"

      response '200', 'select values found' do
        schema type: :object,
               additionalProperties: {
                 type: :array,
                 items: {
                   type: :object,
                   properties: {
                     value: { type: :string },
                     label: { type: :string }
                   }
                 }
               }
        run_test!
      end
    end
  end

  path '/api_public/v1/theme' do
    get 'Retrieves theme configuration' do
      tags 'Theme'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'theme found' do
        schema type: :object,
               properties: {
                 theme: {
                   type: :object,
                   properties: {
                     name: { type: :string },
                     palette_id: { type: %i[string null] },
                     palette_mode: { type: :string },
                     colors: {
                       type: :object,
                       additionalProperties: { type: :string }
                     },
                     fonts: {
                       type: :object,
                       properties: {
                         heading: { type: :string },
                         body: { type: :string }
                       }
                     },
                     border_radius: {
                       type: :object,
                       properties: {
                         sm: { type: :string },
                         md: { type: :string },
                         lg: { type: :string },
                         xl: { type: :string }
                       }
                     },
                     dark_mode: {
                       type: :object,
                       properties: {
                         enabled: { type: :boolean },
                         setting: { type: :string },
                         force_dark: { type: :boolean },
                         auto: { type: :boolean }
                       }
                     },
                     css_variables: { type: :string },
                     custom_css: { type: %i[string null] }
                   }
                 }
               }
        run_test!
      end
    end
  end

  path '/api_public/v1/search/config' do
    get 'Retrieves search configuration' do
      tags 'Search Config'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'search config found' do
        schema type: :object,
               properties: {
                 property_types: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       key: { type: :string },
                       label: { type: :string },
                       count: { type: :integer }
                     }
                   }
                 },
                 price_options: {
                   type: :object,
                   properties: {
                     sale: {
                       type: :object,
                       properties: {
                         from: { type: :array, items: { type: :string } },
                         to: { type: :array, items: { type: :string } }
                       }
                     },
                     rent: {
                       type: :object,
                       properties: {
                         from: { type: :array, items: { type: :string } },
                         to: { type: :array, items: { type: :string } }
                       }
                     }
                   }
                 },
                 features: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       key: { type: :string },
                       label: { type: :string }
                     }
                   }
                 },
                 bedrooms: { type: :array, items: { type: :integer } },
                 bathrooms: { type: :array, items: { type: :integer } },
                 sort_options: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       value: { type: :string },
                       label: { type: :string }
                     }
                   }
                 },
                 area_unit: { type: :string },
                 currency: { type: :string }
               }
        run_test!
      end
    end
  end

  path '/api_public/v1/testimonials' do
    get 'Retrieves testimonials' do
      tags 'Testimonials'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :featured_only, in: :query, type: :boolean, required: false

      response '200', 'testimonials found' do
        schema type: :object,
               properties: {
                 testimonials: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       quote: { type: :string },
                       author_name: { type: :string },
                       author_role: { type: %i[string null] },
                       author_photo: { type: %i[string null] },
                       rating: { type: %i[integer null] },
                       position: { type: :integer }
                     }
                   }
                 }
               }
        run_test!
      end
    end
  end

  path '/api_public/v1/enquiries' do
    post 'Creates a property enquiry' do
      tags 'Enquiries'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :enquiry, in: :body, schema: {
        type: :object,
        properties: {
          enquiry: {
            type: :object,
            properties: {
              name: { type: :string },
              email: { type: :string },
              phone: { type: :string },
              message: { type: :string },
              property_id: { type: :string }
            }
          },
          locale: { type: :string }
        }
      }

      response '201', 'enquiry created' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     contact_id: { type: :integer },
                     message_id: { type: :integer }
                   }
                 }
               }
        let(:enquiry) do
          {
            enquiry: {
              name: 'Swagger User',
              email: 'swagger@example.com',
              phone: '+1000000000',
              message: 'Interested in this property.',
              property_id: nil
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api_public/v1/contact' do
    post 'Creates a contact enquiry' do
      tags 'Contact'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :contact, in: :body, schema: {
        type: :object,
        properties: {
          contact: {
            type: :object,
            properties: {
              name: { type: :string },
              email: { type: :string },
              phone: { type: :string },
              subject: { type: :string },
              message: { type: :string }
            }
          },
          locale: { type: :string }
        }
      }

      response '201', 'contact created' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     contact_id: { type: :integer },
                     message_id: { type: :integer }
                   }
                 }
               }
        let(:contact) do
          {
            contact: {
              name: 'Swagger User',
              email: 'swagger@example.com',
              phone: '+1000000000',
              subject: 'General Enquiry',
              message: 'Hello from the API docs.'
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api_public/v1/auth/firebase' do
    post 'Authenticates via Firebase token' do
      tags 'Auth'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :auth, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string },
          verification_token: { type: :string }
        }
      }

      response '200', 'authenticated' do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     firebase_uid: { type: :string }
                   }
                 },
                 message: { type: :string }
               }
        let(:auth) { { token: 'valid_token' } }
        before do
          user = Pwb::User.create!(email: 'swagger@example.com', password: 'Password123!', website: test_website)
          allow_any_instance_of(Pwb::FirebaseAuthService).to receive(:call).and_return(user)
        end
        run_test!
      end

      response '401', 'invalid token' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }
        let(:auth) { { token: 'invalid_token' } }
        before do
          allow_any_instance_of(Pwb::FirebaseAuthService).to receive(:call).and_return(nil)
        end
        run_test!
      end

      response '400', 'missing token' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }
        let(:auth) { {} }
        run_test!
      end
    end
  end

  path '/api_public/v1/widgets/{widget_key}' do
    get 'Retrieves widget configuration and properties' do
      tags 'Widgets'
      produces 'application/json'
      parameter name: :widget_key, in: :path, type: :string
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'widget found' do
        schema type: :object,
               properties: {
                 config: {
                   type: :object,
                   properties: {
                     widget_key: { type: :string },
                     layout: { type: :string },
                     columns: { type: :integer },
                     max_properties: { type: :integer },
                     show_search: { type: :boolean },
                     show_filters: { type: :boolean },
                     show_pagination: { type: :boolean },
                     listing_type: { type: %i[string null] },
                     theme: { type: :object },
                     visible_fields: { type: :object }
                   }
                 },
                 properties: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       title: { type: %i[string null] },
                       url: { type: :string },
                       photo_url: { type: %i[string null] },
                       photo_count: { type: :integer },
                       price: { type: %i[string null] },
                       price_raw: { type: %i[integer null] },
                       currency: { type: %i[string null] },
                       bedrooms: { type: %i[integer null] },
                       bathrooms: { type: %i[number null] },
                       area: { type: %i[number null] },
                       area_unit: { type: %i[string null] },
                       location: { type: %i[string null] },
                       reference: { type: %i[string null] },
                       property_type: { type: %i[string null] },
                       for_sale: { type: :boolean },
                       for_rent: { type: :boolean },
                       highlighted: { type: :boolean }
                     }
                   }
                 },
                 total_count: { type: :integer },
                 website: {
                   type: :object,
                   properties: {
                     name: { type: :string },
                     currency: { type: :string },
                     area_unit: { type: :string }
                   }
                 }
               }
        let!(:widget_config) do
          Pwb::WidgetConfig.create!(
            website: test_website,
            name: 'Swagger Widget',
            widget_key: 'swagger-widget',
            layout: 'grid',
            columns: 3,
            max_properties: 12
          )
        end
        let(:widget_key) { widget_config.widget_key }
        run_test!
      end
    end
  end

  path '/api_public/v1/widgets/{widget_key}/properties' do
    get 'Retrieves widget properties' do
      tags 'Widgets'
      produces 'application/json'
      parameter name: :widget_key, in: :path, type: :string
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'properties found' do
        schema type: :object,
               properties: {
                 properties: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       title: { type: %i[string null] },
                       url: { type: :string },
                       photo_url: { type: %i[string null] },
                       photo_count: { type: :integer },
                       price: { type: %i[string null] },
                       price_raw: { type: %i[integer null] },
                       currency: { type: %i[string null] },
                       bedrooms: { type: %i[integer null] },
                       bathrooms: { type: %i[number null] },
                       area: { type: %i[number null] },
                       area_unit: { type: %i[string null] },
                       location: { type: %i[string null] },
                       reference: { type: %i[string null] },
                       property_type: { type: %i[string null] },
                       for_sale: { type: :boolean },
                       for_rent: { type: :boolean },
                       highlighted: { type: :boolean }
                     }
                   }
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     per_page: { type: :integer },
                     total_count: { type: :integer },
                     total_pages: { type: :integer }
                   }
                 }
               }
        let!(:widget_config) do
          Pwb::WidgetConfig.create!(
            website: test_website,
            name: 'Swagger Widget',
            widget_key: 'swagger-widget-props',
            layout: 'grid',
            columns: 3,
            max_properties: 12
          )
        end
        let(:widget_key) { widget_config.widget_key }
        run_test!
      end
    end
  end

  path '/api_public/v1/widgets/{widget_key}/impression' do
    post 'Tracks widget impression' do
      tags 'Widgets'
      parameter name: :widget_key, in: :path, type: :string

      response '200', 'impression tracked' do
        let!(:widget_config) do
          Pwb::WidgetConfig.create!(
            website: test_website,
            name: 'Swagger Widget',
            widget_key: 'swagger-widget-impression',
            layout: 'grid',
            columns: 3,
            max_properties: 12
          )
        end
        let(:widget_key) { widget_config.widget_key }
        run_test!
      end
    end
  end

  path '/api_public/v1/widgets/{widget_key}/click' do
    post 'Tracks widget click' do
      tags 'Widgets'
      parameter name: :widget_key, in: :path, type: :string

      response '200', 'click tracked' do
        let!(:widget_config) do
          Pwb::WidgetConfig.create!(
            website: test_website,
            name: 'Swagger Widget',
            widget_key: 'swagger-widget-click',
            layout: 'grid',
            columns: 3,
            max_properties: 12
          )
        end
        let(:widget_key) { widget_config.widget_key }
        run_test!
      end
    end
  end
end
