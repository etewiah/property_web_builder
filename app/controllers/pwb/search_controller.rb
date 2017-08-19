require_dependency 'pwb/application_controller'

module Pwb
  class SearchController < ApplicationController
    before_action :header_image

    def search_ajax_for_sale
      @operation_type = "for_sale"
      # above used to decide if link to result should be to buy or rent path
      # http://www.justinweiss.com/articles/search-and-filter-rails-models-without-bloating-your-controller/
      @properties = Prop.visible.for_sale
      # .order('price_sale_current_cents ASC')
      # @properties = Prop.where(nil) # creates an anonymous scope
      apply_search_filter filtering_params(params)
      set_map_markers
      render "/pwb/search/search_ajax.js.erb", layout: false
      #  view rendered will use js to inject results...
    end

    def search_ajax_for_rent
      @operation_type = "for_rent"
      # above used to decide if link to result should be to buy or rent path
      # http://www.justinweiss.com/articles/search-and-filter-rails-models-without-bloating-your-controller/
      @properties = Prop.visible.for_rent

      apply_search_filter filtering_params(params)
      set_map_markers
      render "/pwb/search/search_ajax.js.erb", layout: false
      #  view rendered will use js to inject results...
    end

    # ordering of results happens client-side with paloma search.js
    def buy
      @page_title = I18n.t("searchForProperties")
      # in erb template for this action, I have js that will render search_results template
      # for properties - like search_ajax action does
      @operation_type = "for_sale"
      # above used to decide if link to result should be to buy or rent path

      @properties = Prop.visible.for_sale.limit 45
      # ordering happens clientside
      # .order('price_sale_current_cents ASC').limit 35
      @prices_from_collection = @current_website.sale_price_options_from
      @prices_till_collection = @current_website.sale_price_options_till
      # @prices_collection = @current_website.sale_price_options_from

      # %W(#{''} 25,000 50,000 75,000 100,000 150,000 250,000 500,000 1,000,000 2,000,000 5,000,000 )
      # ..

      set_common_search_inputs
      set_select_picker_texts
      apply_search_filter filtering_params(params)
      set_map_markers

      # below allows setting in form of any input values that might have been passed by param
      @search_defaults = params[:search].present? ? params[:search] : {}
      # {"property_type" => ""}
      # below won't sort right away as the list of results is loaded by js
      # and so won't be ready for sorting when below is called - but will wire up for sorting button
      # initial client sort called by       INMOAPP.sortSearchResults();
      js 'Main/Search#sort' # trigger client-side paloma script

      render "/pwb/search/buy"
    end

    # TODO: - avoid duplication b/n rent and buy
    def rent
      @page_title = I18n.t("searchForProperties")
      # in erb template for this action, I have js that will render search_results template
      # for properties - like search_ajax action does
      @operation_type = "for_rent"
      # above used to decide if link to result should be to buy or rent path

      @properties = Prop.visible.for_rent.limit 45
      # .order('price_rental_monthly_current_cents ASC').limit 35

      @prices_from_collection = @current_website.rent_price_options_from
      @prices_till_collection = @current_website.rent_price_options_till
      # @prices_collection = %W(#{''}
      #                         150 250 500 1,000 1,500 2,000 2,500 3,000 4,000 5,000 10,000)

      set_common_search_inputs
      set_select_picker_texts
      apply_search_filter filtering_params(params)
      set_map_markers
      @search_defaults = params[:search].present? ? params[:search] : {}

      js 'Main/Search#sort' # trigger client-side paloma script
      render "/pwb/search/rent"
    end

    private

    def set_map_markers
      @map_markers = []
      @properties.each do |property|
        if property.show_map
          @map_markers.push(
            {
              id: property.id,
              title: property.title,
              show_url: property.contextual_show_path(@operation_type),
              image_url: property.primary_image_url,
              display_price: property.contextual_price_with_currency(@operation_type),
              position: {
                lat: property.latitude,
                lng: property.longitude
              }
            }
          )
        end
      end
    end

    # A list of the param names that can be used for filtering the Product list
    def filtering_params(params)
      unless params[:search]
        return []
      end
      # {"price_from"=>"50.000",
      #  "price_till"=>"",
      #  "property_type"=>"propertyTypes.bungalow",
      #  "locality"=>"#<OpenStruct value=\"provincias.cadiz\", label=\"Cádiz\">",
      #  "zone"=>"#<OpenStruct value=\"provincias.ciudadReal\", label=\"Ciudad Real\">",
      #  "count_bedrooms"=>"6",
      #  "count_bathrooms"=>"",
      #  "property_state"=>"propertyStates.brandNew"}
      params[:search].slice(:in_locality, :in_zone, :for_sale_price_from, :for_sale_price_till, :for_rent_price_from,
                            :for_rent_price_till, :property_type, :property_state, :count_bathrooms, :count_bedrooms)
    end

    def set_select_picker_texts
      @select_picker_texts = {
        noneSelectedText: I18n.t("selectpicker.noneSelectedText"),
        noneResultsText: I18n.t("selectpicker.noneResultsText"),
        countSelectedText: I18n.t("selectpicker.countSelectedText")
      }.to_json
    end

    def set_common_search_inputs
      # for these 2 below, I'm checking in form if count is > 1
      # assumption is that there will be at least one Zone with blank values
      # @zones = Zone.all.order "title"
      # @localities = Locality.all.order "title"

      @property_types = FieldKey.get_options_by_tag("property-types")
      # below ensures there is a an empty value at the top of the array
      # so that default is "nothing selected"
      # realised today that I could probably achieve the same with
      # ":include_blank => true" attribute on form
      @property_types.unshift OpenStruct.new(value: "", label: "")
      # because property_states does not have a selected: option in the form
      # not necessary to unshift an empty value
      # (doesn't have selected:option because it cannot be populated by url)
      @property_states = FieldKey.get_options_by_tag("property-states")
    end

    def apply_search_filter(search_filtering_params)
      search_filtering_params.each do |key, value|
        empty_values = ["propertyTypes."]
        if (empty_values.include? value) || value.empty?
          next
        end
        price_fields = ["for_sale_price_from", "for_sale_price_till", "for_rent_price_from", "for_rent_price_till"]
        if price_fields.include? key
          currency_string = @current_website.default_currency || "usd"
          currency = Money::Currency.find currency_string
          # above needed as some currencies like Chilean peso
          # don't have the cents field multiplied by 100
          value = value.gsub(/\D/, '').to_i * currency.subunit_to_unit
          # @properties = @properties.public_send(key, value) if value.present?
        end
        @properties = @properties.public_send(key, value) if value.present?
      end
      # end
    end

    # def search_redirect
    #   # todo - allow choosing between buying or renting
    #   return redirect_to buy_url, locale: I18n.locale
    # end

    # def ajax_find_by_ref
    #   query = params[:reference].upcase.strip
    #   @properties = Prop.where("reference LIKE :query", query: "%#{query}%")

    #   # it seems with active record, .size is better than .count or .length..
    #   if @properties && @properties.size > 1
    #     # how to know if properties are for rent or sale

    #     js 'Main/Search#sort' # trigger client-side paloma script
    #     return render "search_ajax"
    #   else
    #     @property = @properties.first
    #   end

    #   # Prop.visible.for_sale.order('price_sale_current_cents ASC')
    #   if @property && @property.visible
    #     if @property.for_sale
    #       return render js: "window.location='#{property_show_for_sale_url(locale: I18n.locale, url_friendly_title: "show", id: @property.id)}'"
    #       # redirect like below won't work as I'm using "remote true" on client side
    #       # return redirect_to property_show_for_sale_url(locale: I18n.locale, url_friendly_title: "show", id: @property.id) , format: 'js'
    #     else
    #       return render js: "window.location='#{property_show_for_rent_url(locale: I18n.locale, url_friendly_title: "show", id: @property.id)}'"
    #     end
    #   else
    #     @error_message = I18n.t "noResultsForSearch"
    #     # TODO - pluck similar refs to what user typed
    #     # and dislay as a list
    #     return render "go_to_property_error_ajax"
    #   end
    # end

    private
    # def header_image_url
    #   # used by berlin theme
    #   hi_content = Content.where(tag: 'landing-carousel')[0]
    #   @header_image_url = hi_content.present? ? hi_content.default_photo_url : ""
    # end

    def header_image
      # used by berlin theme
      hi_content = Content.where(tag: 'landing-carousel')[0]
      @header_image = hi_content.present? ? hi_content.default_photo : nil
    end
  end
end
