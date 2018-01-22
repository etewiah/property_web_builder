module Pwb
  class PagePartManager
    attr_accessor :page_part_key, :page_part, :container

    def initialize(page_part_key, container)
      raise "Please provide valid container" unless container.present?
      self.page_part_key = page_part_key
      self.container = container
      self.page_part = container.get_page_part page_part_key
      # PagePart.find_by_page_part_key page_part_key
      raise "Please provide valid page_part_key" unless page_part.present?
    end

    def find_or_create_content
      # sets up the connection between a container and content model
      # ensuring the intermediate page_content join is created too
      page_content_join_model = container.page_contents.find_or_create_by(page_part_key: page_part_key)
      unless page_content_join_model.content.present?
        page_content_join_model.create_content(page_part_key: page_part_key)
        # without calling save! below, content and page_content will not be associated
        page_content_join_model.save!
      end
      page_content_join_model.content
      # just creating contents like below will result in join_model without page_part_key
      # page_fragment_content = container.contents.find_or_create_by(page_part_key: page_part_key)
    end

    def get_join_model(container)
      page_content_join_model = container.page_contents.find_by_page_part_key page_part_key
      # current_website.id
    end

    # container can be either a page or the website
    def seed_container_block_content(locale, seed_content)
      page_part_editor_setup = page_part.editor_setup
      raise "Invalid editorBlocks for page_part_editor_setup" unless (page_part_editor_setup && page_part_editor_setup["editorBlocks"].present?)
      # page = page_part.page
      # page_part_key uniquely identifies a fragment
      # page_part_key = page_part.page_part_key

      # container for json to be attached to page details
      locale_block_content_json = {"blocks" => {}}
      # {"blocks"=>{"title_a"=>{"content"=>"about our agency"}, "content_a"=>{"content"=>""}}}
      page_part_editor_setup["editorBlocks"].each do |configColBlocks|
        configColBlocks.each do |configRowBlock|
          row_block_label = configRowBlock["label"]
          row_block_content = ""
          # find the content for current block from within the seed content
          if seed_content[row_block_label]
            if configRowBlock["isImage"]
              photo = seed_fragment_photo row_block_label, seed_content[row_block_label]
              if photo.present? && photo.optimized_image_url.present?
                # optimized_image_url is defined in content_photo and will
                # return cloudinary url or filesystem url depending on settings
                row_block_content = photo.optimized_image_url
              else
                row_block_content = "http://via.placeholder.com/350x250"
              end
            else
              row_block_content = seed_content[row_block_label]
            end
          end
          locale_block_content_json["blocks"][row_block_label] = {"content" => row_block_content}
        end
      end
      # # save the block contents (in associated page_part model)
      # updated_details = container.set_page_part_block_contents page_part_key, locale, locale_block_content_json
      # # retrieve the contents saved above and use to rebuild html for that page_part
      # # (and save it in associated page_content model)
      # fragment_html = container.rebuild_page_content page_part_key, locale

      update_page_part_content page_part_key, locale, locale_block_content_json

      p " #{page_part_key} content set for #{locale}."
    end

    private

    def update_page_part_content  page_part_key, locale, fragment_block
      # save the block contents (in associated page_part model)
      json_fragment_block = set_page_part_block_contents page_part_key, locale, fragment_block
      # retrieve the contents saved above and use to rebuild html for that page_part
      # (and save it in associated page_content model)
      fragment_html = rebuild_page_content locale
      return { json_fragment_block: json_fragment_block, fragment_html: fragment_html }
    end



    # set block contents
    # on page_part model
    def set_page_part_block_contents page_part_key, locale, fragment_details
      # page_part = self.page_parts.find_by_page_part_key page_part_key
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
    def rebuild_page_content locale
      unless page_part && page_part.template
        raise "page_part with valid template not available"
      end
      # page_part = self.page_parts.find_by_page_part_key page_part_key

      if page_part.present?
        l_template = Liquid::Template.parse(page_part.template)
        new_fragment_html = l_template.render('page_part' => page_part.block_contents[locale]["blocks"] )
        # p "#{page_part_key} content for #{self.slug} page parsed."
        # save in content model associated with page

        page_fragment_content = find_or_create_content
        # container.contents.find_or_create_by(page_part_key: page_part_key)
        content_html_col = "raw_" + locale + "="
        # above is the col used by globalize gem to store localized data
        # page_fragment_content[content_html_col] = new_fragment_html
        page_fragment_content.send content_html_col, new_fragment_html
        page_fragment_content.save!

        # set page_part_key value on join model
        page_content_join_model = get_join_model container
        # page_fragment_content.page_contents.find_by_page_id self.id
        page_content_join_model.page_part_key = page_part_key
        page_content_join_model.save!
      else
        new_fragment_html = ""
      end

      return new_fragment_html
    end

    # when seeding I only need to ensure that a photo exists for the fragment
    # so will return existing photo if it can be found
    def seed_fragment_photo block_label, photo_file
      # content_key = self.slug + "_" + page_part_key
      # get in content model associated with page and fragment
      # join_model = page_contents.find_or_create_by(page_part_key: page_part_key)
      # page_fragment_content = join_model.create_content(page_part_key: page_part_key)
      # join_model.save!
      # page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)

      page_fragment_content = find_or_create_content

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

  end
end
