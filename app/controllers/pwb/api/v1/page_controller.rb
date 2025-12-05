require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::PageController < ApplicationApiController
    protect_from_forgery with: :null_session
    def show
      if params[:page_name] == "website"
        # Use current_website for proper multi-tenant isolation
        unless current_website
          return render json: { error: "Website not found" }, status: :not_found
        end
        return render json: current_website.as_json_for_page
      end

      page = current_website.pages.find_by_slug(params[:page_name])
      if page
        render json: page.as_json_for_admin
      else
        render json: {}
      end
    end

    def set_photo
      # This adds an image that can be used for a page fragment
      # A separate call is required to actually use the image
      # in a page fragment
      unless params["block_label"]
        return render_json_error "Please provide block_label"
      end
      block_label = params["block_label"]
      unless params["page_part_key"]
        return render_json_error "Please provide label"
      end
      page_part_key = params["page_part_key"]
      page = current_website.pages.find_by_slug params[:page_slug]

      photo = page.create_fragment_photo page_part_key, block_label, params[:file]
      photo.reload
      render json: {
        image_url: photo.optimized_image_url,
      }
    end

    def update
      page = current_website.pages.find_by_slug params[:page][:slug]
      page.update(page_params)
      page.save!
      render json: page.as_json_for_admin
    end

    def update_page_part_visibility
      page = current_website.pages.find_by_slug params[:page_slug]
      unless page
        return render_json_error "Please provide valid page slug"
      end

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
      if params[:page_slug] == "website"
        # Use current_website for proper multi-tenant isolation
        container = current_website
        unless container
          return render_json_error "Website not found"
        end
      else
        container = current_website.pages.find_by_slug params[:page_slug]
      end
      fragment_details = params[:fragment_details]
      unless fragment_details && fragment_details["locale"]
        return render_json_error "Please provide locale"
      end

      locale = fragment_details["locale"]
      unless fragment_details["page_part_key"]
        return render_json_error "Please provide page_part_key"
      end
      page_part_key = fragment_details["page_part_key"]
      page_part_manager = Pwb::PagePartManager.new page_part_key, container

      result_to_return = page_part_manager.update_page_part_content locale, fragment_details

      # # Check if an image url has been set
      # fragment_details.each do |fragment_detail|
      #   update_all_images = true
      # end

      # page.save!
      # rescue StandardError => error
      #   return render_json_error error.message
      # end

      render json: {
        blocks: result_to_return[:json_fragment_block],
        html: result_to_return[:fragment_html],
      }
    end

    private

    def page_fragment_params
      params.require(:fragment_details).permit(:label, :locale, blocks: %i[content identifier is_image])
    end

    def page_params
      page_fields = ["sort_order_top_nav", "visible"]
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
