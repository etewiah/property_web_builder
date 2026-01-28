# frozen_string_literal: true

namespace :pwb do
  namespace :containers do
    desc "Create a demo container page part with children (for testing/demonstration)"
    task demo: :environment do
      website = Pwb::Website.first
      raise "No website found. Please run db:seed first." unless website

      page = website.pages.find_by(slug: "contact-us")
      raise "Contact page not found. Please run db:seed first." unless page

      puts "Creating container demo on #{website.subdomain}'s contact page..."

      # Create the container page content
      container = Pwb::PageContent.create!(
        page: page,
        website: website,
        page_part_key: "layout_two_column_equal",
        sort_order: 50,
        visible_on_page: true
      )
      puts "  Created container: #{container.page_part_key} (id: #{container.id})"

      # Create a contact form in the left slot
      left_child = Pwb::PageContent.create!(
        page: page,
        website: website,
        page_part_key: "contact_general_enquiry",
        parent_page_content: container,
        slot_name: "left",
        sort_order: 1,
        visible_on_page: true
      )
      puts "  Created child in 'left' slot: #{left_child.page_part_key} (id: #{left_child.id})"

      # Create content for the form
      form_content = Pwb::Content.create!(
        website: website,
        page_part_key: "contact_general_enquiry"
      )
      form_content.update!(
        raw: {
          "section_title" => { "content" => "Send us a message" },
          "section_subtitle" => { "content" => "Fill out the form and we'll get back to you within 24 hours." },
          "show_phone_field" => { "content" => "true" },
          "show_subject_field" => { "content" => "false" },
          "submit_button_text" => { "content" => "Send Message" },
          "success_message" => { "content" => "Thank you! We'll be in touch soon." },
          "form_style" => { "content" => "default" }
        }
      )
      left_child.update!(content: form_content)
      puts "    Added content to contact form"

      # Create a CTA banner in the right slot
      right_child = Pwb::PageContent.create!(
        page: page,
        website: website,
        page_part_key: "cta/cta_banner",
        parent_page_content: container,
        slot_name: "right",
        sort_order: 1,
        visible_on_page: true
      )
      puts "  Created child in 'right' slot: #{right_child.page_part_key} (id: #{right_child.id})"

      # Create content for the CTA
      cta_content = Pwb::Content.create!(
        website: website,
        page_part_key: "cta/cta_banner"
      )
      cta_content.update!(
        raw: {
          "title" => { "content" => "Need Help?" },
          "subtitle" => { "content" => "Our team is here to answer your questions." },
          "button_text" => { "content" => "Call Now" },
          "button_link" => { "content" => "tel:+1234567890" },
          "style" => { "content" => "primary" }
        }
      )
      right_child.update!(content: cta_content)
      puts "    Added content to CTA banner"

      puts "\nContainer demo created successfully!"
      puts "Container has #{container.child_page_contents.count} children:"
      container.available_slots.each do |slot|
        children = container.children_in_slot(slot)
        puts "  - #{slot}: #{children.count} item(s)"
        children.each { |c| puts "      • #{c.page_part_key}" }
      end
    end

    desc "Remove the demo container (cleanup)"
    task remove_demo: :environment do
      website = Pwb::Website.first
      raise "No website found." unless website

      page = website.pages.find_by(slug: "contact-us")
      raise "Contact page not found." unless page

      # Find the demo container
      container = page.page_contents.find_by(page_part_key: "layout_two_column_equal")

      unless container
        puts "No demo container found on contact page."
        exit
      end

      puts "Removing container demo..."

      # Remove children first (they will be nullified by dependent: :nullify, but let's clean up properly)
      container.child_page_contents.each do |child|
        child.content&.destroy
        child.destroy
        puts "  Removed child: #{child.page_part_key}"
      end

      container.destroy
      puts "  Removed container"
      puts "Container demo removed successfully!"
    end

    desc "List all containers in the system"
    task list: :environment do
      containers = Pwb::PageContent.where(page_part_key: Pwb::PagePartLibrary.container_parts.keys)

      if containers.empty?
        puts "No containers found in the system."
        exit
      end

      puts "Found #{containers.count} container(s):\n\n"

      containers.includes(:page, :website, :child_page_contents).each do |container|
        puts "Container: #{container.page_part_key}"
        puts "  Page: #{container.page&.slug || 'N/A'}"
        puts "  Website: #{container.website&.subdomain || 'N/A'}"
        puts "  Children: #{container.child_page_contents.count}"
        container.available_slots.each do |slot|
          children = container.children_in_slot(slot)
          next if children.empty?
          puts "    #{slot}:"
          children.each { |c| puts "      - #{c.page_part_key} (sort: #{c.sort_order})" }
        end
        puts ""
      end
    end
  end
end
