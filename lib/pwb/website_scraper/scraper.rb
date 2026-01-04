# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'fileutils'

module Pwb
  module WebsiteScraper
    # Main orchestrator for scraping an existing PWB website and generating a seed pack.
    #
    # Usage:
    #   scraper = Pwb::WebsiteScraper::Scraper.new(
    #     base_url: 'https://site_to_scrape.com',
    #     pack_name: 'site_pack_name'
    #   )
    #   scraper.scrape!
    #   scraper.generate_seed_pack!
    #
    class Scraper
      attr_reader :base_url, :pack_name, :locales, :scraped_data, :output_path

      # Standard pages to scrape from a PWB site
      DEFAULT_PAGES = %w[home about-us contact-us sell].freeze

      # Output directory for scraped packs (git-ignored)
      SCRAPED_PACKS_DIR = 'db/seeds/site_import_packs'.freeze

      # @param base_url [String] The base URL of the website to scrape
      # @param pack_name [String] Name for the generated seed pack
      # @param locales [Array<String>] Locales to scrape (default: ['en'])
      # @param pages [Array<String>] Page slugs to scrape (default: DEFAULT_PAGES)

      def initialize(base_url:, pack_name:, locales: ['en'], pages: nil)
        @base_url = base_url.chomp('/')
        @pack_name = pack_name.to_s.parameterize.underscore
        @locales = Array(locales)
        @pages_to_scrape = pages || DEFAULT_PAGES
        @scraped_data = {
          agency: {},
          pages: {},
          navigation: [],
          images: [],
          theme: {}
        }
        @output_path = Rails.root.join(SCRAPED_PACKS_DIR, @pack_name)
      end

      # Scrape all content from the website
      def scrape!
        puts "Scraping #{base_url}..."

        # Scrape home page first to get agency info and navigation
        scrape_home_page

        # Scrape each configured page
        @pages_to_scrape.each do |page_slug|
          scrape_page(page_slug)
        end

        # Download images
        download_images

        puts "Scraping complete!"
        scraped_data
      end

      # Generate the seed pack YAML files from scraped data
      def generate_seed_pack!
        puts "Generating seed pack at #{output_path}..."

        FileUtils.mkdir_p(output_path)
        FileUtils.mkdir_p(output_path.join('content'))
        FileUtils.mkdir_p(output_path.join('images'))

        generate_pack_yml
        generate_content_files
        copy_images

        puts "Seed pack generated at: #{output_path}"
        output_path
      end

      private

      # Scrape the home page for agency info and navigation
      def scrape_home_page
        @locales.each do |locale|
          url = build_url('/', locale)
          puts "  Fetching home page: #{url}"

          doc = fetch_page(url)
          next unless doc

          # Extract agency info from first locale only
          if locale == @locales.first
            extract_agency_info(doc)
            extract_navigation(doc)
            extract_theme_info(doc)
          end

          # Extract home page content
          extract_page_content('home', doc, locale)
        end
      end

      # Scrape a specific page
      def scrape_page(page_slug)
        return if page_slug == 'home' # Already scraped

        @locales.each do |locale|
          url = build_url("/p/#{page_slug}", locale)
          puts "  Fetching page: #{url}"

          doc = fetch_page(url)
          next unless doc

          extract_page_content(page_slug, doc, locale)
        end
      end

      # Build URL with locale
      def build_url(path, locale)
        path = path.start_with?('/') ? path : "/#{path}"
        "#{base_url}/#{locale}#{path}"
      end

      # Fetch and parse a page
      def fetch_page(url)
        html = URI.open(url, 'User-Agent' => 'Mozilla/5.0 PropertyWebBuilder Scraper').read
        Nokogiri::HTML(html)
      rescue OpenURI::HTTPError => e
        puts "    Warning: Could not fetch #{url}: #{e.message}"
        nil
      rescue StandardError => e
        puts "    Error fetching #{url}: #{e.message}"
        nil
      end

      # Extract agency information from the page
      def extract_agency_info(doc)
        puts "  Extracting agency info..."

        agency = scraped_data[:agency]

        # Try to find agency name from various locations
        agency[:display_name] = extract_text(doc, [
          'header .logo-text', 'header h1', '.site-title', 'footer .company-name',
          '[class*="brand"]', '[class*="logo"] span'
        ])

        # Extract contact info
        agency[:email] = extract_email(doc)
        agency[:phone] = extract_phone(doc)

        # Extract address
        agency[:address] = extract_address(doc)

        # Extract social links
        agency[:social_links] = extract_social_links(doc)

        # Extract logo
        logo_url = extract_logo(doc)
        if logo_url
          scraped_data[:images] << { type: 'logo', url: logo_url, filename: 'logo.png' }
          agency[:logo] = 'logo.png'
        end

        puts "    Found: #{agency[:display_name]}"
      end

      # Extract navigation links
      def extract_navigation(doc)
        puts "  Extracting navigation..."

        nav_links = []

        # Try multiple selectors for navigation
        nav_selectors = ['nav a', 'header a', '.navigation a', '.menu a', '[class*="nav"] a']

        nav_selectors.each do |selector|
          doc.css(selector).each do |link|
            href = link['href']
            text = link.text.strip

            next if text.blank? || href.blank?
            next if href.start_with?('#', 'javascript:', 'mailto:', 'tel:')
            next if text.length > 50 # Skip long text (probably not nav)

            nav_links << {
              label: text,
              href: href,
              placement: 'header'
            }
          end
          break if nav_links.any? # Stop if we found links
        end

        # Deduplicate by href
        scraped_data[:navigation] = nav_links.uniq { |l| l[:href] }
        puts "    Found #{scraped_data[:navigation].size} navigation links"
      end

      # Extract theme/styling information
      def extract_theme_info(doc)
        puts "  Extracting theme info..."

        theme = scraped_data[:theme]

        # Try to extract primary color from CSS
        style_tags = doc.css('style').map(&:text).join("\n")

        # Look for common color patterns
        primary_color = style_tags.match(/--primary[^:]*:\s*(#[a-fA-F0-9]{3,6})/i)
        theme[:primary_color] = primary_color[1] if primary_color

        # Extract from inline styles or common classes
        hero = doc.at_css('[class*="hero"], [class*="banner"], .jumbotron')
        if hero
          bg_style = hero['style']
          if bg_style && bg_style.include?('background')
            bg_color = bg_style.match(/#[a-fA-F0-9]{3,6}/)
            theme[:hero_bg_color] = bg_color[0] if bg_color
          end
        end
      end

      # Extract page content
      def extract_page_content(page_slug, doc, locale)
        puts "    Extracting content for #{page_slug} (#{locale})..."

        scraped_data[:pages][page_slug] ||= {}
        page_data = scraped_data[:pages][page_slug]
        page_data[locale] ||= {}

        # Extract main content area
        main_content = extract_main_content(doc)
        page_data[locale][:main_content] = main_content if main_content.present?

        # Extract hero section if present
        hero = extract_hero_section(doc)
        page_data[locale][:hero] = hero if hero.present?

        # Extract any team/about sections
        if page_slug == 'about-us'
          team = extract_team_section(doc)
          page_data[locale][:team] = team if team.present?

          # Extract team member photos
          extract_team_images(doc)
        end

        # Extract images from this page
        extract_page_images(doc, page_slug)
      end

      # Extract main content block
      def extract_main_content(doc)
        # Create a clean copy of the document with header/footer removed
        clean_doc = strip_header_footer(doc)

        # First, try to find specific PWB page part containers
        pwb_selectors = [
          '.page-part', '[class*="page_part"]', '.pwb-content',
          'section[id*="page-part"]', '.content-section',
          '.our-agency-section', '.content-html-section', '.services-section'
        ]

        pwb_selectors.each do |selector|
          begin
            elements = clean_doc.css(selector)
            next if elements.empty?

            # Combine all page parts
            combined_html = elements.map { |el| clean_html(el) }.join("\n")
            return combined_html if combined_html.present? && combined_html.length > 100
          rescue Nokogiri::CSS::SyntaxError
            next
          end
        end

        # Standard content selectors
        content_selectors = [
          '.sticky-body', 'main article', '.content-area', '.page-content',
          '#content', 'main .container', '.main-content', 'article', 'main'
        ]

        content_selectors.each do |selector|
          begin
            element = clean_doc.at_css(selector)
            next unless element

            # Skip if it's mostly navigation or header content
            next if mostly_navigation?(element)

            # Clean up the HTML
            html = clean_html(element)
            return html if html.present? && html.length > 100
          rescue Nokogiri::CSS::SyntaxError
            next
          end
        end

        # Fallback: find the largest text block in the body
        extract_largest_text_block(clean_doc)
      end

      # Create a copy of the document with header and footer removed
      def strip_header_footer(doc)
        # Clone the document
        clean_doc = doc.dup

        # Remove header elements
        clean_doc.css('header, #divHeaderWrapper, .header, nav, .navbar, [class*="header"]').each(&:remove)

        # Remove footer elements
        clean_doc.css('footer, .footer, [class*="footer"]').each(&:remove)

        # Remove navigation elements
        clean_doc.css('[class*="nav"], [class*="menu"], .breadcrumb').each(&:remove)

        clean_doc
      end

      # Check if element is mostly navigation/header content
      def mostly_navigation?(element)
        link_count = element.css('a').size
        total_text = element.text.strip.length
        return false if total_text == 0

        # If links make up most of the content, it's probably nav
        link_text = element.css('a').map { |a| a.text.strip.length }.sum
        (link_text.to_f / total_text) > 0.7
      end

      # Find the element with the most text content
      def extract_largest_text_block(doc)
        candidates = []

        # Look for divs and sections with substantial text
        doc.css('div, section').each do |element|
          # Skip nav, header, footer by ancestry
          next if element.ancestors('nav, header, footer').any?

          # Skip by class/id patterns
          element_id = element['id'].to_s.downcase
          element_class = element['class'].to_s.downcase
          skip_patterns = /\b(nav|header|footer|menu|sidebar|topbar|contact.*header|hidden)/i
          next if element_class.match?(skip_patterns) || element_id.match?(skip_patterns)

          # Skip elements that are hidden
          next if element_class.include?('hidden')

          text_length = element.text.strip.length
          next if text_length < 200 # Skip small blocks

          # Skip if it's mostly navigation links
          next if mostly_navigation?(element)

          # Prefer elements with paragraphs and headings
          para_count = element.css('p').size
          heading_count = element.css('h1, h2, h3, h4').size
          candidates << {
            element: element,
            text_length: text_length,
            para_count: para_count,
            heading_count: heading_count
          }
        end

        # Score by text length, paragraphs, and headings
        best = candidates.max_by do |c|
          c[:text_length] + (c[:para_count] * 100) + (c[:heading_count] * 50)
        end
        return nil unless best

        clean_html(best[:element])
      end

      # Extract hero section
      def extract_hero_section(doc)
        hero_selectors = [
          '[class*="hero"]', '.banner', '.jumbotron', '.intro-section',
          '[class*="splash"]', '.header-image'
        ]

        hero_selectors.each do |selector|
          element = doc.at_css(selector)
          next unless element

          hero_data = {
            title: extract_text(element, ['h1', 'h2', '.hero-title', '.title']),
            subtitle: extract_text(element, ['h2', 'h3', 'p', '.subtitle', '.hero-subtitle']),
            cta_text: extract_text(element, ['a.btn', 'button', '.cta'])
          }

          # Extract hero background image
          bg_image = extract_background_image(element)
          if bg_image
            filename = "hero_#{SecureRandom.hex(4)}.jpg"
            scraped_data[:images] << { type: 'hero', url: bg_image, filename: filename }
            hero_data[:background_image] = filename
          end

          return hero_data.compact if hero_data.values.any?(&:present?)
        end

        nil
      end

      # Extract team section from about page
      def extract_team_section(doc)
        team_selectors = [
          '[class*="team"]', '.staff', '.agents', '.members',
          '[class*="about"] .grid', '.people'
        ]

        team_selectors.each do |selector|
          section = doc.at_css(selector)
          next unless section

          members = []
          member_cards = section.css('[class*="member"], [class*="person"], [class*="agent"], .card')

          member_cards.each_with_index do |card, idx|
            member = {
              name: extract_text(card, ['h3', 'h4', '.name', '.title']),
              role: extract_text(card, ['.role', '.position', '.job-title', 'h5']),
              bio: extract_text(card, ['p', '.bio', '.description']),
              email: extract_email(card)
            }
            members << member.compact if member[:name].present?
          end

          return { members: members } if members.any?
        end

        nil
      end

      # Extract team member images
      def extract_team_images(doc)
        doc.css('[class*="team"] img, .staff img, .agents img').each_with_index do |img, idx|
          src = img['src']
          next unless src.present?

          full_url = make_absolute_url(src)
          filename = "team_member_#{idx + 1}.jpg"
          scraped_data[:images] << { type: 'team', url: full_url, filename: filename }
        end
      end

      # Extract images from a page
      def extract_page_images(doc, page_slug)
        doc.css('main img, .content img, article img').each_with_index do |img, idx|
          src = img['src']
          next unless src.present?
          next if src.include?('data:') # Skip data URIs

          full_url = make_absolute_url(src)
          filename = "#{page_slug}_image_#{idx + 1}.jpg"
          scraped_data[:images] << { type: 'page', page: page_slug, url: full_url, filename: filename }
        end
      end

      # Helper methods for extraction

      def extract_text(doc, selectors)
        selectors.each do |selector|
          element = doc.at_css(selector)
          next unless element

          text = element.text.strip
          return text if text.present? && text.length < 500
        end
        nil
      end

      def extract_email(doc)
        # Look in href="mailto:..."
        mailto = doc.at_css('a[href^="mailto:"]')
        return mailto['href'].sub('mailto:', '').split('?').first if mailto

        # Look for email patterns in text
        text = doc.text
        email_match = text.match(/[\w.+-]+@[\w.-]+\.\w{2,}/i)
        email_match[0] if email_match
      end

      def extract_phone(doc)
        # Look in href="tel:..."
        tel = doc.at_css('a[href^="tel:"]')
        return tel['href'].sub('tel:', '').strip if tel

        # Look for phone patterns in text - be more specific
        text = doc.text

        # Match patterns like 902.453.1700 or +1 902-453-1700 or (902) 453-1700
        phone_patterns = [
          /(?:\+1[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}/,  # North American
          /\+\d{1,3}[\s.-]?\d{2,4}[\s.-]?\d{3,4}[\s.-]?\d{3,4}/  # International
        ]

        phone_patterns.each do |pattern|
          match = text.match(pattern)
          return match[0].strip if match
        end

        nil
      end

      def extract_address(doc)
        address_selectors = [
          'address', '.address', '[class*="location"]', '.contact-info address',
          'footer address', '[itemtype*="PostalAddress"]'
        ]

        address_selectors.each do |selector|
          element = doc.at_css(selector)
          next unless element

          text = element.text.strip.gsub(/\s+/, ' ')
          return text if text.present? && text.length < 200
        end
        nil
      end

      def extract_social_links(doc)
        social_patterns = {
          facebook: /facebook\.com/i,
          twitter: /twitter\.com|x\.com/i,
          linkedin: /linkedin\.com/i,
          instagram: /instagram\.com/i,
          youtube: /youtube\.com/i
        }

        links = {}
        doc.css('a[href*="facebook"], a[href*="twitter"], a[href*="linkedin"], a[href*="instagram"], a[href*="youtube"], a[href*="x.com"]').each do |link|
          href = link['href']
          social_patterns.each do |platform, pattern|
            links[platform] = href if href.match?(pattern)
          end
        end

        links.any? ? links : nil
      end

      def extract_logo(doc)
        logo_selectors = [
          'header img[class*="logo"]',
          '.logo img',
          'header .brand img',
          'header img'
        ]

        logo_selectors.each do |selector|
          begin
            img = doc.at_css(selector)
            next unless img

            src = img['src']
            return make_absolute_url(src) if src.present?
          rescue Nokogiri::CSS::SyntaxError
            next
          end
        end

        # Fallback: look for any img with "logo" in alt or class
        doc.css('img').each do |img|
          alt = img['alt'].to_s.downcase
          css_class = img['class'].to_s.downcase
          if alt.include?('logo') || css_class.include?('logo')
            return make_absolute_url(img['src']) if img['src'].present?
          end
        end

        nil
      end

      def extract_background_image(element)
        # Check inline style
        style = element['style']
        if style
          url_match = style.match(/url\(['"]?([^'")\s]+)['"]?\)/i)
          return make_absolute_url(url_match[1]) if url_match
        end

        # Check data-background attribute
        data_bg = element['data-background'] || element['data-bg']
        return make_absolute_url(data_bg) if data_bg.present?

        # Check for img inside
        img = element.at_css('img')
        return make_absolute_url(img['src']) if img && img['src'].present?

        nil
      end

      def make_absolute_url(url)
        return nil if url.blank?
        return url if url.start_with?('http')

        if url.start_with?('//')
          "https:#{url}"
        elsif url.start_with?('/')
          "#{base_url}#{url}"
        else
          "#{base_url}/#{url}"
        end
      end

      def clean_html(element)
        # Remove scripts, styles, and comments
        element.css('script, style, comment').remove

        # Get inner HTML
        html = element.inner_html.strip

        # Clean up whitespace
        html.gsub(/\n\s*\n/, "\n").strip
      end

      # Download all collected images
      def download_images
        puts "  Downloading #{scraped_data[:images].size} images..."

        images_dir = output_path.join('images')
        FileUtils.mkdir_p(images_dir)

        scraped_data[:images].each do |image|
          download_image(image[:url], images_dir.join(image[:filename]))
        end
      end

      def download_image(url, dest_path)
        return if File.exist?(dest_path)

        puts "    Downloading: #{url}"
        URI.open(url, 'User-Agent' => 'Mozilla/5.0 PropertyWebBuilder Scraper') do |remote|
          File.open(dest_path, 'wb') do |file|
            file.write(remote.read)
          end
        end
      rescue StandardError => e
        puts "    Warning: Could not download #{url}: #{e.message}"
      end

      # Generate pack.yml
      def generate_pack_yml
        pack_config = {
          'name' => pack_name,
          'display_name' => scraped_data[:agency][:display_name] || pack_name.titleize,
          'description' => "Scraped from #{base_url}",
          'version' => '1.0',
          'inherits_from' => 'base',
          'website' => {
            'theme_name' => 'brisbane',
            'default_client_locale' => locales.first,
            'supported_locales' => locales,
            'currency' => 'CAD',
            'area_unit' => 'sqft'
          },
          'agency' => build_agency_config,
          'page_parts' => build_page_parts_config
        }

        File.write(output_path.join('pack.yml'), pack_config.to_yaml)
        puts "  Generated pack.yml"
      end

      def build_agency_config
        agency = scraped_data[:agency]
        config = {
          'display_name' => agency[:display_name],
          'email' => agency[:email],
          'phone' => agency[:phone]
        }

        if agency[:address].present?
          config['address'] = { 'street_address' => agency[:address] }
        end

        config.compact
      end

      def build_page_parts_config
        {
          'home' => [
            { 'key' => 'heroes/hero_centered', 'order' => 1 },
            { 'key' => 'features/feature_grid_3col', 'order' => 2 }
          ],
          'about-us' => [
            { 'key' => 'content_html', 'order' => 1 },
            { 'key' => 'teams/team_grid', 'order' => 2 }
          ],
          'contact-us' => [
            { 'key' => 'contactUsFormAndMap', 'order' => 1 }
          ]
        }
      end

      # Generate content YAML files for each page
      def generate_content_files
        scraped_data[:pages].each do |page_slug, locales_data|
          content = {}

          # Build content_html section
          content['content_html'] = {}
          content['content_html']['main_content'] = {}

          locales_data.each do |locale, page_content|
            if page_content[:main_content].present?
              content['content_html']['main_content'][locale] = page_content[:main_content]
            end
          end

          # Build hero section if present
          first_locale_data = locales_data[locales.first.to_sym] || locales_data[locales.first]
          if first_locale_data&.dig(:hero).present?
            hero = first_locale_data[:hero]
            content['heroes/hero_centered'] = {
              'hero_title' => build_locale_hash(locales_data, :hero, :title),
              'hero_subtitle' => build_locale_hash(locales_data, :hero, :subtitle),
              'cta_text' => build_locale_hash(locales_data, :hero, :cta_text)
            }.compact
          end

          # Build team section if present
          if first_locale_data&.dig(:team).present?
            team = first_locale_data[:team]
            content['teams/team_grid'] = build_team_content(team)
          end

          # Write content file
          file_path = output_path.join('content', "#{page_slug}.yml")
          File.write(file_path, content.to_yaml)
          puts "  Generated content/#{page_slug}.yml"
        end
      end

      def build_locale_hash(locales_data, *keys)
        result = {}
        locales_data.each do |locale, data|
          value = data.dig(*keys)
          result[locale.to_s] = value if value.present?
        end
        result.any? ? result : nil
      end

      def build_team_content(team)
        content = {
          'section_title' => { 'en' => 'Meet Our Team' }
        }

        team[:members]&.each_with_index do |member, idx|
          num = idx + 1
          content["member_#{num}_name"] = member[:name]
          content["member_#{num}_role"] = { 'en' => member[:role] } if member[:role]
          content["member_#{num}_bio"] = { 'en' => member[:bio] } if member[:bio]
          content["member_#{num}_email"] = member[:email] if member[:email]
        end

        content
      end

      # Copy downloaded images to output directory
      def copy_images
        # Images are already downloaded to the right place in download_images
        puts "  Images saved to #{output_path.join('images')}"
      end
    end
  end
end
