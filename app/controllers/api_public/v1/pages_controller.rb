module ApiPublic
  module V1
    class PagesController < BaseController
      include ApiPublic::Cacheable
      include UrlLocalizationHelper

      def show
        unless website_provisioned?
          render json: website_not_provisioned_error, status: :not_found
          return
        end

        page = Pwb::Current.website.pages.find(params[:id])

        set_short_cache(max_age: 5.minutes, etag_data: [page.id, page.updated_at])
        return if performed?

        render json: page_json(page)
      rescue ActiveRecord::RecordNotFound
        render_not_found_error(
          "No page exists with id '#{params[:id]}' for this website",
          code: "PAGE_NOT_FOUND"
        )
      end

      def show_by_slug
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale

        unless website_provisioned?
          render json: website_not_provisioned_error, status: :not_found
          return
        end

        page = Pwb::Current.website.pages.find_by_slug(params[:slug])

        if page
          set_short_cache(max_age: 5.minutes, etag_data: [page.id, page.updated_at])
          return if performed?

          render json: page_json(page)
        else
          render_not_found_error(
            "No page exists with slug '#{params[:slug]}' for this website. Available pages: #{available_page_slugs.join(', ')}",
            code: "PAGE_NOT_FOUND"
          )
        end
      end

      private

      def website_provisioned?
        Pwb::Current.website.present? && Pwb::Current.website.pages.exists?
      end

      def website_not_provisioned_error
        {
          error: "Website not provisioned",
          message: "The website has not been provisioned with any pages. Please run the setup/seeding process to create initial pages.",
          code: "WEBSITE_NOT_PROVISIONED"
        }
      end

      def available_page_slugs
        Pwb::Current.website.pages.pluck(:slug).compact
      end

      def page_json(page)
        json = page.as_json(methods: [])

        # Include page parts if requested (legacy - metadata only)
        json["page_parts"] = build_page_parts(page) if params[:include_parts] == "true"

        # Include rendered page contents with pre-rendered HTML
        # This is the preferred approach for frontend clients that need to display content
        json["page_contents"] = build_rendered_page_contents(page) if params[:include_rendered] == "true"

        json
      end

      # Build rendered page contents with pre-rendered HTML
      # This matches how Pwb::PagesController#show_page works
      # The HTML is already rendered via Liquid and stored in Content.raw
      def build_rendered_page_contents(page)
        return [] unless page.respond_to?(:ordered_visible_page_contents)

        page.ordered_visible_page_contents.map do |page_content|
          raw_html = page_content.is_rails_part ? nil : page_content.content&.raw
          # Localize URLs in HTML content based on current locale
          localized_html = raw_html.present? ? localize_html_urls(raw_html) : nil

          {
            page_part_key: page_content.page_part_key,
            sort_order: page_content.sort_order,
            visible: page_content.visible_on_page,
            is_rails_part: page_content.is_rails_part || false,
            rendered_html: localized_html,
            # Include label for debugging/admin purposes
            label: page_content.label
          }
        end
      end

      def build_page_parts(page)
        return [] unless page.respond_to?(:page_parts)

        parts_scope = page.page_parts
        parts_scope = parts_scope.visible if parts_scope.respond_to?(:visible)
        parts_scope = parts_scope.ordered if parts_scope.respond_to?(:ordered)

        parts_scope.map do |part|
          {
            id: part.id,
            key: part.respond_to?(:page_part_key) ? part.page_part_key : part.key,
            position: part.position,
            visible: part.respond_to?(:visible?) ? part.visible? : true,
            template: part.respond_to?(:template_name) ? part.template_name : nil,
            content: build_part_content(part)
          }
        end
      end

      def build_part_content(part)
        content = {}

        # Common content fields
        content[:heading] = part.heading if part.respond_to?(:heading) && part.heading.present?
        content[:subheading] = part.subheading if part.respond_to?(:subheading) && part.subheading.present?
        content[:body] = part.body if part.respond_to?(:body) && part.body.present?
        content[:body_html] = part.body_html if part.respond_to?(:body_html) && part.body_html.present?

        # Image
        content[:image_url] = part.image_url if part.respond_to?(:image_url) && part.image_url.present?

        # CTA
        content[:cta_text] = part.cta_text if part.respond_to?(:cta_text) && part.cta_text.present?
        content[:cta_url] = part.cta_url if part.respond_to?(:cta_url) && part.cta_url.present?

        # Items (for lists, features, etc.)
        content[:items] = part.items if part.respond_to?(:items) && part.items.present?

        # Custom data
        content[:custom_data] = part.custom_data if part.respond_to?(:custom_data) && part.custom_data.present?

        content
      end
    end
  end
end
