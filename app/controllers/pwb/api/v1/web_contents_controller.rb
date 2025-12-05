module Pwb
  class Api::V1::WebContentsController < ApplicationController
    protect_from_forgery with: :null_session
    before_action :set_current_website

    # GET /api/v1/web-contents
    def index
      contents = current_contents

      # Apply filters
      contents = contents.where(tag: params.dig(:filter, :tag)) if params.dig(:filter, :tag).present?
      contents = contents.where(key: params.dig(:filter, :key)) if params.dig(:filter, :key).present?

      render json: serialize_contents(contents)
    end

    # GET /api/v1/web-contents/:id
    def show
      content = current_contents.find(params[:id])
      render json: serialize_content(content)
    end

    # below is used by logo_photo and about_us_photo,
    # where only one photo is allowed
    def update_photo
      content_tag = params[:content_tag]
      photo = ContentPhoto.find_by_id(params[:id])
      unless photo
        if content_tag
          content = current_website.contents.find_by_key(content_tag) || current_website.contents.create({ key: content_tag, tag: "appearance" })
          photo = ContentPhoto.create
          if content_tag == "logo"
            content.content_photos.destroy_all
          end
          content.content_photos.push photo
        end
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
      new_content = current_website.contents.create(tag: tag, key: key)

      if params[:file]
        photo.image = params[:file]
      end
      photo.save!
      new_content.content_photos.push photo

      photo.reload

      render json: serialize_content(new_content)
    end

    private

    def current_contents
      if Pwb::Current.website
        Pwb::Current.website.contents
      else
        Pwb::Content.none
      end
    end

    def serialize_contents(contents)
      {
        data: contents.map { |c| serialize_content_data(c) }
      }
    end

    def serialize_content(content)
      {
        data: serialize_content_data(content)
      }
    end

    def serialize_content_data(content)
      {
        id: content.id.to_s,
        type: "web-contents",
        attributes: {
          "key" => content.key,
          "tag" => content.tag,
          "raw-fr" => content.raw_fr,
          "raw-de" => content.raw_de,
          "raw-ru" => content.raw_ru,
          "raw-pt" => content.raw_pt,
          "raw-it" => content.raw_it,
          "raw-tr" => content.raw_tr,
          "raw-nl" => content.raw_nl,
          "raw-vi" => content.raw_vi,
          "raw-ar" => content.raw_ar,
          "raw-ca" => content.raw_ca,
          "raw-pl" => content.raw_pl,
          "raw-ro" => content.raw_ro,
          "raw-es" => content.raw_es,
          "raw-en" => content.raw_en,
          "content-photos" => content.content_photos
        }
      }
    end

    def set_current_website
      Pwb::Current.website = current_website_from_subdomain
    end

    def current_website_from_subdomain
      return nil unless request.subdomain.present?
      Website.find_by_subdomain(request.subdomain)
    end

    def current_website
      @current_website ||= Pwb::Current.website
    end
  end
end
