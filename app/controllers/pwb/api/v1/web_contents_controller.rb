module Pwb
  class Api::V1::WebContentsController < JSONAPI::ResourceController
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    skip_before_action :ensure_valid_accept_media_type


    # below is used by logo_photo and about_us_photo,
    # where only one photo is allowed
    def update_photo
      content_tag = params[:content_tag]
      # photo = ContentPhoto.find(params[:id])
      # find would throw error if not found
      photo = ContentPhoto.find_by_id(params[:id])
      unless photo
        if content_tag
          # where photo has never been set before, associated Content will not exist
          content = Content.find_by_key(content_tag) || Content.create({ key: content_tag, tag: 'general' })
          photo = ContentPhoto.create
          content.content_photos.push photo
        end
        # TODO - handle where no photo or content_tag..
      end

      if params[:file]
        photo.image = params[:file]
      end
      photo.save!

      return render json: photo.to_json
    end


  end
end
