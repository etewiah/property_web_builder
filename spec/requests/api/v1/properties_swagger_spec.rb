require 'swagger_helper'

RSpec.describe 'api/v1/properties', type: :request do

  path '/api/v1/properties' do

    get('list properties') do
      tags 'Properties'
      produces 'application/vnd.api+json'
      
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
  end

  path '/api/v1/properties/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'

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
  end
end
