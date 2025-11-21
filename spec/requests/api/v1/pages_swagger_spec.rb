require 'swagger_helper'

RSpec.describe 'api/v1/pages', type: :request do

  path '/api/v1/pages/{page_name}' do
    parameter name: 'page_name', in: :path, type: :string, description: 'Page slug/name'

    get('show page') do
      tags 'Pages'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: false, description: 'Locale code'

      let(:page_name) { 'home' }

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

  path '/api/v1/pages' do
    put('update page') do
      tags 'Pages'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :page, in: :body, schema: {
        type: :object,
        properties: {
          id: { type: :integer },
          page_slug: { type: :string },
          visible: { type: :boolean },
          page_title: { type: :string }
        }
      }

      response(200, 'updated') do
        let(:page) { { page_slug: 'home', visible: true } }
        run_test!
      end
    end
  end

  path '/api/v1/pages/page_part_visibility' do
    put('update page part visibility') do
      tags 'Pages'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :data, in: :body, schema: {
        type: :object,
        properties: {
          page_slug: { type: :string },
          page_part_key: { type: :string },
          visible: { type: :boolean }
        },
        required: ['page_slug', 'page_part_key', 'visible']
      }

      response(200, 'updated') do
        let(:data) { { page_slug: 'home', page_part_key: 'hero', visible: true } }
        run_test!
      end
    end
  end

  path '/api/v1/pages/page_fragment' do
    put('save page fragment') do
      tags 'Pages'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :data, in: :body, schema: {
        type: :object,
        properties: {
          page_slug: { type: :string },
          fragment_key: { type: :string },
          content: { type: :string }
        }
      }

      response(200, 'saved') do
        let(:data) { { page_slug: 'home', fragment_key: 'header', content: 'Welcome' } }
        run_test!
      end
    end
  end

  path '/api/v1/pages/photos/{page_slug}/{page_part_key}/{block_label}' do
    parameter name: 'page_slug', in: :path, type: :string, description: 'Page slug'
    parameter name: 'page_part_key', in: :path, type: :string, description: 'Page part key'
    parameter name: 'block_label', in: :path, type: :string, description: 'Block label'

    post('set page photo') do
      tags 'Pages'
      consumes 'multipart/form-data'
      
      parameter name: :photo, in: :formData, type: :file, description: 'Photo file'

      let(:page_slug) { 'home' }
      let(:page_part_key) { 'hero' }
      let(:block_label) { 'background' }

      response(200, 'photo set') do
        run_test!
      end
    end
  end
end
