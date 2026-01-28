# frozen_string_literal: true

namespace :pwb do
  namespace :containers do
    desc "Seed example container page contents for demonstration"
    task seed_examples: :environment do
      puts "Seeding container page content examples..."

      website = Pwb::Website.first
      unless website
        puts "No website found. Please run rake app:pwb:db:seed first."
        exit 1
      end

      ActsAsTenant.with_tenant(website) do
        Pwb::Current.website = website

        # Find the about-us page or create one
        page = website.pages.find_by(slug: 'about-us')
        unless page
          puts "Creating about-us page..."
          page = website.pages.create!(
            slug: 'about-us',
            visible: true,
            page_title: 'About Us'
          )
        end

        puts "Creating container layout examples on '#{page.slug}' page..."

        # Example 1: Two-column layout with CTA and Contact Form
        create_two_column_example(website, page)

        # Example 2: Three-column layout with content blocks
        create_three_column_example(website, page)

        # Example 3: Sidebar layout
        create_sidebar_example(website, page)

        puts "Container examples seeded successfully!"
        puts "\nView the examples at: /p/about-us"
      end
    end

    desc "Remove container examples from about-us page"
    task remove_examples: :environment do
      website = Pwb::Website.first
      unless website
        puts "No website found."
        exit 1
      end

      ActsAsTenant.with_tenant(website) do
        page = website.pages.find_by(slug: 'about-us')
        unless page
          puts "No about-us page found."
          exit 0
        end

        # Remove containers (which will cascade to children due to foreign key)
        container_keys = %w[
          layout/layout_two_column_equal
          layout/layout_three_column_equal
          layout/layout_sidebar_right
        ]

        count = page.page_contents.where(page_part_key: container_keys).destroy_all.count
        puts "Removed #{count} container page contents."
      end
    end

    desc "List all container page contents"
    task list: :environment do
      website = Pwb::Website.first
      unless website
        puts "No website found."
        exit 1
      end

      ActsAsTenant.with_tenant(website) do
        containers = Pwb::PageContent.where(website_id: website.id)
                                     .select { |pc| pc.container? }

        if containers.empty?
          puts "No container page contents found."
        else
          puts "Container Page Contents:"
          puts "-" * 60

          containers.each do |container|
            page = container.page
            children = container.child_page_contents
            puts "\n#{container.page_part_key} (ID: #{container.id})"
            puts "  Page: #{page&.slug || 'website-level'}"
            puts "  Visible: #{container.visible_on_page}"
            puts "  Children: #{children.count}"

            children.group_by(&:slot_name).each do |slot_name, slot_children|
              puts "    #{slot_name}: #{slot_children.map(&:page_part_key).join(', ')}"
            end
          end
        end
      end
    end

    private

    def create_two_column_example(website, page)
      puts "  Creating two-column layout..."

      # Create the container
      container = page.page_contents.find_or_create_by!(
        page_part_key: 'layout/layout_two_column_equal',
        website_id: website.id
      ) do |pc|
        pc.sort_order = 10
        pc.visible_on_page = true
        pc.label = 'Two Column Demo'
      end

      # Create left column child (CTA Banner)
      left_child = page.page_contents.find_or_create_by!(
        page_part_key: 'cta/cta_banner',
        parent_page_content_id: container.id,
        slot_name: 'left',
        website_id: website.id
      ) do |pc|
        pc.sort_order = 1
        pc.visible_on_page = true
        pc.label = 'Left CTA'
      end

      # Create or find the associated PagePart and Content for left child
      seed_page_part_content(website, page, left_child, {
        title: { en: 'Get Started Today', es: 'Empieza Hoy' },
        subtitle: { en: 'Let us help you find your perfect home', es: 'Te ayudamos a encontrar tu hogar perfecto' },
        button_text: { en: 'Contact Us', es: 'Contáctanos' },
        button_link: '/contact',
        style: 'primary'
      })

      # Create right column child (Contact Form)
      right_child = page.page_contents.find_or_create_by!(
        page_part_key: 'contact_general_enquiry',
        parent_page_content_id: container.id,
        slot_name: 'right',
        website_id: website.id
      ) do |pc|
        pc.sort_order = 1
        pc.visible_on_page = true
        pc.label = 'Right Contact Form'
      end

      seed_page_part_content(website, page, right_child, {
        section_title: { en: 'Send Us a Message', es: 'Envíanos un Mensaje' },
        section_subtitle: { en: "We'll get back to you within 24 hours", es: 'Te responderemos en 24 horas' },
        submit_button_text: { en: 'Send', es: 'Enviar' },
        success_message: { en: 'Thank you! We received your message.', es: '¡Gracias! Hemos recibido tu mensaje.' }
      })

      puts "    Created: #{container.page_part_key} with #{container.child_page_contents.count} children"
    end

    def create_three_column_example(website, page)
      puts "  Creating three-column layout..."

      container = page.page_contents.find_or_create_by!(
        page_part_key: 'layout/layout_three_column_equal',
        website_id: website.id
      ) do |pc|
        pc.sort_order = 20
        pc.visible_on_page = true
        pc.label = 'Three Column Demo'
      end

      # Create children for each column
      %w[left center right].each_with_index do |slot, index|
        child = page.page_contents.find_or_create_by!(
          page_part_key: 'cta/cta_banner',
          parent_page_content_id: container.id,
          slot_name: slot,
          website_id: website.id
        ) do |pc|
          pc.sort_order = 1
          pc.visible_on_page = true
          pc.label = "#{slot.capitalize} Column CTA"
        end

        titles = ['Buy', 'Sell', 'Rent']
        seed_page_part_content(website, page, child, {
          title: { en: titles[index], es: titles[index] },
          subtitle: { en: "#{titles[index]} your property with us", es: "#{titles[index]} tu propiedad con nosotros" },
          button_text: { en: 'Learn More', es: 'Más Info' },
          button_link: "/#{titles[index].downcase}",
          style: 'light'
        })
      end

      puts "    Created: #{container.page_part_key} with #{container.child_page_contents.count} children"
    end

    def create_sidebar_example(website, page)
      puts "  Creating sidebar layout..."

      container = page.page_contents.find_or_create_by!(
        page_part_key: 'layout/layout_sidebar_right',
        website_id: website.id
      ) do |pc|
        pc.sort_order = 30
        pc.visible_on_page = true
        pc.label = 'Sidebar Demo'
      end

      # Main content area
      main_child = page.page_contents.find_or_create_by!(
        page_part_key: 'content_html',
        parent_page_content_id: container.id,
        slot_name: 'main',
        website_id: website.id
      ) do |pc|
        pc.sort_order = 1
        pc.visible_on_page = true
        pc.label = 'Main Content'
      end

      seed_page_part_content(website, page, main_child, {
        content_html: {
          en: '<h2>Welcome to Our Agency</h2><p>We have been serving the community for over 20 years with exceptional real estate services.</p>',
          es: '<h2>Bienvenido a Nuestra Agencia</h2><p>Hemos servido a la comunidad durante más de 20 años con servicios inmobiliarios excepcionales.</p>'
        }
      })

      # Sidebar content
      sidebar_child = page.page_contents.find_or_create_by!(
        page_part_key: 'cta/cta_banner',
        parent_page_content_id: container.id,
        slot_name: 'sidebar',
        website_id: website.id
      ) do |pc|
        pc.sort_order = 1
        pc.visible_on_page = true
        pc.label = 'Sidebar CTA'
      end

      seed_page_part_content(website, page, sidebar_child, {
        title: { en: 'Need Help?', es: '¿Necesitas Ayuda?' },
        subtitle: { en: 'Contact our team', es: 'Contacta a nuestro equipo' },
        button_text: { en: 'Call Now', es: 'Llama Ahora' },
        button_link: 'tel:+123456789',
        style: 'dark'
      })

      puts "    Created: #{container.page_part_key} with #{container.child_page_contents.count} children"
    end

    def seed_page_part_content(website, page, page_content, field_values)
      page_part_key = page_content.page_part_key

      # Find or create the PagePart record
      page_part = Pwb::PagePart.find_or_create_by!(
        website_id: website.id,
        page_part_key: page_part_key,
        page_slug: page.slug
      ) do |pp|
        pp.block_contents = {}
        pp.show_in_editor = true
      end

      # Build block_contents for each locale
      locales = website.supported_locales.presence || ['en']
      locales.each do |locale|
        locale_str = locale.to_s
        blocks = {}

        field_values.each do |field_name, value|
          content = if value.is_a?(Hash)
                      value[locale.to_sym] || value[locale_str] || value[:en] || value['en'] || value.values.first
                    else
                      value
                    end
          blocks[field_name.to_s] = { 'content' => content }
        end

        page_part.block_contents[locale_str] = { 'blocks' => blocks }
      end

      page_part.save!

      # Render and save the content
      render_page_content(website, page_content, page_part)
    end

    def render_page_content(website, page_content, page_part)
      page_part_key = page_content.page_part_key

      # Skip rendering for containers - they render dynamically
      return if page_content.container?

      # Get or create the Content record
      content = page_content.content || page_content.create_content(
        page_part_key: page_part_key,
        website_id: website.id
      )
      page_content.save! if page_content.content_id_changed?

      # Get the template
      template_path = Pwb::PagePartLibrary.template_path(page_part_key)
      return unless template_path && File.exist?(template_path)

      template_content = page_part.template_content.presence || File.read(template_path)
      liquid_template = Liquid::Template.parse(template_content)

      # Render for each locale
      locales = website.supported_locales.presence || ['en']
      locales.each do |locale|
        locale_str = locale.to_s
        block_contents = page_part.block_contents.dig(locale_str, 'blocks') || {}

        rendered_html = liquid_template.render('page_part' => block_contents)

        # Save using Mobility's locale-specific setter
        content.send("raw_#{locale_str}=", rendered_html)
      end

      content.save!
    end
  end
end
