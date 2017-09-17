require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::PageController < ApplicationApiController
    # protect_from_forgery with: :null_session
    def get
      # admin_setup = Pwb::CmsPageContainer.where(name: params[:page_name]).first || {}
      # render json: admin_setup.as_json_for_admin["attributes"]
      page = Pwb::Page.find_by_slug(params[:page_name])
      if page
        render json: page.as_json_for_admin
      else
        render json: {}
      end
    end



    def set_photo 
      page = Page.find_by_slug params[:page_slug]

      unless params["block_label"]
        return render_json_error 'Please provide block_label'
      end
      block_label = params["block_label"]
      unless params["fragment_label"]
        return render_json_error 'Please provide label'
      end
      fragment_label = params["fragment_label"]

      photo = page.create_fragment_photo fragment_label, block_label, params[:file]
      photo.reload
      render json: {
        image_url: photo.optimized_image_url
      }
    end

    def update
      page = Page.find_by_slug params[:page][:slug]
      page.update(page_params)
      page.save!
      render json: page.as_json_for_admin
    end
    def update_page_part_visibility
      page = Page.find_by_slug params[:page_slug]
      page.details["visiblePageParts"] = params[:visible_page_parts]
      page.save!
      render json: page
    end

    def save_page_fragment
      page = Page.find_by_slug params[:page_slug]
      fragment_details = params[:fragment_details]
      unless fragment_details["locale"]
        return render_json_error 'Please provide locale'
      end
      locale = fragment_details["locale"]
      unless fragment_details["label"]
        return render_json_error 'Please provide label'
      end
      label = fragment_details["label"]


      # begin
      fragment_html = render_to_string :partial => "pwb/fragments/#{label}",  :locals => { page_part: params[:fragment_details][:blocks]}
      page.set_fragment_html label, locale, fragment_html
      # , formats: :css
      updated_details = page.set_fragment_details label, locale, fragment_details

      # binding.pry 
      # # Check if an image url has been set
      # fragment_details.each do |fragment_detail|
      #   update_all_images = true
      # end

      # if update_all_images
        
      # end

      page.save!
      # rescue StandardError => error
      #   return render_json_error error.message
      # end

      return render json: {
        blocks: updated_details,
        html: fragment_html
      }
    end

    private

    def page_fragment_params
      params.require(:fragment_details).permit(:label, :locale, blocks: [:content, :identifier, :is_image])
    end


    def page_params
      page_fields = ["sort_order_top_nav","visible"]
      locales = I18n.available_locales
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
