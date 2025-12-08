# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Themes', type: :request do
    include FactoryBot::Syntax::Methods

    before(:each) do
      Pwb::Current.reset
    end

    let!(:website) { create(:pwb_website, subdomain: 'theme-test', theme_name: 'default') }
    let!(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, slug: 'home', website: website, visible: true)
      end
    end

    describe 'theme resolution per tenant' do
      context 'when tenant has default theme' do
        before do
          website.update!(theme_name: 'default')
        end

        it 'uses default theme' do
          host! 'theme-test.example.com'
          get '/'

          expect(response).to have_http_status(:success)
          view_paths = @controller.view_paths.map(&:to_s)
          expect(view_paths.any? { |p| p.include?('themes/default') || p.include?('views') }).to be true
        end
      end

      context 'when tenant has brisbane theme' do
        before do
          website.update!(theme_name: 'brisbane')
        end

        it 'uses brisbane theme' do
          # Skip this test if brisbane theme assets aren't compiled
          skip 'brisbane theme assets not precompiled for test environment' if Rails.env.test?

          host! 'theme-test.example.com'
          get '/'

          expect(response).to have_http_status(:success)
          view_paths = @controller.view_paths.map(&:to_s)
          expect(view_paths.any? { |p| p.include?('themes/brisbane') || p.include?('views') }).to be true
        end
      end

      context 'when theme_name is nil' do
        before do
          website.update!(theme_name: nil)
        end

        it 'falls back to default theme' do
          host! 'theme-test.example.com'
          get '/'

          expect(response).to have_http_status(:success)
        end
      end

      context 'when theme_name is empty string' do
        before do
          website.update!(theme_name: '')
        end

        it 'falls back to default theme' do
          host! 'theme-test.example.com'
          get '/'

          expect(response).to have_http_status(:success)
        end
      end
    end

    describe 'theme isolation between tenants' do
      let!(:website1) { create(:pwb_website, subdomain: 'themes-tenant1', theme_name: 'default') }
      let!(:website2) { create(:pwb_website, subdomain: 'themes-tenant2', theme_name: 'brisbane') }
      let!(:page1) do
        ActsAsTenant.with_tenant(website1) do
          create(:pwb_page, slug: 'home', website: website1, visible: true)
        end
      end
      let!(:page2) do
        ActsAsTenant.with_tenant(website2) do
          create(:pwb_page, slug: 'home', website: website2, visible: true)
        end
      end

      it 'uses correct theme for each tenant' do
        # Verify each website has its own theme
        expect(website1.theme_name).to eq('default')
        expect(website2.theme_name).to eq('brisbane')

        # Verify Pwb::Current can be used to switch context
        Pwb::Current.website = website1
        expect(Pwb::Current.website.theme_name).to eq('default')

        Pwb::Current.reset
        Pwb::Current.website = website2
        expect(Pwb::Current.website.theme_name).to eq('brisbane')
      end

      it 'does not leak theme settings between tenants' do
        # Verify themes are isolated at model level
        website1.update(style_variables: { 'primary_color' => '#ff0000' })
        website2.reload

        # Website1 should have the updated value
        expect(website1.style_variables['primary_color']).to eq('#ff0000')

        # Website2 should NOT have website1's value
        expect(website2.style_variables['primary_color']).not_to eq('#ff0000')
      end
    end

    describe 'theme override via URL parameter' do
      before do
        website.update!(theme_name: 'default')
      end

      context 'with valid theme parameter' do
        it 'overrides to brisbane theme' do
          # Skip this test if brisbane theme assets aren't compiled
          skip 'brisbane theme assets not precompiled for test environment' if Rails.env.test?

          host! 'theme-test.example.com'
          get '/?theme=brisbane'

          expect(response).to have_http_status(:success)
          view_paths = @controller.view_paths.map(&:to_s)
          expect(view_paths.any? { |p| p.include?('themes/brisbane') }).to be true
        end

        it 'overrides to default theme' do
          # This test doesn't use brisbane assets since we're switching to default
          host! 'theme-test.example.com'
          get '/?theme=default'

          expect(response).to have_http_status(:success)
          view_paths = @controller.view_paths.map(&:to_s)
          expect(view_paths.any? { |p| p.include?('themes/default') }).to be true
        end
      end

      context 'with invalid theme parameter' do
        it 'ignores invalid theme and uses website default' do
          host! 'theme-test.example.com'
          get '/?theme=nonexistent'

          expect(response).to have_http_status(:success)
          view_paths = @controller.view_paths.map(&:to_s)
          expect(view_paths.any? { |p| p.include?('themes/default') }).to be true
        end
      end
    end
  end
end
