module Pwb
  class PagePartManager
    attr_accessor :page_part_key, :page_part, :container

    def initialize(page_part_key, container)
      self.page_part_key = page_part_key
      self.container = container
      self.page_part = PagePart.find_by_page_part_key page_part_key
    end

    def find_or_create_content
      # right now each time this is called, new content is created
      # -need to TDD prevent this...
      page_content_join_model = container.page_contents.find_or_create_by(page_part_key: page_part_key)
# byebug
      if page_content_join_model.content.present?
        page_content_join_model.content
      else
        page_content_join_model.create_content(page_part_key: page_part_key)
      end
      # just creating contents like below will result in join_model without page_part_key
      # page_fragment_content = container.contents.find_or_create_by(page_part_key: page_part_key)
    end

    def get_join_model(container)
      page_content_join_model = container.page_contents.find_by_page_part_key page_part_key
      # current_website.id
    end

    # container can be either a page or the website
    def seed_container_block_content(locale, seed_content, container)
      page_part_editor_setup = page_part.editor_setup
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
              photo = container.seed_fragment_photo page_part_key, row_block_label, seed_content[row_block_label]
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

      result = update_page_part_content page_part_key, locale, locale_block_content_json

      p "website #{page_part_key} content set for #{locale}."

      # p "#{container.slug} page #{page_part_key} content set for #{locale}."
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
      # page_part = self.page_parts.find_by_page_part_key page_part_key

      if page_part.present?
        l_template = Liquid::Template.parse(page_part.template)
        new_fragment_html = l_template.render('page_part' => page_part.block_contents[locale]["blocks"] )
        # p "#{page_part_key} content for #{self.slug} page parsed."
        # save in content model associated with page
        # byebug
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

  end
end
