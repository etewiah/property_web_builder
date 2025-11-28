require 'swagger_helper'

RSpec.describe 'API Public V1', type: :request, openapi_spec: 'v1/api_public_swagger.yaml' do

  path '/api_public/v1/properties/{id}' do
    get 'Retrieves a property' do
      tags 'Properties'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'property found' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            title: { type: :string },
            description: { type: :string },
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
            count_bathrooms: { type: :integer },
            count_garages: { type: :integer },
            for_sale: { type: :boolean },
            for_rent: { type: :boolean }
          }

        let(:id) { FactoryBot.create(:pwb_prop, :sale).id }
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
      parameter name: :sale_or_rental, in: :query, type: :string, required: false
      parameter name: :currency, in: :query, type: :string, required: false
      parameter name: :for_sale_price_from, in: :query, type: :string, required: false
      parameter name: :for_sale_price_till, in: :query, type: :string, required: false
      parameter name: :for_rent_price_from, in: :query, type: :string, required: false
      parameter name: :for_rent_price_till, in: :query, type: :string, required: false
      parameter name: :bedrooms_from, in: :query, type: :string, required: false
      parameter name: :bathrooms_from, in: :query, type: :string, required: false
      parameter name: :property_type, in: :query, type: :string, required: false

      response '200', 'properties found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string },
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
            slug: { type: :string },
            link_path: { type: :string },
            visible: { type: :boolean },
            page_title: { type: :string },
            link_title: { type: :string },
            raw_html: { type: :string },
            show_in_top_nav: { type: :boolean },
            show_in_footer: { type: :boolean },
            page_contents: {
              type: :array,
              items: { type: :object }
            }
          }

        let(:id) { FactoryBot.create(:pwb_page).id }
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
            slug: { type: :string },
            link_path: { type: :string },
            visible: { type: :boolean },
            page_title: { type: :string },
            link_title: { type: :string },
            raw_html: { type: :string },
            show_in_top_nav: { type: :boolean },
            show_in_footer: { type: :boolean },
            page_contents: {
              type: :array,
              items: { type: :object }
            }
          }

        let(:slug) { FactoryBot.create(:pwb_page).slug }
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
      parameter name: :placement, in: :query, type: :string, required: false
      parameter name: :locale, in: :query, type: :string, required: false
      parameter name: :visible_only, in: :query, type: :boolean, required: false

      response '200', 'links found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              slug: { type: :string },
              link_path: { type: :string },
              visible: { type: :boolean },
              link_title: { type: :string },
              page_slug: { type: :string },
              placement: { type: :string },
              href_class: { type: :string },
              is_deletable: { type: :boolean }
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
            theme_name: { type: :string },
            default_currency: { type: :string },
            supported_locales: { type: :array, items: { type: :string } },
            social_media: { type: :object },
            agency: { type: :object },
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
end
