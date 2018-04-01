module Pwb
  class PropCreator
    attr_accessor :propertyJSON

    def initialize(propertyJSON)
      self.propertyJSON = propertyJSON
    end

    def create 
      # TODO: pass in locales
      locales = ["en","es"]
      # TODO: ensure reference is created (calculate from lat lng if necessary)
      # and add geocoding option
      new_prop = Pwb::Prop.create(propertyJSON.except("locale_code","features","property_photos"))
      # new_prop = Pwb::Prop.create(propertyJSON.except("features", "property_photos", "image_urls", "last_retrieved_at"))

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
        max_photos_to_process = 2
        # TODO - retrieve above as a param
        propertyJSON["property_photos"].each_with_index do |property_photo, index|
          if index > max_photos_to_process
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
