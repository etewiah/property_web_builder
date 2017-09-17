module Pwb
  # added July 2017
  # has details json col where page_fragment info is stored
  class Page < ApplicationRecord
    extend ActiveHash::Associations::ActiveRecordExtensions
    belongs_to_active_hash :page_setup, optional: true, foreign_key: "setup_id", class_name: "Pwb::PageSetup", shortcuts: [:friendly_name], primary_key: "id"
    has_many :links, foreign_key: "page_slug", primary_key: "slug"
    has_one :main_link, -> { where(placement: :top_nav) }, foreign_key: "page_slug", primary_key: "slug", class_name: "Pwb::Link"
    # , :conditions => ['placement = ?', :admin]

    has_many :page_contents
    has_many :contents, :through => :page_contents

    translates :raw_html, fallbacks_for_empty_translations: true
    translates :page_title, fallbacks_for_empty_translations: true
    translates :link_title, fallbacks_for_empty_translations: true
    # globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]
    globalize_accessors locales: I18n.available_locales

    # Pwb::Page.has_attribute?("raw_html")
    # below needed so above returns true
    attribute :link_title
    attribute :page_title
    attribute :raw_html
    # without above, Rails 5.1 will give deprecation warnings in my specs

    # scope :visible_in_admin, -> () { where visible: true  }

    def get_fragment_html label, locale
      content_key = slug + "_" + label
      content = self.contents.find_by_key content_key
      # fragments = details["fragments"] || {}
      # if fragments[label] && fragments[label][locale]
      #   fragments[label][locale]["html"]
      if content.present?
        content.raw
      else
        nil
      end
    end


    # # from admin ui, when image is updated for a given locale I need to
    # # update it on all fragments
    # # - also need to delete all other photos associated with the fragment_block
    # def update_fragment_image_url fragment_label, block_label, new_image_url
    #   content_key = self.slug + "_" + fragment_label
    #   # get in content model associated with page and fragment
    #   page_fragment_content = contents.find_or_create_by(key: content_key)
    #   # get all images associated with this fragment block
    #   fragment_photos = page_fragment_content.content_photos.where(description: block_label)
    #   fragment_photos.each do |fragment_photo|
    #     byebug
    #     # delete other images
    #   end
    #   #
    # end

    # used by page_controller to create a photo (from upload) that can
    # later be used in fragment html
    def create_fragment_photo fragment_label, block_label, photo_file
      content_key = self.slug + "_" + fragment_label
      # get content model associated with page and fragment
      page_fragment_content = contents.find_or_create_by(key: content_key)

      if ENV["RAILS_ENV"] == "test"
        # don't create photos for tests
        return nil
      end
      begin
        photo = page_fragment_content.content_photos.create(description: block_label)
        #TODO change description above to key

        photo.image = photo_file
        # photo.image = Pwb::Engine.root.join(photo_file).open
        photo.save!
      rescue Exception => e
        # log exception to console
        p e
        # if photo
        #   photo.destroy!
        # end
      end
      return photo
    end


    # when seeding I only need to ensure that a photo exists for the fragment
    # so will return existing photo if it can be found
    def seed_fragment_photo fragment_label, block_label, photo_file
      content_key = self.slug + "_" + fragment_label
      # get in content model associated with page and fragment
      page_fragment_content = contents.find_or_create_by(key: content_key)
      # change description below to key
      photo = page_fragment_content.content_photos.find_by_description(block_label)
      if photo.present?
        return photo
      else
        photo = page_fragment_content.content_photos.create(description: block_label)
      end
      # photo = page_fragment_content.content_photos.find_or_initialize_by(description: block_label)

      if ENV["RAILS_ENV"] == "test"
        # don't create photos for tests
        return nil
      end
      begin

        photo.image = photo_file
        # photo.image = Pwb::Engine.root.join(photo_file).open
        photo.save!
      rescue Exception => e
        # log exception to console
        p e
        # if photo
        #   photo.destroy!
        # end
      end
      # if photo
      #   photo.content = page_fragment_content
      # end
      return photo
    end


    def set_fragment_html fragment_label, locale, new_fragment_html
      content_key = slug + "_" + fragment_label
      # save in content model associated with page
      page_fragment_content = contents.find_or_create_by(key: content_key)
      content_html_col = "raw_" + locale + "="
      # above is the col used by globalize gem to store localized data
      # page_fragment_content[content_html_col] = fragment_html
      page_fragment_content.send content_html_col, new_fragment_html
      page_fragment_content.save!

      return page_fragment_content
    end

    def set_fragment_details fragment_label, locale, fragment_details
      # ensure path exists in details col
      unless details["fragments"].present?
        details["fragments"] = {}
      end
      unless details["fragments"][fragment_label].present?
        details["fragments"][fragment_label] = {}
      end

      # locale_label_fragments = label_fragments[locale].present? ? label_fragments[locale] : { label => { locale => fragment_details  }}
      details["fragments"][fragment_label][locale] = fragment_details
      return details["fragments"][fragment_label][locale]
    end

    # def as_json(options = nil)
    #   super({only: [
    #            "sort_order_top_nav", "show_in_top_nav",
    #            "sort_order_footer", "show_in_footer",
    #            "slug", "link_path","details","visible"
    #          ],
    #          methods: [
    #            "link_title_en","link_title_es",
    #            "link_title_de", "link_title_fr",
    #            "link_title_ru",
    #            "page_title_en","page_title_es",
    #            "page_title_de", "page_title_fr",
    #            "page_title_ru",
    #            "raw_html_en","raw_html_es",
    #            "raw_html_de", "raw_html_fr",
    #            "raw_html_ru",
    #   ]}.merge(options || {}))
    # end
    # above can be called on a result set from a query like so:
    # Page.all.as_json
    # Below can only be called on a single record like so:
    # Page.first.as_json
    def as_json_for_admin(options = nil)
      as_json({only: [
                 "sort_order_top_nav", "show_in_top_nav",
                 "sort_order_footer", "show_in_footer",
                 "slug", "link_path","visible"
               ],
               methods: admin_globalize_attribute_names}.merge(options || {}))
    end

    def admin_globalize_attribute_names

      self.globalize_attribute_names.push :page_fragments, :setup, :visible_page_parts, :page_contents
      # return "link_title_en","link_title_es", "link_title_de",
      #                    "link_title_ru", "link_title_fr"
    end

    def setup
      # gets config info for fragments from associated page_setup model (which reads from json config files)
      return page_setup.present? ? page_setup.attributes.slice(:fragment_configs) : {}
    end

    def page_contents
      return contents
    end

    def visible_page_parts
      return details["visiblePageParts"]
    end

    def page_fragments
      return details["fragments"]
    end
  end
end
