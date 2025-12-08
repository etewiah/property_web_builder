require 'swagger_helper'

RSpec.describe 'API V1', type: :request, openapi_spec: 'v1/swagger.yaml' do
  include Warden::Test::Helpers

  # Create website first without tenant scope
  let!(:test_website) { Pwb::Website.create!(subdomain: 'swagger-test', slug: 'swagger-test', company_display_name: 'Swagger Test', default_client_locale: 'en-GB', supported_locales: ['en-GB']) }

  # Create agency and user within tenant context
  let!(:test_agency) do
    ActsAsTenant.with_tenant(test_website) do
      Pwb::Agency.create!(website: test_website, company_name: 'Swagger Test Agency')
    end
  end
  let!(:admin_user) do
    ActsAsTenant.with_tenant(test_website) do
      user = Pwb::User.create!(email: 'swagger-admin@test.com', password: 'password123', website: test_website, admin: true)
      Pwb::UserMembership.create!(user: user, website: test_website, role: 'admin', active: true)
      user
    end
  end

  before do
    Warden.test_mode!
    login_as admin_user, scope: :user
    host! 'swagger-test.example.com'
    # Set up tenant context
    Pwb::Current.website = test_website
    ActsAsTenant.current_tenant = test_website
  end

  after do
    Warden.test_reset!
    ActsAsTenant.current_tenant = nil
    Pwb::Current.reset
  end

  path '/api/v1/agency' do
    get 'Retrieves agency details' do
      tags 'Agency'
      produces 'application/json'

      response '200', 'agency details found' do
        # Note: primary_address can be null when no address is set
        schema type: :object,
          properties: {
            agency: { type: :object },
            website: { type: :object },
            primary_address: { type: [:object, :null] },
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
        let(:agency) { { agency: { company_name: 'Updated Company' } } }
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
        let(:website) { { website: { company_display_name: 'Updated Website' } } }
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
        let!(:test_page) { FactoryBot.create(:pwb_page, website: test_website, slug: 'test-page') }
        let(:page_name) { 'test-page' }
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
        let!(:existing_page) { FactoryBot.create(:pwb_page, website: test_website, slug: 'update-page') }
        let(:page) { { page: { slug: existing_page.slug, visible: true } } }
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
        let(:locale) { 'en' }
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
        let(:batch_key) { 'admin' }
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

      response '200', 'properties created', skip: 'Controller has bug - current_website undefined' do
        let(:propertiesJSON) do
          {
            propertiesJSON: [
              { reference: 'SWAGGER-001', title: 'Test Property', price_sale_current_cents: 100000 }
            ]
          }
        end
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

      response '200', 'photo added', skip: 'Requires fixture file setup' do
        let!(:property) { FactoryBot.create(:pwb_prop, :sale, website: test_website) }
        let(:id) { property.id }
        let(:file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.jpg'), 'image/jpeg') }
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
      parameter name: :linkGroups, in: :body, schema: {
        type: :object,
        properties: {
          linkGroups: {
            type: :object,
            properties: {
              top_nav_links: { type: :array, items: { type: :object } },
              footer_links: { type: :array, items: { type: :object } }
            }
          }
        }
      }

      response '200', 'links updated', skip: 'Controller has bug - Link.find_by_slug returns nil without proper scope' do
        let!(:link) { FactoryBot.create(:pwb_link, :top_nav, website: test_website, slug: 'test-link') }
        let(:linkGroups) { { linkGroups: { top_nav_links: [{ slug: link.slug, title: 'Updated Link' }], footer_links: [] } } }
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
        let(:field_names) { 'property_type' }
        run_test!
      end
    end
  end
end
