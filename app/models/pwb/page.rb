module Pwb
  # added July 2017
  # has details json col where page_fragment info is stored
  class Page < ApplicationRecord
    extend ActiveHash::Associations::ActiveRecordExtensions
    # belongs_to_active_hash :page_setup, optional: true, foreign_key: "setup_id", class_name: "Pwb::PageSetup", shortcuts: [:friendly_name], primary_key: "id"

    has_many :links, foreign_key: "page_slug", primary_key: "slug"
    has_one :main_link, -> { where(placement: :top_nav) }, foreign_key: "page_slug", primary_key: "slug", class_name: "Pwb::Link"
    # , :conditions => ['placement = ?', :admin]

    has_many :page_parts, foreign_key: "page_slug", primary_key: "slug"

    has_many :page_contents
    has_many :contents, :through => :page_contents
    # https://stackoverflow.com/questions/5856838/scope-with-join-on-has-many-through-association
    has_many :ordered_visible_page_contents, -> { ordered_visible }, :class_name => 'PageContent'
    # below would get me the correct items but the order gets lost:
    # has_many :ordered_visible_contents, :source => :content, :through => :ordered_visible_page_contents
    # note, even where ordered_visible_contents exist,
    # @page.ordered_visible_contents.first will return nill
    # @page.ordered_visible_contents.all.first will return content

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

    # def compose_contents
    #   content_to_show = []
    #   components = []
    #   ordered_visible_page_contents.each do |page_content|
    #     if page_content.is_rails_part
    #       components.push page_content.page_part_key
    #     else
    #       content = page_content.content.present? ? page_content.content.raw : ""
    #       content_to_show.push content
    #     end
    #   end
    #   return {
    #     content_to_show: content_to_show,
    #     components: components
    #   }
    # end

    # used by page_controller to create a photo (from upload) that can
    # later be used in fragment html
    def create_fragment_photo page_part_key, block_label, photo_file
      # content_key = self.slug + "_" + page_part_key
      # get content model associated with page and fragment
      page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)

      if ENV["RAILS_ENV"] == "test"
        # don't create photos for tests
        return nil
      end
      begin
        photo = page_fragment_content.content_photos.create(block_key: block_label)
        photo.image = photo_file
        # photo.image = Pwb::Engine.root.join(photo_file).open
        photo.save!
      rescue Exception => e
        # log exception to console
        print e
        # if photo
        #   photo.destroy!
        # end
      end
      return photo
    end


    # when seeding I only need to ensure that a photo exists for the fragment
    # so will return existing photo if it can be found
    def seed_fragment_photo page_part_key, block_label, photo_file
      # content_key = self.slug + "_" + page_part_key
      # get in content model associated with page and fragment
      page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)
      photo = page_fragment_content.content_photos.find_by_block_key(block_label)

      if photo.present?
        return photo
      else
        photo = page_fragment_content.content_photos.create(block_key: block_label)
      end

      if ENV["RAILS_ENV"] == "test"
        # don't create photos for tests
        return nil
      end
      begin
        # if photo_file.is_a?(String)
        # photo.image = photo_file
        photo.image = Pwb::Engine.root.join(photo_file).open
        photo.save!
        print "#{self.slug}--#{page_part_key} image created: #{photo.optimized_image_url}\n"
        # reload the record to ensure that url is available
        photo.reload
        print "#{self.slug}--#{page_part_key} image created: #{photo.optimized_image_url}(after reload..)"
      rescue Exception => e
        # log exception to console
        print e
      end
      return photo
    end

    def set_fragment_sort_order page_part_key, sort_order
      page_fragment_content = contents.find_by_page_part_key page_part_key
      # using join model for sorting and visibility as it
      # will allow use of same content by different pages
      # with different settings for sorting and visibility
      page_content_join_model = page_fragment_content.page_contents.find_by_page_id self.id
      page_content_join_model.sort_order = sort_order
      page_content_join_model.save!
    end

    def set_fragment_visibility page_part_key, visible_on_page
      page_fragment_content = contents.find_by_page_part_key page_part_key
      # page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)

      unless page_fragment_content.present?
        return
      end
      page_content_join_model = page_fragment_content.page_contents.find_by_page_id self.id
      page_content_join_model.visible_on_page = visible_on_page
      page_content_join_model.save!
    end

    # currently only used in
    # /pwb/spec/controllers/pwb/welcome_controller_spec.rb
    def set_fragment_html page_part_key, locale, new_fragment_html
      # content_key = slug + "_" + page_part_key
      # save in content model associated with page
      page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)
      content_html_col = "raw_" + locale + "="
      # above is the col used by globalize gem to store localized data
      # page_fragment_content[content_html_col] = fragment_html
      page_fragment_content.send content_html_col, new_fragment_html
      page_fragment_content.save!

      return page_fragment_content
    end


    def update_page_part_content  page_part_key, locale, fragment_block
      # save the block contents (in associated page_part model)
      json_fragment_block = set_page_part_block_contents page_part_key, locale, fragment_block
      # retrieve the contents saved above and use to rebuild html for that page_part
      # (and save it in associated page_content model)
      fragment_html = rebuild_page_content page_part_key, locale

      return { json_fragment_block: json_fragment_block, fragment_html: fragment_html }
    end

    # def parse_page_part page_part_key, content_for_pf_locale

    #   page_part = self.page_parts.find_by_page_part_key page_part_key

    #   if page_part.present?
    #     l_template = Liquid::Template.parse(page_part.template)
    #     fragment_html = l_template.render('page_part' => content_for_pf_locale["blocks"] )
    #     p "#{page_part_key} content for #{self.slug} page parsed."

    #   else
    #     fragment_html = ""
    #   end

    #   # fragment_html = l_template.render('page_part' => content_for_pf_locale["blocks"] )
    #   # ac = ActionController::Base.new()
    #   # # render html for fragment with associated partial
    #   # fragment_html = ac.render_to_string :partial => "pwb/fragments/#{page_part_key}",  :locals => { page_part: content_for_pf_locale["blocks"]}
    #   return fragment_html
    # end



    # def as_json(options = nil)
    #   super({only: ["sort_order_top_nav", "show_in_top_nav"],
    #          methods: ["link_title_en","link_title_es"
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
               methods: admin_attribute_names}.merge(options || {}))
    end

    def admin_attribute_names

      self.globalize_attribute_names.push :page_contents, :page_parts
      # return "link_title_en","link_title_es", "link_title_de",
    end

    # def page_fragment_blocks
    #   return details["fragments"]
    # end

    private




    # called by seeder and Api::V1::PageController to set block contents
    # on page_part model
    def set_page_part_block_contents page_part_key, locale, fragment_details
      page_part = self.page_parts.find_by_page_part_key page_part_key
      if page_part.present?
        page_part.block_contents[locale] = fragment_details
        page_part.save!
        # fragment_details passed in might be a params object
        # - retrieving what has just been saved will return it as JSON
        fragment_details = page_part.block_contents[locale]
      end

      return fragment_details
    end

    # Will retrieve saved page_part blocks and use that along with template
    # to rebuild page_content html
    def rebuild_page_content page_part_key, locale
      page_part = self.page_parts.find_by_page_part_key page_part_key

      if page_part.present?
        l_template = Liquid::Template.parse(page_part.template)
        new_fragment_html = l_template.render('page_part' => page_part.block_contents[locale]["blocks"] )
        # p "#{page_part_key} content for #{self.slug} page parsed."
        # save in content model associated with page
        page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)
        content_html_col = "raw_" + locale + "="
        # above is the col used by globalize gem to store localized data
        # page_fragment_content[content_html_col] = new_fragment_html
        page_fragment_content.send content_html_col, new_fragment_html
        page_fragment_content.save!

        # set page_part_key value on join model
        page_content_join_model = page_fragment_content.page_contents.find_by_page_id self.id
        page_content_join_model.page_part_key = page_part_key
        page_content_join_model.save!


      else
        new_fragment_html = ""
      end

      return new_fragment_html
    end


  end
end
