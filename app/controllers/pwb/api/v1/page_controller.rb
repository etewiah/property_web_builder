require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::PageController < ApplicationApiController
    # protect_from_forgery with: :null_session
    def get
      # admin_setup = Pwb::CmsPageContainer.where(name: params[:page_name]).first || {}
      # render json: admin_setup.as_json["attributes"]
      page = Pwb::Page.find_by_slug(params[:page_name])
      if page
        render json: page.as_json
      else
        render json: {}
      end
    end

    def update
      page = Page.find_by_slug params[:page][:slug]
      page.update(page_params)
      page.save!
      render json: page
    end

    def update_page_part_visibility
      page = Page.find_by_slug params[:page_slug]
      page.details["visiblePageParts"] = params[:visible_page_parts]
      page.save!
      render json: page
    end

    def save_page_fragment
      page = Page.find_by_slug params[:page_slug]
      locale = params[:fragment_details]["locale"]
      label = params[:fragment_details]["label"]
# byebug
      # fl = "about_us_services"
      fragment_html = render_to_string :partial => "pwb/fragments/#{label}",  :locals => { page_part: params[:fragment_details][:blocks]}
      # , formats: :css

      # TODO - add page model method that safely sets below
      page.details["fragments"][label][locale] = params[:fragment_details]
      page.details["fragments"][label][locale]["html"] = fragment_html

      # page.update(page_params)
      page.save!
      render json: page.details["fragments"][label][locale]
    end

    private

    def page_fragment_params
      params.require(:fragment_details).permit(:label, :locale, blocks: [:content, :identifier, :is_image])
    end


    def page_params
      page_fields = ["sort_order_top_nav","visible"]
      # TODO - replace below with i18n available locales..
      locales = ["en","es"]
      locales.each do |locale|
        page_fields.push("link_title_#{locale}")
        page_fields.push("page_title_#{locale}")
        page_fields.push("raw_html_#{locale}")
      end
      params.require(:page).permit(
        page_fields
      )
    end
  end
end
