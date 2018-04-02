module Pwb
  class PropCreator
    attr_accessor :propertyJSON, :locales, :max_photos_to_process

    def initialize(propertyJSON, **keyword_args)
      # https://www.justinweiss.com/articles/fun-with-keyword-arguments/
      self.propertyJSON = propertyJSON
      self.locales = keyword_args["locales"] || keyword_args[:locales] || ["en","nl"]
      self.max_photos_to_process = keyword_args["max_photos_to_process"] || keyword_args[:max_photos_to_process] || 2
    end

    # TODO: move logic for below (currently in prop model) to here:
    # before_save :set_rental_search_price
    # after_create :set_defaults

    def create_from_json 
      # TODO: ensure reference is created (calculate from lat lng if necessary)
      new_prop = Pwb::Prop.create(propertyJSON.except("locale_code","features","property_photos"))

      if propertyJSON["latitude"] && propertyJSON["longitude"]
        unless propertyJSON["street_address"] && propertyJSON["postal_code"]
          new_prop.reverse_geocode
        end
      else
        new_prop.geocode
      end

      # create will use website defaults for currency and area_unit
      # need to override that
      if propertyJSON["currency"]
        new_prop.currency = propertyJSON["currency"]
        new_prop.save!
      end
      if propertyJSON["area_unit"]
        new_prop.area_unit = propertyJSON["area_unit"]
        new_prop.save!
      end

      # TODO - go over supported locales and save title and description
      # into them
      locales.each do |locale|
        # new_prop["description_" + locale] = propertyJSON["description"]
        # above won't work
        new_prop.update_attribute("description_" + locale, propertyJSON["description"])
        new_prop.update_attribute("title_" + locale, propertyJSON["title"])
      end
      new_prop.save!

      if propertyJSON["features"]
        # new_prop.set_features=propertyJSON["features"]
        propertyJSON["features"].each do |feature_name|
          feature_translation_model = I18n::Backend::ActiveRecord::Translation.find_by_value(feature_name.strip)
          if feature_translation_model
            feature_key = feature_translation_model.key
          else
            feature_key = "features." + feature_name.camelize(:lower).delete(" \t\r\n")
            locales.each do |locale|
              # not much I can do other than set all locales to the translation I know of
              # Admin can go in later and edit them
              I18n::Backend::ActiveRecord::Translation.create!(
              {locale: locale, key: feature_key, value: feature_name.strip})
            end
          end
          new_prop.features.find_or_create_by( feature_key: feature_key)
        end
      end
      if propertyJSON["property_photos"]
        # uploading images can slow things down so worth setting a limit
        propertyJSON["property_photos"].each_with_index do |property_photo, index|
          if (index + 1) > max_photos_to_process
            break
          end
          photo = Pwb::PropPhoto.create
          photo.sort_order = property_photo["sort_order"] || nil
          photo.remote_image_url = property_photo["url"] || property_photo[:url]
          # photo.remote_image_url = property_photo["image"]["url"] || property_photo["url"]
          photo.save!
          new_prop.prop_photos.push photo
        end
      end
      return new_prop
    end

  end
end
