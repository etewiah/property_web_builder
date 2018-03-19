require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::PropertiesController < ApplicationApiPublicController


    def request_property_info
      @error_messages = []
      I18n.locale = params["contact"]["locale"] || I18n.default_locale
      # have a hidden field in form to pass in above
      # if I didn't I could end up with the wrong locale
      # @enquiry = Message.new(params[:contact])
      @property = Prop.find(params[:contact][:property_id])
      @contact = Contact.find_or_initialize_by(primary_email: params[:contact][:email])
      @contact.attributes = {
        primary_phone_number: params[:contact][:tel],
        first_name: params[:contact][:name]
      }

      title = I18n.t "mailers.property_enquiry_targeting_agency.title"
      @enquiry = Message.new({
                               title: title,
                               content: params[:contact][:message],
                               locale: params[:contact][:locale],
                               url: request.referer,
                               host: request.host,
                               origin_ip: request.ip,
                               user_agent: request.user_agent,
                               delivery_email: @current_agency.email_for_property_contact_form
                               # origin_email: params[:contact][:email]
      })

      unless @enquiry.save && @contact.save
        @error_messages += @contact.errors.full_messages
        @error_messages += @enquiry.errors.full_messages
        return render json: {
          success: false,
          errors: @error_messages
        }
      end

      unless @current_agency.email_for_property_contact_form.present?
        # in case a delivery email has not been set
        @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
      end

      @enquiry.contact = @contact
      @enquiry.save

      EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver
      # @enquiry.delivery_success = true
      @enquiry.save
      @flash = I18n.t "contact.success"
      return render json: {
        success: true
      }
    rescue => e
      # TODO: - log error to logger....
      @error_messages = [I18n.t("contact.error"), e]
      return render json: {
        success: false,
        errors: @error_messages
      }
    end


    def search
      @operation_type = "for_rent"
      # http://www.justinweiss.com/articles/search-and-filter-rails-models-without-bloating-your-controller/

      # @properties = Prop.visible.for_rent
      # apply_search_filter filtering_params(params)
      # set_map_markers
      # render "/pwb/search/search_ajax.js.erb", layout: false

      # byebug

      prop_search_results = DisplayPropertiesQuery.new(search_params: params).from_params
      # else
      #   prop_search_results = DisplayPropertiesQuery.new().from_params
      # end
      # properties_for_rent = DisplayPropertiesQuery.new().for_rent

      return render json: {
        prop_search_results: prop_search_results
      }
    end


    def show
      I18n.locale = params[:locale]
      property = Pwb::Prop.find params[:id]
      # property_title = @current_agency.company_name
      # @content_to_show = []

      if property.present?

        return render json: {
          property: property.as_json_detailed
        }
      else
        return render json: {
          page: {}
        }
      end
    end


    private

  end
end
