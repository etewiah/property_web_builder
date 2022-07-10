module Pwb
  class Api::V1::WebContentsController < JSONAPI::ResourceController
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    # skip_before_action :ensure_valid_accept_media_type

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
          content = Content.find_by_key(content_tag) || Content.create({ key: content_tag, tag: "appearance" })
          photo = ContentPhoto.create
          if content_tag == "logo"
            # TODO: This is a workaround
            # need to have a way of determining content that should only have
            # one photo and enforcing that
            content.content_photos.destroy_all
          end
          content.content_photos.push photo
        end
        # TODO: - handle where no photo or content_tag..
      end
      if params[:file]
        photo.image = params[:file]
      end
      photo.save!
      photo.reload
      render json: photo.to_json
    end

    # below used when uploading carousel images
    def create_content_with_photo
      tag = params[:tag]
      photo = ContentPhoto.create

      key = tag.underscore.camelize + photo.id.to_s
      new_content = Content.create(tag: tag, key: key)

      # photo.subdomain = subdomain
      # photo.folder = current_tenant_model.whitelabel_country_code
      # photo.tenant_id = current_tenant_model.id
      if params[:file]
        photo.image = params[:file]
      end
      photo.save!
      new_content.content_photos.push photo

      # http://typeoneerror.com/labs/jsonapi-resources-ember-data/
      # resource for model
      resource = Api::V1::WebContentResource.new(new_content, nil)

      # serializer for resource
      serializer = JSONAPI::ResourceSerializer.new(Api::V1::WebContentResource)
      # jsonapi-compliant hash (ready to be send to render)

      photo.reload
      # above needed to ensure image_url is available
      # might need below if upload in prod is slow..

      # upload_confirmed = false
      # tries = 0
      # until upload_confirmed
      #   if photo.image_url.present?
      #     upload_confirmed = true
      #   else
      #     sleep 1
      #     photo.reload
      #     tries += 1
      #     if tries > 5
      #       upload_confirmed = true
      #     end
      #   end
      # end

      render json: serializer.serialize_to_hash(resource)

      # return render json: new_content.to_json
      # return render :json => { :error => "Sorry...", :status => "444", :data => "ssss" }, :status => 422
    end
  end
end
