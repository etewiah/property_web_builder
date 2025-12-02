namespace :pwb do
  namespace :db do
    desc "Update page parts from seed YAML files and rebuild content"
    task update_page_parts: :environment do
      page_parts_dir = Rails.root.join("db", "yml_seeds", "page_parts")

      page_parts_dir.children.each do |file|
        next unless file.extname == ".yml"

        puts "Processing #{file.basename}..."

        # Load the YAML file
        yml_content = YAML.load_file(file)

        # The YAML is an array of hashes, usually with one element
        part_config = yml_content.first

        page_part_key = part_config["page_part_key"]
        page_slug = part_config["page_slug"]

        # Find the existing PagePart
        page_part = Pwb::PagePart.find_by(page_part_key: page_part_key, page_slug: page_slug)

        if page_part
          # Update attributes
          page_part.update!(part_config)
          puts "  Updated PagePart: #{page_part_key} for page #{page_slug}"

          # Rebuild content for all available locales
          I18n.available_locales.each do |locale|
            # Determine container
            container = nil
            if page_slug == "website"
              container = Pwb::Website.last
            else
              container = Pwb::Page.find_by_slug(page_slug)
            end

            if container
              manager = Pwb::PagePartManager.new(page_part_key, container)

              # Load content from translation YAMLs
              locale_seed_file = Rails.root.join("db", "yml_seeds", "content_translations", locale.to_s + ".yml")
              if File.exist?(locale_seed_file)
                yml = YAML.load_file(locale_seed_file)
                # The structure is locale -> container_label (page_slug) -> page_part_key
                if yml[locale.to_s] && yml[locale.to_s][page_slug] && yml[locale.to_s][page_slug][page_part_key]
                  seed_content = yml[locale.to_s][page_slug][page_part_key]

                  # Update block contents and rebuild
                  manager.seed_container_block_content(locale.to_s, seed_content)
                  puts "    Seeded and rebuilt content for locale: #{locale}"
                else
                  puts "    No seed content found in #{locale}.yml for #{page_slug} -> #{page_part_key}"
                end
              else
                puts "    Translation file not found: #{locale_seed_file}"
              end

            else
              puts "    Container '#{page_slug}' not found."
            end
          end
        else
          puts "  PagePart not found: #{page_part_key} for page #{page_slug}. Creating it..."
          Pwb::PagePart.create!(part_config)
        end
      end

      # Clear cache to ensure new content is served
      Rails.cache.clear
      puts "Done. Cache cleared."
    end
  end
end
