require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::PageController < ApplicationApiController
    # protect_from_forgery with: :null_session
    def show
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
      unless params["page_part_key"]
        return render_json_error 'Please provide label'
      end
      page_part_key = params["page_part_key"]

      photo = page.create_fragment_photo page_part_key, block_label, params[:file]
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

      if params["cmd"] == "setAsHidden"
        page.set_fragment_visibility params[:page_part_key], false
      end
      if params["cmd"] == "setAsVisible"
        page.set_fragment_visibility params[:page_part_key], true
      end

      # page.details["visiblePageParts"] = params[:visible_page_parts]
      # page.save!
      render json: page
    end

    def save_page_fragment
      page = Page.find_by_slug params[:page_slug]
      fragment_details = params[:fragment_details]
      unless fragment_details && fragment_details["locale"]
        return render_json_error 'Please provide locale'
      end
      locale = fragment_details["locale"]
      unless fragment_details["page_part_key"]
        return render_json_error 'Please provide page_part_key'
      end
      page_part_key = fragment_details["page_part_key"]

      # json_fragment_block = page.set_fragment_details page_part_key, locale, fragment_details
      # fragment_html = render_to_string :partial => "pwb/fragments/#{page_part_key}",  :locals => { page_part: params[:fragment_details][:blocks]}

      # # save the block contents (in associated page_part model)
      # json_fragment_block = page.set_page_part_block_contents page_part_key, locale, fragment_details
      # # retrieve the contents saved above and use to rebuild html for that page_part
      # # (and save it in associated page_content model)
      # fragment_html = page.rebuild_page_content page_part_key, locale

      result_to_return = page.update_page_part_content page_part_key, locale, fragment_details

      # # Check if an image url has been set
      # fragment_details.each do |fragment_detail|
      #   update_all_images = true
      # end

      # page.save!
      # rescue StandardError => error
      #   return render_json_error error.message
      # end

      return render json: {
        blocks: result_to_return[:json_fragment_block],
        html: result_to_return[:fragment_html]
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
