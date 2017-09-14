# To reload from console:
# load "#{Pwb::Engine.root}/lib/pwb/content_translations_seeder.rb"
module Pwb
  class ContentTranslationsSeeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed_content_translations                                  1 ↵

      def seed_content_translations!
        I18n.available_locales.each do |locale|
          seed_locale locale.to_s
        end
      end

      protected

      def seed_locale locale
        locale_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'content_translations', locale + '.yml')
        unless File.exist? locale_seed_file
          return
        end
        yml = YAML.load_file(locale_seed_file)

        Pwb::PageSetup.all.each do |page_setup|
          page_setup.pages.each do |page|
            page_setup.fragment_configs.each do |fragment_config|
              begin
                if yml[locale][page.slug][fragment_config["label"]]
                  set_page_block_content locale, page.slug, fragment_config, yml[locale][page.slug][fragment_config["label"]]
                end
              rescue NoMethodError => e

              end
            end
          end
        end
      end

      def set_page_block_content locale, page_slug, fragment_config, content_for_page_fragment
        page = Pwb::Page.find_by_slug page_slug
        fragment_label = fragment_config["label"]

        # ensure path exists in details col
        unless page.details["fragments"].present?
          page.details["fragments"] = {}
        end
        unless page.details["fragments"][fragment_label].present?
          page.details["fragments"][fragment_label] = {}
        end

        content_for_pf_locale = {"blocks" => {}}
        # {"blocks"=>{"title_a"=>{"content"=>"about our agency"}, "content_a"=>{"content"=>""}}}
        fragment_config["editorBlocks"].each do |colBlocks|
          colBlocks.each do |rowBlocks|
            row_block_label = rowBlocks["label"]
            row_block_content = ""
            if content_for_page_fragment[row_block_label]
              row_block_content = content_for_page_fragment[row_block_label]
            end
            content_for_pf_locale["blocks"][row_block_label] = {"content"=>row_block_content}
          end
        end


        ac = ActionController::Base.new()
        fragment_html = ac.render_to_string :partial => "pwb/fragments/#{fragment_label}",  :locals => { page_part: content_for_pf_locale["blocks"]}

        # below might be moved to be saved in associated content model
        content_for_pf_locale["html"] = fragment_html

        page.details["fragments"][fragment_label][locale] = content_for_pf_locale
        page.save!

      end

    end
  end
end
