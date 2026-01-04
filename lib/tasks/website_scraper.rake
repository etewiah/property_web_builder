# frozen_string_literal: true

require_relative '../pwb/website_scraper/scraper'

namespace :pwb do
  desc 'Scrape content from an existing PWB website to create a seed pack'
  task :scrape_website, [:url, :pack_name, :locales] => :environment do |_t, args|
    url = args[:url]
    pack_name = args[:pack_name]
    locales = args[:locales]&.split(',') || ['en']

    if url.blank? || pack_name.blank?
      puts 'Usage: rake pwb:scrape_website[https://example.com,pack_name,en,es]'
      puts ''
      puts 'Arguments:'
      puts '  url       - The base URL of the website to scrape'
      puts '  pack_name - Name for the generated seed pack'
      puts '  locales   - Comma-separated locales to scrape (default: en)'
      puts ''
      puts 'Example:'
      puts '  rake "pwb:scrape_website[https://site_to_scrape.com,site_pack_name,en]"'
      exit 1
    end

    puts '=' * 60
    puts 'PWB Website Scraper'
    puts '=' * 60
    puts "URL:       #{url}"
    puts "Pack Name: #{pack_name}"
    puts "Locales:   #{locales.join(', ')}"
    puts '=' * 60
    puts ''

    scraper = Pwb::WebsiteScraper::Scraper.new(
      base_url: url,
      pack_name: pack_name,
      locales: locales
    )

    # Scrape the website
    scraper.scrape!

    puts ''

    # Generate seed pack
    output_path = scraper.generate_seed_pack!

    puts ''
    puts '=' * 60
    puts 'Scraping Complete!'
    puts '=' * 60
    puts ''
    puts 'Generated seed pack at (git-ignored):'
    puts "  #{output_path}"
    puts ''
    puts 'To use this seed pack:'
    puts "  rake \"pwb:seed_pack:apply[site_import_packs/#{pack_name},your_subdomain]\""
    puts ''
    puts 'Or preview what it contains:'
    puts "  rake \"pwb:seed_pack:preview[site_import_packs/#{pack_name}]\""
    puts ''
  end

  namespace :scrape_website do
    desc 'Preview what would be scraped without downloading'
    task :preview, [:url] => :environment do |_t, args|
      url = args[:url]

      if url.blank?
        puts 'Usage: rake pwb:scrape_website:preview[https://example.com]'
        exit 1
      end

      puts "Previewing: #{url}"
      puts ''

      require 'nokogiri'
      require 'open-uri'

      doc = Nokogiri::HTML(URI.open(url, 'User-Agent' => 'Mozilla/5.0 PropertyWebBuilder Scraper'))

      puts 'Page Title:'
      puts "  #{doc.at_css('title')&.text}"
      puts ''

      puts 'Navigation Links:'
      doc.css('nav a, header a').each do |link|
        href = link['href']
        text = link.text.strip
        next if text.blank? || href.blank? || href.start_with?('#', 'javascript:')

        puts "  #{text}: #{href}"
      end
      puts ''

      puts 'Images Found:'
      doc.css('img').first(10).each do |img|
        src = img['src']
        alt = img['alt']
        puts "  #{alt || 'no alt'}: #{src&.truncate(60)}"
      end
      puts ''

      puts 'Contact Info:'
      mailto = doc.at_css('a[href^="mailto:"]')
      puts "  Email: #{mailto['href'].sub('mailto:', '')}" if mailto

      tel = doc.at_css('a[href^="tel:"]')
      puts "  Phone: #{tel['href'].sub('tel:', '')}" if tel
    end
  end
end
