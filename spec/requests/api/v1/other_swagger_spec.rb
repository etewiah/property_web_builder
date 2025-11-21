require 'swagger_helper'

RSpec.describe 'api/v1/translations', type: :request do
  path '/api/v1/translations/list/{locale}' do
    parameter name: 'locale', in: :path, type: :string, description: 'Locale code (e.g., en, es)'

    get('list translations for locale') do
      tags 'Translations'
      produces 'application/json'

      let(:locale) { 'en' }

      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/api/v1/translations/batch/{batch_key}' do
    parameter name: 'batch_key', in: :path, type: :string, description: 'Batch key'

    get('get translations by batch key') do
      tags 'Translations'
      produces 'application/json'

      let(:batch_key) { 'person-titles' }

      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/api/v1/translations' do
    post('create translation') do
      tags 'Translations'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :translation, in: :body, schema: {
        type: :object,
        properties: {
          key: { type: :string },
          value: { type: :string },
          locale: { type: :string }
        }
      }

      response(200, 'created') do
        let(:translation) { { key: 'test.key', value: 'Test Value', locale: 'en' } }
        run_test!
      end
    end
  end

  path '/api/v1/translations/create_for_locale' do
    post('create translation for locale') do
      tags 'Translations'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :data, in: :body, schema: {
        type: :object,
        properties: {
          key: { type: :string },
          locale: { type: :string },
          value: { type: :string }
        }
      }

      response(200, 'created') do
        let(:data) { { key: 'test.key', locale: 'en', value: 'Test' } }
        run_test!
      end
    end
  end

  path '/api/v1/translations/{id}/update_for_locale' do
    parameter name: 'id', in: :path, type: :string, description: 'Translation ID'

    put('update translation for locale') do
      tags 'Translations'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :data, in: :body, schema: {
        type: :object,
        properties: {
          locale: { type: :string },
          value: { type: :string }
        }
      }

      let(:id) { '1' }

      response(200, 'updated') do
        let(:data) { { locale: 'en', value: 'Updated Value' } }
        run_test!
      end
    end
  end

  path '/api/v1/translations/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'Translation ID'

    delete('delete translation') do
      tags 'Translations'

      let(:id) { '1' }

      response(200, 'deleted') do
        run_test!
      end
    end
  end
end

RSpec.describe 'api/v1/links', type: :request do
  path '/api/v1/links' do
    get('list links') do
      tags 'Links'
      produces 'application/json'
      parameter name: :placement, in: :query, type: :string, required: false, description: 'Link placement (top_nav, footer, etc.)'

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

    put('bulk update links') do
      tags 'Links'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :links, in: :body, schema: {
        type: :array,
        items: {
          type: :object,
          properties: {
            id: { type: :integer },
            title: { type: :string },
            url: { type: :string },
            placement: { type: :string },
            visible: { type: :boolean },
            position: { type: :integer }
          }
        }
      }

      response(200, 'updated') do
        let(:links) { [] }
        run_test!
      end
    end
  end
end

RSpec.describe 'api/v1/web_contents', type: :request do
  path '/api/v1/web_contents' do
    get('list web contents') do
      tags 'Web Contents'
      produces 'application/vnd.api+json'

      response(200, 'successful') do
        run_test!
      end
    end

    post('create web content') do
      tags 'Web Contents'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      
      parameter name: :web_content, in: :body, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'web_contents' },
              attributes: {
                type: :object,
                properties: {
                  content_tag: { type: :string },
                  value: { type: :string }
                }
              }
            }
          }
        }
      }

      response(201, 'created') do
        let(:web_content) { { data: { type: 'web_contents', attributes: { content_tag: 'test', value: 'test' } } } }
        run_test!
      end
    end
  end

  path '/api/v1/web_contents/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'Web content ID'

    get('show web content') do
      tags 'Web Contents'
      produces 'application/vnd.api+json'

      let(:id) { '1' }

      response(200, 'successful') do
        run_test!
      end
    end

    patch('update web content') do
      tags 'Web Contents'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      
      parameter name: :web_content, in: :body, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string },
              attributes: {
                type: :object,
                properties: {
                  value: { type: :string }
                }
              }
            }
          }
        }
      }

      let(:id) { '1' }

      response(200, 'updated') do
        let(:web_content) { { data: { id: id, type: 'web_contents', attributes: { value: 'updated' } } } }
        run_test!
      end
    end
  end

  path '/api/v1/web_contents/photo/{tag}' do
    parameter name: 'tag', in: :path, type: :string, description: 'Content tag'

    post('create web content with photo') do
      tags 'Web Contents'
      consumes 'multipart/form-data'
      
      parameter name: :photo, in: :formData, type: :file, description: 'Photo file'

      let(:tag) { 'carousel' }

      response(200, 'created') do
        run_test!
      end
    end
  end
end

RSpec.describe 'api/v1/contacts', type: :request do
  path '/api/v1/contacts' do
    get('list contacts') do
      tags 'Contacts'
      produces 'application/json'

      response(200, 'successful') do
        run_test!
      end
    end

    post('create contact') do
      tags 'Contacts'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :contact, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          email: { type: :string, format: :email },
          phone: { type: :string },
          message: { type: :string }
        },
        required: ['name', 'email']
      }

      response(201, 'created') do
        let(:contact) { { name: 'John Doe', email: 'john@example.com' } }
        run_test!
      end
    end
  end

  path '/api/v1/contacts/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'Contact ID'

    get('show contact') do
      tags 'Contacts'
      produces 'application/json'

      let(:id) { '1' }

      response(200, 'successful') do
        run_test!
      end
    end

    patch('update contact') do
      tags 'Contacts'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :contact, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          email: { type: :string },
          phone: { type: :string }
        }
      }

      let(:id) { '1' }

      response(200, 'updated') do
        let(:contact) { { name: 'Updated Name' } }
        run_test!
      end
    end

    delete('delete contact') do
      tags 'Contacts'

      let(:id) { '1' }

      response(204, 'deleted') do
        run_test!
      end
    end
  end
end

RSpec.describe 'api/v1/other', type: :request do
  path '/api/v1/themes' do
    get('list themes') do
      tags 'Other'
      produces 'application/json'

      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/api/v1/select_values' do
    get('get select values') do
      tags 'Other'
      produces 'application/json'
      parameter name: :field_names, in: :query, type: :string, required: false, description: 'Comma-separated field names'

      response(200, 'successful') do
        run_test!
      end
    end
  end
end
