require 'swagger_helper'

RSpec.describe 'api/v1/properties', type: :request do

  path '/api/v1/properties' do
    get('list properties') do
      tags 'Properties'
      produces 'application/vnd.api+json'
      parameter name: 'filter[for_sale]', in: :query, type: :boolean, required: false, description: 'Filter properties for sale'
      parameter name: 'filter[for_rent]', in: :query, type: :boolean, required: false, description: 'Filter properties for rent'
      parameter name: 'page[number]', in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: 'page[size]', in: :query, type: :integer, required: false, description: 'Page size'
      
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/vnd.api+json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end

    post('create property') do
      tags 'Properties'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      
      parameter name: :property, in: :body, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'properties' },
              attributes: {
                type: :object,
                properties: {
                  reference: { type: :string },
                  title: { type: :string },
                  description: { type: :string },
                  for_sale: { type: :boolean },
                  for_rent: { type: :boolean },
                  price_sale_current_cents: { type: :integer },
                  price_sale_current_currency: { type: :string },
                  price_rental_monthly_current_cents: { type: :integer },
                  visible: { type: :boolean }
                }
              }
            },
            required: ['type', 'attributes']
          }
        },
        required: ['data']
      }

      response(201, 'created') do
        let(:property) { { data: { type: 'properties', attributes: { visible: true, for_sale: true } } } }
        run_test!
      end
    end
  end

  path '/api/v1/properties/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'Property ID'

    get('show property') do
      tags 'Properties'
      produces 'application/vnd.api+json'
      
      let!(:property) { Pwb::Prop.create!(visible: true, for_sale: true, price_sale_current_cents: 100000, price_sale_current_currency: "EUR") }
      let(:id) { property.id }

      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/vnd.api+json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
      
      response(404, 'not found') do
        let(:id) { 'invalid' }
        run_test!
      end
    end

    patch('update property') do
      tags 'Properties'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      
      parameter name: :property, in: :body, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string, example: 'properties' },
              attributes: {
                type: :object,
                properties: {
                  title: { type: :string },
                  description: { type: :string },
                  visible: { type: :boolean }
                }
              }
            }
          }
        }
      }

      let!(:prop) { Pwb::Prop.create!(visible: true, for_sale: true, price_sale_current_cents: 100000, price_sale_current_currency: "EUR") }
      let(:id) { prop.id }

      response(200, 'updated') do
        let(:property) { { data: { id: id, type: 'properties', attributes: { title: 'Updated Title' } } } }
        run_test!
      end
    end

    delete('delete property') do
      tags 'Properties'
      
      let!(:prop) { Pwb::Prop.create!(visible: true, for_sale: true, price_sale_current_cents: 100000, price_sale_current_currency: "EUR") }
      let(:id) { prop.id }

      response(204, 'deleted') do
        run_test!
      end
    end
  end

  path '/api/v1/properties/bulk_create' do
    post('bulk create properties') do
      tags 'Properties'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :data, in: :body, schema: {
        type: :object,
        properties: {
          propertiesJSON: { type: :string, description: 'JSON string of properties array' }
        },
        required: ['propertiesJSON']
      }

      response(200, 'created') do
        let(:data) { { propertiesJSON: '[]' } }
        run_test!
      end
    end
  end

  path '/api/v1/properties/update_extras' do
    post('update property extras/features') do
      tags 'Properties'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :data, in: :body, schema: {
        type: :object,
        properties: {
          id: { type: :integer },
          extras: { 
            type: :object,
            description: 'Features/extras as key-value pairs'
          }
        },
        required: ['id', 'extras']
      }

      response(200, 'updated') do
        run_test!
      end
    end
  end

  path '/api/v1/properties/{id}/photo' do
    parameter name: 'id', in: :path, type: :string, description: 'Property ID'

    post('add photo to property') do
      tags 'Properties'
      consumes 'multipart/form-data'
      
      parameter name: :photo, in: :formData, type: :file, description: 'Photo file'

      let!(:property) { Pwb::Prop.create!(visible: true, for_sale: true, price_sale_current_cents: 100000, price_sale_current_currency: "EUR") }
      let(:id) { property.id }

      response(200, 'photo added') do
        run_test!
      end
    end
  end

  path '/api/v1/properties/{id}/photo_from_url' do
    parameter name: 'id', in: :path, type: :string, description: 'Property ID'

    post('add photo from URL') do
      tags 'Properties'
      consumes 'application/json'
      
      parameter name: :data, in: :body, schema: {
        type: :object,
        properties: {
          photo_url: { type: :string, format: :uri }
        },
        required: ['photo_url']
      }

      let!(:property) { Pwb::Prop.create!(visible: true, for_sale: true, price_sale_current_cents: 100000, price_sale_current_currency: "EUR") }
      let(:id) { property.id }

      response(200, 'photo added') do
        run_test!
      end
    end
  end

  path '/api/v1/properties/photos/{photo_id}' do
    parameter name: 'photo_id', in: :path, type: :string, description: 'Photo ID'

    delete('delete property photo') do
      tags 'Properties'

      let(:photo_id) { '1' }

      response(200, 'photo deleted') do
        run_test!
      end
    end
  end
end
