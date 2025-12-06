require "rails_helper"

module Pwb
  RSpec.describe PagesController, type: :controller do
    routes { Rails.application.routes }

    let(:website) { create(:pwb_website, subdomain: 'test-pages') }

    before do
      # Set up the current website for requests
      allow(controller).to receive(:current_website).and_return(website)
      controller.instance_variable_set(:@current_website, website)
    end

    describe "GET #show_page" do
      let!(:page) do
        # Use Pwb::Page directly to avoid tenant requirement
        Pwb::Page.create!(slug: 'test-page', website: website)
      end
      let!(:link) do
        Pwb::Link.create!(page_slug: page.slug, website: website, placement: :top_nav, link_title: 'Test')
      end

      it "renders the show template for existing page" do
        get :show_page, params: { page_slug: 'test-page' }
        expect(response).to render_template("pwb/pages/show")
      end

      it "falls back to home page when page not found" do
        home_page = Pwb::Page.create!(slug: 'home', website: website)
        Pwb::Link.create!(page_slug: home_page.slug, website: website, placement: :top_nav, link_title: 'Home')
        get :show_page, params: { page_slug: 'nonexistent' }
        expect(response).to render_template("pwb/pages/show")
        expect(assigns(:page).slug).to eq('home')
      end
    end

    describe "GET #show_page_part" do
      let!(:page) do
        Pwb::Page.create!(slug: 'about-us', website: website)
      end
      let!(:link) do
        Pwb::Link.create!(page_slug: page.slug, website: website, placement: :top_nav, link_title: 'About Us')
      end
      let!(:content) do
        Pwb::Content.create!(
          page_part_key: 'our_story',
          raw: '<h2>Our Story</h2><p>Test content</p>',
          website: website
        )
      end
      let!(:page_content) do
        Pwb::PageContent.create!(
          page: page,
          content: content,
          page_part_key: 'our_story',
          visible_on_page: true,
          website: website
        )
      end

      context "with valid page and page_part" do
        it "renders the page part template" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'our_story' }
          expect(response).to be_successful
          expect(response).to render_template("pwb/pages/show_page_part")
        end

        it "assigns the correct page" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'our_story' }
          expect(assigns(:page)).to eq(page)
        end

        it "assigns the correct page_content" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'our_story' }
          expect(assigns(:page_content)).to eq(page_content)
        end

        it "assigns the content HTML" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'our_story' }
          expect(assigns(:content_html)).to include('Our Story')
        end

        it "uses the page_part layout" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'our_story' }
          expect(response).to render_template(layout: 'pwb/page_part')
        end
      end

      context "with nonexistent page" do
        it "returns not found" do
          get :show_page_part, params: { page_slug: 'nonexistent', page_part_key: 'our_story' }
          expect(response).to have_http_status(:not_found)
        end

        it "returns error message" do
          get :show_page_part, params: { page_slug: 'nonexistent', page_part_key: 'our_story' }
          expect(response.body).to include('Page not found')
        end
      end

      context "with nonexistent page_part" do
        it "returns not found" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'nonexistent_part' }
          expect(response).to have_http_status(:not_found)
        end

        it "returns error message" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'nonexistent_part' }
          expect(response.body).to include('Page part not found')
        end
      end

      context "with hidden page_part" do
        before do
          page_content.update!(visible_on_page: false)
        end

        it "returns not found for hidden parts" do
          get :show_page_part, params: { page_slug: 'about-us', page_part_key: 'our_story' }
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
