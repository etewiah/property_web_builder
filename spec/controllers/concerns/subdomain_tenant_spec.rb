# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubdomainTenant, type: :controller do
  controller(ActionController::Base) do
    include SubdomainTenant

    def index
      render json: {
        subdomain: Pwb::Current.website&.subdomain,
        tenant_id: ActsAsTenant.current_tenant&.id
      }
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
    Pwb::Current.reset
    ActsAsTenant.current_tenant = nil
  end

  after do
    Pwb::Current.reset
    ActsAsTenant.current_tenant = nil
  end

  it 'uses the X-Website-Slug header ahead of host resolution' do
    website1 = create(:pwb_website, slug: 'site-1', subdomain: 'tenant1')
    website2 = create(:pwb_website, slug: 'site-2', subdomain: 'tenant2')

    request.host = 'tenant1.localhost'
    allow(controller).to receive(:website_from_slug_header).and_return(website2)

    get :index

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['subdomain']).to eq('tenant2')
    expect(response.parsed_body['tenant_id']).to eq(website2.id)
  end

  it 'does not fall back to the first website for unknown hosts' do
    create(:pwb_website, slug: 'site-1', subdomain: 'tenant1')

    request.host = 'unknown.example.com'

    get :index

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['subdomain']).to be_nil
    expect(response.parsed_body['tenant_id']).to be_nil
  end

  it 'uses the explicit default website for localhost root requests' do
    default_site = create(:pwb_website, slug: 'default-site', subdomain: 'default')

    request.host = 'localhost'

    get :index

    expect(response.parsed_body['subdomain']).to eq('default')
    expect(response.parsed_body['tenant_id']).to eq(default_site.id)
  end

  it 'does not use an arbitrary website on localhost when no default website exists' do
    create(:pwb_website, slug: 'other-site', subdomain: 'other')

    request.host = 'localhost'

    get :index

    expect(response.parsed_body['subdomain']).to be_nil
    expect(response.parsed_body['tenant_id']).to be_nil
  end
end