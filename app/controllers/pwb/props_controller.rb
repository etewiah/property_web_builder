require_dependency "pwb/application_controller"

module Pwb
  class PropsController < ApplicationController
    include SeoHelper

    def show_for_rent
      @carousel_speed = 3000
      @operation_type = "for_rent"
      @operation_type_key = @operation_type.camelize(:lower)
      @map_markers = []

      # Use Pwb::ListedProperty (materialized view) for read operations
      # Find by slug first, then fall back to ID for backwards compatibility
      @property_details = find_property_by_slug_or_id(params[:id])

      if @property_details && @property_details.visible && @property_details.for_rent
        set_map_marker
        @show_vacational_rental = @property_details.for_rent_short_term

        @page_title = @property_details.title
        @page_description = @property_details.description

        # Set SEO data for the property
        set_property_seo(@property_details, 'for_rent')

        return render "/pwb/props/show"
      else
        @page_title = I18n.t("propertyNotFound")
        hi_content = @current_website.contents.where(tag: "landing-carousel")[0]
        @header_image = hi_content.present? ? hi_content.default_photo : nil
        return render "not_found"
      end
    end

    def show_for_sale
      @carousel_speed = 3000
      @operation_type = "for_sale"
      @operation_type_key = @operation_type.camelize(:lower)
      @map_markers = []

      # Use Pwb::ListedProperty (materialized view) for read operations
      # Find by slug first, then fall back to ID for backwards compatibility
      @property_details = find_property_by_slug_or_id(params[:id])

      if @property_details && @property_details.visible && @property_details.for_sale
        set_map_marker
        @page_title = @property_details.title
        @page_description = @property_details.description

        # Set SEO data for the property
        set_property_seo(@property_details, 'for_sale')

        return render "/pwb/props/show"
      else
        @page_title = I18n.t("propertyNotFound")
        hi_content = @current_website.contents.where(tag: "landing-carousel")[0]
        @header_image = hi_content.present? ? hi_content.default_photo : nil
        return render "not_found"
      end
    end

    def request_property_info_ajax
      @error_messages = []
      I18n.locale = params["contact"]["locale"] || I18n.default_locale
      # have a hidden field in form to pass in above
      # if I didn't I could end up with the wrong locale
      # @enquiry = Message.new(params[:contact])
      # Use Pwb::ListedProperty (materialized view) for read operations
      @property = Pwb::ListedProperty.where(website_id: @current_website.id).find(params[:contact][:property_id])
      @contact = @current_website.contacts.find_or_initialize_by(primary_email: params[:contact][:email])
      @contact.attributes = {
        primary_phone_number: params[:contact][:tel],
        first_name: params[:contact][:name],
      }

      title = I18n.t "mailers.property_enquiry_targeting_agency.title"
      @enquiry = Message.new({
        website: @current_website,
        title: title,
        content: params[:contact][:message],
        locale: params[:contact][:locale],
        url: request.referer,
        host: request.host,
        origin_ip: request.ip,
        user_agent: request.user_agent,
        delivery_email: @current_agency.email_for_property_contact_form,
      # origin_email: params[:contact][:email]
      })

      unless @enquiry.save && @contact.save
        @error_messages += @contact.errors.full_messages
        @error_messages += @enquiry.errors.full_messages
        return render "pwb/ajax/request_info_errors"
      end

      unless @current_agency.email_for_property_contact_form.present?
        # in case a delivery email has not been set
        @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
      end

      @enquiry.contact = @contact
      @enquiry.save

      # Async email delivery via Solid Queue
      EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver_later
      @flash = I18n.t "contact.success"
      return render "pwb/ajax/request_info_success", layout: false
    rescue => e
      # TODO: - log error to logger....
      @error_messages = [I18n.t("contact.error"), e]
      return render "pwb/ajax/request_info_errors", layout: false
    end

    private

    # Set SEO metadata for property pages
    def set_property_seo(property, operation_type)
      # Build canonical URL using slug if available
      canonical_path = if property.slug.present?
                         property.contextual_show_path(operation_type)
                       else
                         request.path
                       end
      canonical_url = "#{request.protocol}#{request.host_with_port}#{canonical_path}"

      # Get first image for social sharing
      image_url = property.primary_image_url

      # Get SEO fields - handle both ListedProperty (view) and Prop (model)
      # ListedProperty is a materialized view, so SEO fields come from the underlying Prop
      seo_title_value = property.respond_to?(:seo_title) ? property.seo_title : nil
      meta_desc_value = property.respond_to?(:meta_description) ? property.meta_description : nil

      set_seo(
        title: seo_title_value.presence || property.title,
        description: meta_desc_value.presence || truncate_description(property.description),
        canonical_url: canonical_url,
        image: image_url,
        og_type: 'product' # More appropriate for real estate listings
      )

      # Store property for JSON-LD generation in the view
      @seo_property = property
    end

    # Truncate description for meta tags (recommended ~155-160 chars)
    def truncate_description(text)
      return nil if text.blank?
      ActionController::Base.helpers.strip_tags(text).truncate(160)
    end

    # Find property by slug first, then fall back to ID for backwards compatibility
    # Supports both friendly slugs and legacy UUID/integer IDs
    def find_property_by_slug_or_id(identifier)
      scope = Pwb::ListedProperty.where(website_id: @current_website.id)

      # Try slug first
      property = scope.find_by(slug: identifier)
      return property if property

      # Fall back to ID (supports both UUID and integer formats)
      scope.find_by(id: identifier)
    end

    def set_map_marker
      if @property_details.show_map
        @map_markers.push(
          {
            id: @property_details.id,
            title: @property_details.title,
            show_url: @property_details.contextual_show_path(@operation_type),
            image_url: @property_details.primary_image_url,
            display_price: @property_details.contextual_price_with_currency(@operation_type),
            position: {
              lat: @property_details.latitude,
              lng: @property_details.longitude,
            },
          }
        )
      end
    end
  end
end
