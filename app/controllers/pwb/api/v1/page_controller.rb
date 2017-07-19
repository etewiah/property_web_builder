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

    private

    def page_params
      page_fields = ["sort_order_top_nav"]
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
