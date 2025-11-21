namespace :pwb do
  namespace :pages do
    desc "Associate all pages with their website (sets website_id on pages)"
    task associate_with_website: :environment do
      # Get the website (assumes single-tenant or first website)
      website = Pwb::Website.first
      
      unless website
        puts "❌ Error: No website found in the database"
        exit 1
      end
      
      puts "📋 Website: #{website.id}"
      
      # Find all pages without a website_id
      orphaned_pages = Pwb::Page.where(website_id: nil)
      total_pages = Pwb::Page.count
      
      puts "📊 Total pages in database: #{total_pages}"
      puts "🔍 Pages without website_id: #{orphaned_pages.count}"
      
      if orphaned_pages.count.zero?
        puts "✅ All pages are already associated with a website"
        exit 0
      end
      
      # Display the pages that will be updated
      puts "\n📝 Pages to be associated with website #{website.id}:"
      orphaned_pages.each do |page|
        puts "  - #{page.slug} (ID: #{page.id})"
      end
      
      # Update all orphaned pages
      puts "\n🔧 Associating pages with website..."
      updated_count = orphaned_pages.update_all(website_id: website.id)
      
      puts "✅ Successfully associated #{updated_count} page(s) with website #{website.id}"
      
      # Verify the update
      remaining_orphaned = Pwb::Page.where(website_id: nil).count
      associated_pages = website.pages.count
      
      puts "\n📈 Summary:"
      puts "  - Pages now associated with website: #{associated_pages}"
      puts "  - Remaining orphaned pages: #{remaining_orphaned}"
      
      if remaining_orphaned.zero?
        puts "\n🎉 Success! All pages are now properly associated with the website"
      else
        puts "\n⚠️  Warning: #{remaining_orphaned} page(s) still without website association"
      end
    end
    
    desc "Display page-website association status"
    task status: :environment do
      puts "📊 Page-Website Association Status\n\n"
      
      websites = Pwb::Website.all
      total_pages = Pwb::Page.count
      orphaned_pages = Pwb::Page.where(website_id: nil).count
      
      puts "Total Websites: #{websites.count}"
      puts "Total Pages: #{total_pages}"
      puts "Orphaned Pages (no website_id): #{orphaned_pages}"
      puts ""
      
      websites.each do |website|
        puts "Website ID #{website.id}:"
        puts "  - Associated pages: #{website.pages.count}"
        
        if website.pages.any?
          puts "  - Page slugs: #{website.pages.pluck(:slug).join(', ')}"
        end
        puts ""
      end
      
      if orphaned_pages > 0
        puts "⚠️  Orphaned pages:"
        Pwb::Page.where(website_id: nil).each do |page|
          puts "  - #{page.slug} (ID: #{page.id})"
        end
        puts "\n💡 Run 'rails pwb:pages:associate_with_website' to fix this"
      else
        puts "✅ All pages are properly associated with a website"
      end
    end
  end
end
