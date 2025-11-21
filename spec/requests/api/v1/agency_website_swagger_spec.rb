require 'swagger_helper'

RSpec.describe 'api/v1/agency', type: :request do

  path '/api/v1/agency' do
    get('get agency details') do
      tags 'Agency'
      produces 'application/json'
      
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end

    put('update agency') do
      tags 'Agency'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :agency, in: :body, schema: {
        type: :object,
        properties: {
          company_name: { type: :string },
          display_name: { type: :string },
          email_primary: { type: :string, format: :email },
          phone_number_primary: { type: :string },
          phone_number_mobile: { type: :string }
        }
      }

      response(200, 'updated') do
        let(:agency) { { company_name: 'Test Agency' } }
        run_test!
      end
    end
  end

  path '/api/v1/master_address' do
    put('update master address') do
      tags 'Agency'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :address, in: :body, schema: {
        type: :object,
        properties: {
          street_address: { type: :string },
          city: { type: :string },
          region: { type: :string },
          postal_code: { type: :string },
          country: { type: :string },
          latitude: { type: :number },
          longitude: { type: :number }
        }
      }

      response(200, 'updated') do
        let(:address) { { city: 'Test City' } }
        run_test!
      end
    end
  end

  path '/api/v1/infos' do
    get('get agency and website info') do
      tags 'Agency'
      produces 'application/json'
      
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end
end

RSpec.describe 'api/v1/website', type: :request do

  path '/api/v1/website' do
    put('update website settings') do
      tags 'Website'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :website, in: :body, schema: {
        type: :object,
        properties: {
          company_display_name: { type: :string },
          theme_name: { type: :string },
          supported_locales: { 
            type: :array,
            items: { type: :string }
          },
          configuration: { 
            type: :object,
            description: 'Website configuration as key-value pairs'
          }
        }
      }

      response(200, 'updated') do
        let(:website) { { company_display_name: 'Test Website' } }
        run_test!
      end
    end
  end
end
