# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe NavigationHelper, type: :helper do
    let(:website) { create(:pwb_website, subdomain: 'nav-test') }

    before do
      assign(:current_website, website)
      ActsAsTenant.current_tenant = website
    end

    after do
      ActsAsTenant.current_tenant = nil
    end

    describe '#render_top_navigation_links' do
      context 'with navigation links' do
        let!(:page_about) { create(:pwb_page, website: website, slug: 'about') }
        let!(:page_contact) { create(:pwb_page, website: website, slug: 'contact') }

        let!(:link_a) do
          create(:pwb_link, :top_nav, website: website, page_slug: 'about', visible: true, sort_order: 1)
        end

        let!(:link_b) do
          create(:pwb_link, :top_nav, website: website, page_slug: 'contact', visible: true, sort_order: 2)
        end

        it 'returns HTML string' do
          result = helper.render_top_navigation_links
          expect(result).to be_a(String)
          expect(result).to be_html_safe
        end
      end

      context 'with no links' do
        it 'returns empty string' do
          website.links.destroy_all
          result = helper.render_top_navigation_links
          expect(result).to eq('')
        end
      end
    end

    describe '#render_footer_links' do
      context 'with footer links' do
        let!(:page_terms) { create(:pwb_page, website: website, slug: 'terms') }

        let!(:footer_link) do
          create(:pwb_link, :footer, website: website, page_slug: 'terms', visible: true)
        end

        it 'returns HTML string' do
          result = helper.render_footer_links
          expect(result).to be_a(String)
          expect(result).to be_html_safe
        end
      end
    end

    describe '#top_nav_link_for' do
      let(:link) do
        Pwb::Link.new(
          website: website,
          page_slug: 'about',
          link_url: 'https://example.com/about',
          placement: :top_nav
        )
      end

      it 'generates link HTML with external URL' do
        result = helper.top_nav_link_for(link)
        expect(result).to include('li')
        expect(result).to include('https://example.com/about')
      end
    end

    describe '#footer_link_for' do
      let(:link) do
        Pwb::Link.new(
          website: website,
          page_slug: 'terms',
          link_url: 'https://example.com/terms',
          placement: :footer
        )
      end

      it 'generates link HTML with external URL' do
        result = helper.footer_link_for(link)
        expect(result).to include('https://example.com/terms')
      end

      it 'returns empty string for invalid link_path' do
        link = Pwb::Link.new(
          website: website,
          link_path: 'invalid_path_that_does_not_exist',
          link_url: nil,
          placement: :footer
        )
        result = helper.footer_link_for(link)
        expect(result).to eq('')
      end
    end

    describe '#render_omniauth_sign_in' do
      context 'when provider credentials are not configured' do
        before do
          allow(Rails.application.credentials).to receive(:[]).with('google_app_id').and_return(nil)
          allow(Rails.application.credentials).to receive(:[]).with('google_app_secret').and_return(nil)
        end

        it 'returns nil' do
          result = helper.render_omniauth_sign_in(:google)
          expect(result).to be_nil
        end
      end
    end
  end
end
