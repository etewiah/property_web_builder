# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::LocalizedPages", type: :request do
  let!(:website) do
    FactoryBot.create(:pwb_website,
      subdomain: "localized-pages-test",
      supported_locales: %w[en es fr],
      default_client_locale: "en"
    )
  end

  let!(:page) do
    ActsAsTenant.with_tenant(website) do
      page = FactoryBot.create(:pwb_page, slug: "about-us", website: website, visible: true)
      # Set up Mobility translations for the page
      Mobility.with_locale(:en) do
        page.page_title = "About Our Company"
        page.seo_title = "About Us - Best Real Estate"
        page.meta_description = "Learn more about our real estate company and services."
        page.meta_keywords = "real estate, about us, company"
      end
      Mobility.with_locale(:es) do
        page.page_title = "Sobre Nuestra Empresa"
        page.seo_title = "Sobre Nosotros - Mejor Inmobiliaria"
        page.meta_description = "Conozca más sobre nuestra empresa inmobiliaria y servicios."
        page.meta_keywords = "inmobiliaria, sobre nosotros, empresa"
      end
      Mobility.with_locale(:fr) do
        page.page_title = "À Propos de Notre Entreprise"
        page.seo_title = "À Propos - Meilleur Immobilier"
        page.meta_description = "En savoir plus sur notre entreprise immobilière et nos services."
        page.meta_keywords = "immobilier, à propos, entreprise"
      end
      page.save!
      page
    end
  end

  before(:each) do
    Pwb::Current.reset
    Pwb::Current.website = website
    ActsAsTenant.current_tenant = website
    host! "#{website.subdomain}.example.com"
  end

  after(:each) do
    ActsAsTenant.current_tenant = nil
    Pwb::Current.reset
  end

  describe "GET /api_public/v1/:locale/localized_page/by_slug/:page_slug" do
    context "with English locale" do
      it "returns page with English translations" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        expect(response).to have_http_status(200)
        json = response.parsed_body

        expect(json["id"]).to eq(page.id)
        expect(json["slug"]).to eq("about-us")
        expect(json["title"]).to eq("About Us - Best Real Estate")
        expect(json["meta_description"]).to eq("Learn more about our real estate company and services.")
        expect(json["meta_keywords"]).to eq("real estate, about us, company")
      end
    end

    context "with Spanish locale" do
      it "returns page with Spanish translations" do
        get "/api_public/v1/es/localized_page/by_slug/about-us"

        expect(response).to have_http_status(200)
        json = response.parsed_body

        expect(json["title"]).to eq("Sobre Nosotros - Mejor Inmobiliaria")
        expect(json["meta_description"]).to eq("Conozca más sobre nuestra empresa inmobiliaria y servicios.")
        expect(json["meta_keywords"]).to eq("inmobiliaria, sobre nosotros, empresa")
      end

      it "includes locale-specific canonical URL" do
        get "/api_public/v1/es/localized_page/by_slug/about-us"

        json = response.parsed_body
        expect(json["canonical_url"]).to include("/es/p/about-us")
      end
    end

    context "with French locale" do
      it "returns page with French translations" do
        get "/api_public/v1/fr/localized_page/by_slug/about-us"

        expect(response).to have_http_status(200)
        json = response.parsed_body

        expect(json["title"]).to eq("À Propos - Meilleur Immobilier")
        expect(json["meta_description"]).to eq("En savoir plus sur notre entreprise immobilière et nos services.")
        expect(json["meta_keywords"]).to eq("immobilier, à propos, entreprise")
      end
    end

    describe "canonical URL generation" do
      it "generates canonical URL without locale prefix for default locale" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        # Default locale (en) should not have locale prefix
        expect(json["canonical_url"]).to match(%r{/p/about-us$})
        expect(json["canonical_url"]).not_to include("/en/")
      end

      it "generates canonical URL with locale prefix for non-default locales" do
        get "/api_public/v1/es/localized_page/by_slug/about-us"

        json = response.parsed_body
        expect(json["canonical_url"]).to include("/es/p/about-us")
      end
    end

    describe "Open Graph metadata" do
      it "includes all required OG tags" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        og = json["og"]

        expect(og).to be_present
        expect(og["og:title"]).to eq("About Us - Best Real Estate")
        expect(og["og:description"]).to eq("Learn more about our real estate company and services.")
        expect(og["og:type"]).to eq("website")
        expect(og["og:url"]).to include("/p/about-us")
        expect(og["og:site_name"]).to be_present
      end

      it "localizes OG metadata for non-default locale" do
        get "/api_public/v1/es/localized_page/by_slug/about-us"

        json = response.parsed_body
        og = json["og"]

        expect(og["og:title"]).to eq("Sobre Nosotros - Mejor Inmobiliaria")
        expect(og["og:description"]).to eq("Conozca más sobre nuestra empresa inmobiliaria y servicios.")
        expect(og["og:url"]).to include("/es/p/about-us")
      end
    end

    describe "Twitter Card metadata" do
      it "includes all required Twitter Card tags" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        twitter = json["twitter"]

        expect(twitter).to be_present
        expect(twitter["twitter:card"]).to eq("summary_large_image")
        expect(twitter["twitter:title"]).to eq("About Us - Best Real Estate")
        expect(twitter["twitter:description"]).to eq("Learn more about our real estate company and services.")
      end
    end

    describe "JSON-LD structured data" do
      it "includes valid JSON-LD WebPage schema" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        json_ld = json["json_ld"]

        expect(json_ld).to be_present
        expect(json_ld["@context"]).to eq("https://schema.org")
        expect(json_ld["@type"]).to eq("WebPage")
        expect(json_ld["name"]).to eq("About Us - Best Real Estate")
        expect(json_ld["description"]).to eq("Learn more about our real estate company and services.")
        expect(json_ld["url"]).to include("/p/about-us")
        expect(json_ld["inLanguage"]).to eq("en")
        expect(json_ld["datePublished"]).to be_present
        expect(json_ld["dateModified"]).to be_present
      end

      it "includes publisher organization" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        publisher = json["json_ld"]["publisher"]

        expect(publisher).to be_present
        expect(publisher["@type"]).to eq("Organization")
        expect(publisher["name"]).to be_present
      end

      it "sets inLanguage based on requested locale" do
        get "/api_public/v1/es/localized_page/by_slug/about-us"

        json = response.parsed_body
        expect(json["json_ld"]["inLanguage"]).to eq("es")
      end
    end

    describe "breadcrumbs" do
      it "includes breadcrumb trail" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        breadcrumbs = json["breadcrumbs"]

        expect(breadcrumbs).to be_an(Array)
        expect(breadcrumbs.length).to eq(2)
        expect(breadcrumbs[0]["name"]).to eq("Home")
        expect(breadcrumbs[0]["url"]).to eq("/")
        expect(breadcrumbs[1]["name"]).to eq("About Our Company")
        expect(breadcrumbs[1]["url"]).to include("/p/about-us")
      end

      it "localizes breadcrumb URLs for non-default locale" do
        get "/api_public/v1/es/localized_page/by_slug/about-us"

        json = response.parsed_body
        breadcrumbs = json["breadcrumbs"]

        expect(breadcrumbs[0]["url"]).to eq("/es/")
        expect(breadcrumbs[1]["url"]).to include("/es/p/about-us")
        expect(breadcrumbs[1]["name"]).to eq("Sobre Nuestra Empresa")
      end
    end

    describe "alternate locales" do
      it "includes alternate locale URLs" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        alternates = json["alternate_locales"]

        expect(alternates).to be_an(Array)
        # Should include es and fr, but not en (current locale)
        locales = alternates.map { |a| a["locale"] }
        expect(locales).to include("es", "fr")
        expect(locales).not_to include("en")
      end

      it "excludes current locale from alternates" do
        get "/api_public/v1/es/localized_page/by_slug/about-us"

        json = response.parsed_body
        alternates = json["alternate_locales"]

        locales = alternates.map { |a| a["locale"] }
        expect(locales).to include("en", "fr")
        expect(locales).not_to include("es")
      end

      it "includes correct URLs for alternate locales" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        alternates = json["alternate_locales"]

        es_alternate = alternates.find { |a| a["locale"] == "es" }
        expect(es_alternate["url"]).to include("/es/p/about-us")

        fr_alternate = alternates.find { |a| a["locale"] == "fr" }
        expect(fr_alternate["url"]).to include("/fr/p/about-us")
      end
    end

    describe "html_elements" do
      it "includes localized UI element labels" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body
        html_elements = json["html_elements"]

        expect(html_elements).to be_an(Array)
        expect(html_elements).not_to be_empty

        page_title_element = html_elements.find { |e| e["element_class_id"] == "page_title" }
        expect(page_title_element).to be_present
        expect(page_title_element["element_label"]).to be_a(Hash)
        expect(page_title_element["element_label"]["en"]).to eq("About Our Company")
        expect(page_title_element["element_label"]["es"]).to eq("Sobre Nuestra Empresa")
      end
    end

    describe "navigation visibility flags" do
      it "includes all navigation flags" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body

        expect(json).to have_key("show_in_top_nav")
        expect(json).to have_key("show_in_footer")
        expect(json).to have_key("sort_order_top_nav")
        expect(json).to have_key("sort_order_footer")
        expect(json).to have_key("visible")
      end
    end

    describe "caching" do
      it "includes cache control metadata in response" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        json = response.parsed_body

        expect(json["cache_control"]).to eq("public, max-age=3600")
        expect(json["etag"]).to be_present
        expect(json["last_modified"]).to be_present
      end

      it "sets proper HTTP cache headers" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"

        expect(response.headers["Cache-Control"]).to include("public")
        expect(response.headers["ETag"]).to be_present
      end

      it "generates different ETags for different locales" do
        get "/api_public/v1/en/localized_page/by_slug/about-us"
        en_etag = response.parsed_body["etag"]

        get "/api_public/v1/es/localized_page/by_slug/about-us"
        es_etag = response.parsed_body["etag"]

        expect(en_etag).not_to eq(es_etag)
      end
    end

    describe "page_contents" do
      let!(:page_with_content) do
        ActsAsTenant.with_tenant(website) do
          page = FactoryBot.create(:pwb_page, slug: "services", website: website, visible: true)
          Mobility.with_locale(:en) { page.page_title = "Our Services" }
          Mobility.with_locale(:es) { page.page_title = "Nuestros Servicios" }
          page.save!

          # Create page content with rendered HTML
          # Content.raw uses Mobility, so we need to set it with locale context
          content = Pwb::Content.create!(
            website: website,
            page_part_key: "content_html"
          )
          Mobility.with_locale(:en) do
            content.raw = '<section class="services"><h1>Our Services</h1><a href="/contact">Contact Us</a></section>'
          end
          Mobility.with_locale(:es) do
            content.raw = '<section class="services"><h1>Nuestros Servicios</h1><a href="/contact">Contáctenos</a></section>'
          end
          content.save!
          Pwb::PageContent.create!(
            page: page,
            website: website,
            content: content,
            page_part_key: "content_html",
            sort_order: 1,
            visible_on_page: true,
            is_rails_part: false
          )
          page
        end
      end

      it "includes page_contents array" do
        get "/api_public/v1/en/localized_page/by_slug/services"

        json = response.parsed_body

        expect(json["page_contents"]).to be_an(Array)
        expect(json["page_contents"].length).to eq(1)

        content = json["page_contents"].first
        expect(content["page_part_key"]).to eq("content_html")
        expect(content["sort_order"]).to eq(1)
        expect(content["visible"]).to be true
        expect(content["is_rails_part"]).to be false
        expect(content["rendered_html"]).to include("<section class=\"services\">")
      end

      it "localizes URLs in rendered HTML for non-default locale" do
        get "/api_public/v1/es/localized_page/by_slug/services"

        json = response.parsed_body
        content = json["page_contents"].first

        # Internal links should be localized
        expect(content["rendered_html"]).to include('href="/es/contact"')
      end
    end

    describe "error handling" do
      it "returns 404 for non-existent page" do
        get "/api_public/v1/en/localized_page/by_slug/nonexistent-page"

        expect(response).to have_http_status(404)
        json = response.parsed_body

        expect(json["error"]).to eq("Page not found")
        expect(json["code"]).to eq("PAGE_NOT_FOUND")
      end

      context "when website has no pages" do
        before do
          website.pages.destroy_all
        end

        it "returns website not provisioned error" do
          get "/api_public/v1/en/localized_page/by_slug/about-us"

          expect(response).to have_http_status(404)
          json = response.parsed_body

          expect(json["error"]).to eq("Website not provisioned")
          expect(json["code"]).to eq("WEBSITE_NOT_PROVISIONED")
        end
      end
    end

    describe "locale fallback" do
      let!(:page_with_partial_translations) do
        ActsAsTenant.with_tenant(website) do
          page = FactoryBot.create(:pwb_page, slug: "terms", website: website, visible: true)
          # Only set English translations
          Mobility.with_locale(:en) do
            page.page_title = "Terms of Service"
            page.seo_title = "Terms and Conditions"
            page.meta_description = "Read our terms of service."
          end
          # No Spanish or French translations set
          page.save!
          page
        end
      end

      it "falls back to English when translation is missing" do
        # Request Spanish but Spanish translations don't exist
        get "/api_public/v1/es/localized_page/by_slug/terms"

        json = response.parsed_body
        # Should fall back to English due to Mobility fallbacks configuration
        expect(json["title"]).to eq("Terms and Conditions")
        expect(json["meta_description"]).to eq("Read our terms of service.")
      end
    end
  end
end
