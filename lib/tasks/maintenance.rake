# frozen_string_literal: true

namespace :maintenance do
  desc "Fix navigation links for a website that has broken/incomplete links"
  task :fix_links, [:subdomain] => :environment do |_t, args|
    subdomain = args[:subdomain]

    if subdomain.blank?
      puts "Usage: rake maintenance:fix_links[subdomain]"
      puts "Example: rake maintenance:fix_links[ancient-peak-35]"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: subdomain)
    if website.nil?
      puts "Website not found: #{subdomain}"
      exit 1
    end

    puts "Fixing navigation links for website: #{subdomain}"
    puts "Current links: #{website.links.count}"

    # Define the standard links that should exist
    standard_links = [
      { slug: 'top_nav_home', page_slug: 'home', link_path: 'home_path', link_title: 'Home', placement: :top_nav, sort_order: 1, visible: true },
      { slug: 'top_nav_buy', page_slug: 'buy', link_path: 'buy_path', link_title: 'Buy', placement: :top_nav, sort_order: 2, visible: true },
      { slug: 'top_nav_rent', page_slug: 'rent', link_path: 'rent_path', link_title: 'Rent', placement: :top_nav, sort_order: 3, visible: true },
      { slug: 'top_nav_about', page_slug: 'about-us', link_path: 'show_page_path', link_path_params: 'about-us', link_title: 'About', placement: :top_nav, sort_order: 4, visible: true },
      { slug: 'top_nav_contact', page_slug: 'contact-us', link_path: 'contact_us_path', link_title: 'Contact', placement: :top_nav, sort_order: 5, visible: true },
      { slug: 'footer_home', page_slug: 'home', link_path: 'home_path', link_title: 'Home', placement: :footer, sort_order: 1, visible: true },
      { slug: 'footer_buy', page_slug: 'buy', link_path: 'buy_path', link_title: 'Properties for Sale', placement: :footer, sort_order: 2, visible: true },
      { slug: 'footer_rent', page_slug: 'rent', link_path: 'rent_path', link_title: 'Properties for Rent', placement: :footer, sort_order: 3, visible: true },
      { slug: 'footer_contact', page_slug: 'contact-us', link_path: 'contact_us_path', link_title: 'Contact Us', placement: :footer, sort_order: 4, visible: true },
      { slug: 'footer_privacy', page_slug: 'privacy', link_path: 'show_page_path', link_path_params: 'privacy', link_title: 'Privacy Policy', placement: :footer, sort_order: 5, visible: true },
      { slug: 'footer_terms', page_slug: 'legal', link_path: 'show_page_path', link_path_params: 'legal', link_title: 'Terms & Conditions', placement: :footer, sort_order: 6, visible: true }
    ]

    # Delete existing broken links (those without link_path)
    broken_links = website.links.where(link_path: [nil, ''])
    if broken_links.any?
      puts "Removing #{broken_links.count} broken links (missing link_path)..."
      broken_links.destroy_all
    end

    # Create or update standard links
    created = 0
    updated = 0

    standard_links.each do |link_attrs|
      existing = website.links.find_by(slug: link_attrs[:slug])
      if existing
        # Update existing link if missing critical attributes
        if existing.link_path.blank?
          existing.update!(link_attrs.except(:slug))
          updated += 1
          puts "  Updated: #{link_attrs[:slug]}"
        end
      else
        website.links.create!(link_attrs.merge(website_id: website.id))
        created += 1
        puts "  Created: #{link_attrs[:slug]}"
      end
    end

    puts ""
    puts "Done! Created: #{created}, Updated: #{updated}"
    puts "Total links now: #{website.links.reload.count}"
    puts "  Top nav: #{website.links.where(placement: :top_nav).count}"
    puts "  Footer: #{website.links.where(placement: :footer).count}"
  end

  desc "Reseed a website from its seed pack"
  task :reseed, [:subdomain] => :environment do |_t, args|
    subdomain = args[:subdomain]

    if subdomain.blank?
      puts "Usage: rake maintenance:reseed[subdomain]"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: subdomain)
    if website.nil?
      puts "Website not found: #{subdomain}"
      exit 1
    end

    pack_name = website.seed_pack_name || 'base'
    puts "Reseeding website '#{subdomain}' with pack '#{pack_name}'..."

    begin
      pack = Pwb::SeedPack.find(pack_name)
      pack.apply!(
        website: website,
        options: {
          skip_website: true,      # Don't override existing website config
          skip_agency: true,       # Keep existing agency
          skip_properties: true,   # Keep existing properties
          skip_users: true,        # Keep existing users
          verbose: true
        }
      )
      puts "\nReseed complete!"
    rescue Pwb::SeedPack::PackNotFoundError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Show diagnostic info for a website"
  task :diagnose, [:subdomain] => :environment do |_t, args|
    subdomain = args[:subdomain]

    if subdomain.blank?
      puts "Usage: rake maintenance:diagnose[subdomain]"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: subdomain)
    if website.nil?
      puts "Website not found: #{subdomain}"
      exit 1
    end

    puts "\n=== Website Diagnostics: #{subdomain} ==="
    puts ""
    puts "Basic Info:"
    puts "  ID: #{website.id}"
    puts "  State: #{website.provisioning_state}"
    puts "  Seed Pack: #{website.seed_pack_name || '(not set)'}"
    puts "  Theme: #{website.theme_name}"
    puts ""
    puts "Data Counts:"
    puts "  Links: #{website.links.count}"
    puts "    - Top Nav: #{website.links.where(placement: :top_nav).count}"
    puts "    - Footer: #{website.links.where(placement: :footer).count}"
    puts "  Pages: #{website.pages.count}"
    puts "  Contents: #{website.contents.count}"
    puts "  Field Keys: #{website.field_keys.count}"
    puts "  Properties: #{website.realty_assets.count}"
    puts ""
    puts "Navigation Links (top_nav):"
    website.links.ordered_visible_top_nav.each do |link|
      status = link.link_path.present? ? "OK" : "BROKEN (no link_path)"
      puts "  - #{link.slug}: #{link.link_title.inspect} -> #{link.link_path || link.link_url || 'NONE'} [#{status}]"
    end
    puts ""
    puts "Agency:"
    if website.agency
      puts "  Name: #{website.agency.display_name}"
      puts "  Email: #{website.agency.email_primary}"
    else
      puts "  (no agency)"
    end
    puts ""
  end
end
