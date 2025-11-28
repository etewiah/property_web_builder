require 'swagger_helper'

RSpec.describe 'API V1', type: :request, openapi_spec: 'v1/swagger.yaml' do

  path '/api/v1/agency' do
    get 'Retrieves agency details' do
      tags 'Agency'
      produces 'application/json'

      response '200', 'agency details found' do
        schema type: :object,
          properties: {
            agency: { type: :object },
            website: { type: :object },
            primary_address: { type: :object },
            setup: { type: :object }
          }
        run_test!
      end
    end

    put 'Updates agency details' do
      tags 'Agency'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :agency, in: :body, schema: {
        type: :object,
        properties: {
          agency: {
            type: :object,
            properties: {
              company_name: { type: :string },
              display_name: { type: :string },
              email_primary: { type: :string },
              phone_number_primary: { type: :string },
              social_media: { type: :object }
            }
          }
        }
      }

      response '200', 'agency updated' do
        run_test!
      end
    end
  end

  path '/api/v1/website' do
    put 'Updates website details' do
      tags 'Website'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :website, in: :body, schema: {
        type: :object,
        properties: {
          website: {
            type: :object,
            properties: {
              company_name: { type: :string },
              display_name: { type: :string },
              theme_name: { type: :string },
              default_currency: { type: :string },
              social_media: { type: :object }
            }
          }
        }
      }

      response '200', 'website updated' do
        run_test!
      end
    end
  end

  path '/api/v1/pages/{page_name}' do
    get 'Retrieves a page' do
      tags 'Pages'
      produces 'application/json'
      parameter name: :page_name, in: :path, type: :string

      response '200', 'page found' do
        run_test!
      end
    end
  end

  path '/api/v1/pages' do
    put 'Updates a page' do
      tags 'Pages'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :page, in: :body, schema: {
        type: :object,
        properties: {
          page: {
            type: :object,
            properties: {
              slug: { type: :string },
              visible: { type: :boolean }
            }
          }
        }
      }

      response '200', 'page updated' do
        run_test!
      end
    end
  end

  path '/api/v1/translations/list/{locale}' do
    get 'Retrieves translations list' do
      tags 'Translations'
      produces 'application/json'
      parameter name: :locale, in: :path, type: :string

      response '200', 'translations list found' do
        run_test!
      end
    end
  end

  path '/api/v1/translations/batch/{batch_key}' do
    get 'Retrieves translations by batch' do
      tags 'Translations'
      produces 'application/json'
      parameter name: :batch_key, in: :path, type: :string

      response '200', 'translations batch found' do
        run_test!
      end
    end
  end

  path '/api/v1/properties/bulk_create' do
    post 'Bulk creates properties' do
      tags 'Properties'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :propertiesJSON, in: :body, schema: {
        type: :object,
        properties: {
          propertiesJSON: {
            type: :array,
            items: {
              type: :object,
              properties: {
                reference: { type: :string },
                title: { type: :string },
                price_sale_current_cents: { type: :integer }
              }
            }
          }
        }
      }

      response '200', 'properties created' do
        run_test!
      end
    end
  end

  path '/api/v1/properties/{id}/photo' do
    post 'Adds a photo to a property' do
      tags 'Properties'
      consumes 'multipart/form-data'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :file, in: :formData, type: :file

      response '200', 'photo added' do
        run_test!
      end
    end
  end

  path '/api/v1/web-contents' do
    get 'Retrieves web contents' do
      tags 'Web Contents'
      produces 'application/json'

      response '200', 'web contents found' do
        run_test!
      end
    end
  end

  path '/api/v1/links' do
    get 'Retrieves links' do
      tags 'Links'
      produces 'application/json'

      response '200', 'links found' do
        run_test!
      end
    end

    put 'Bulk updates links' do
      tags 'Links'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :links, in: :body, schema: {
        type: :array,
        items: { type: :object }
      }

      response '200', 'links updated' do
        run_test!
      end
    end
  end

  path '/api/v1/themes' do
    get 'Retrieves themes' do
      tags 'Themes'
      produces 'application/json'

      response '200', 'themes found' do
        run_test!
      end
    end
  end

  path '/api/v1/mls' do
    get 'Retrieves MLS info' do
      tags 'MLS'
      produces 'application/json'

      response '200', 'mls info found' do
        run_test!
      end
    end
  end

  path '/api/v1/select_values' do
    get 'Retrieves select values' do
      tags 'Select Values'
      produces 'application/json'
      parameter name: :field_names, in: :query, type: :string

      response '200', 'select values found' do
        run_test!
      end
    end
  end
end
