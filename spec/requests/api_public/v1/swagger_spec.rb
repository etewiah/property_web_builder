require 'swagger_helper'

RSpec.describe 'API Public V1', type: :request, openapi_spec: 'v1/api_public_swagger.yaml' do

  path '/api_public/v1/properties/{id}' do
    get 'Retrieves a property' do
      tags 'Properties'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string

      response '200', 'property found' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            title: { type: :string },
            description: { type: :string }
          },
          required: [ 'id', 'title' ]

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

      response '200', 'properties found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string }
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
            id: { type: :integer },
            slug: { type: :string },
            content: { type: :string }
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

      response '200', 'page found' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            slug: { type: :string }
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
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'translations found' do
        schema type: :object
        let(:locale) { 'en' }
        run_test!
      end
    end
  end

  path '/api_public/v1/links' do
    get 'Retrieves links' do
      tags 'Links'
      produces 'application/json'

      response '200', 'links found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              href: { type: :string },
              label: { type: :string }
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

      response '200', 'site details found' do
        schema type: :object,
          properties: {
            site_name: { type: :string },
            logo_url: { type: :string }
          }
        run_test!
      end
    end
  end

  path '/api_public/v1/select_values' do
    get 'Retrieves select values' do
      tags 'Select Values'
      produces 'application/json'

      response '200', 'select values found' do
        schema type: :object
        run_test!
      end
    end
  end
end
