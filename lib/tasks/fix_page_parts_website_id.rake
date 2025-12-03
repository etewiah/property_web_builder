namespace :pwb do
  namespace :db do
    desc "Fix PageParts missing website_id by associating them with websites based on page_slug"
    task fix_page_parts_website_ids: :environment do
      puts "Fixing PageParts missing website_id..."
      
      orphaned_page_parts = Pwb::PagePart.where(website_id: nil)
      puts "Found #{orphaned_page_parts.count} PageParts without website_id"
      
      if orphaned_page_parts.count == 0
        puts "Nothing to fix!"
        next
      end
      
      # Get all websites
      websites = Pwb::Website.all
      
      if websites.empty?
        puts "No websites found. Cannot assign PageParts."
        next
      end
      
      fixed_count = 0
      duplicated_count = 0
      
      orphaned_page_parts.find_each do |page_part|
        page_slug = page_part.page_slug
        page_part_key = page_part.page_part_key
        
        websites.each do |website|
          # Check if this page_part should belong to this website
          # For page_slug "website", it's a website-level page part
          # For other page_slugs, check if the website has a page with that slug
          
          should_associate = false
          
          if page_slug == "website"
            should_associate = true
          else
            # Check if website has a page with this slug
            page = website.pages.find_by(slug: page_slug)
            should_associate = page.present?
          end
          
          if should_associate
            # Check if this website already has this page part
            existing = Pwb::PagePart.find_by(
              page_part_key: page_part_key,
              page_slug: page_slug,
              website_id: website.id
            )
            
            if existing
              puts "  PagePart '#{page_part_key}' (#{page_slug}) already exists for website #{website.subdomain}"
            else
              # Create a copy for this website
              new_page_part = page_part.dup
              new_page_part.website_id = website.id
              new_page_part.save!
              duplicated_count += 1
              puts "  Created PagePart '#{page_part_key}' (#{page_slug}) for website #{website.subdomain}"
            end
          end
        end
      end
      
      # Now delete the orphaned page parts (those without website_id)
      deleted_count = orphaned_page_parts.delete_all
      
      puts ""
      puts "Summary:"
      puts "  - Created #{duplicated_count} new PageParts with website associations"
      puts "  - Deleted #{deleted_count} orphaned PageParts without website_id"
      puts "Done!"
    end
    
    desc "Fix Content records missing website_id"
    task fix_contents_website_ids: :environment do
      puts "Fixing Content records missing website_id..."
      
      orphaned_contents = Pwb::Content.where(website_id: nil)
      puts "Found #{orphaned_contents.count} Contents without website_id"
      
      if orphaned_contents.count == 0
        puts "Nothing to fix!"
        next
      end
      
      fixed_count = 0
      
      orphaned_contents.find_each do |content|
        # Try to find website via page_contents association
        page_content = content.page_contents.first
        
        if page_content && page_content.page && page_content.page.website_id
          content.update!(website_id: page_content.page.website_id)
          fixed_count += 1
          puts "  Fixed Content ##{content.id} (#{content.key}) via page association"
        elsif page_content && page_content.website_id
          content.update!(website_id: page_content.website_id)
          fixed_count += 1
          puts "  Fixed Content ##{content.id} (#{content.key}) via page_content"
        else
          # Assign to first website as fallback
          first_website = Pwb::Website.first
          if first_website
            content.update!(website_id: first_website.id)
            fixed_count += 1
            puts "  Fixed Content ##{content.id} (#{content.key}) - assigned to first website"
          end
        end
      end
      
      puts ""
      puts "Summary: Fixed #{fixed_count} Content records"
      puts "Done!"
    end
    
    desc "Fix PageContent records missing website_id"
    task fix_page_contents_website_ids: :environment do
      puts "Fixing PageContent records missing website_id..."
      
      orphaned_page_contents = Pwb::PageContent.where(website_id: nil)
      puts "Found #{orphaned_page_contents.count} PageContents without website_id"
      
      if orphaned_page_contents.count == 0
        puts "Nothing to fix!"
        next
      end
      
      fixed_count = 0
      
      orphaned_page_contents.find_each do |page_content|
        # Try to get website_id from associated page
        if page_content.page && page_content.page.website_id
          page_content.update!(website_id: page_content.page.website_id)
          fixed_count += 1
          puts "  Fixed PageContent ##{page_content.id} (#{page_content.page_part_key}) via page"
        elsif page_content.content && page_content.content.website_id
          page_content.update!(website_id: page_content.content.website_id)
          fixed_count += 1
          puts "  Fixed PageContent ##{page_content.id} (#{page_content.page_part_key}) via content"
        else
          # Assign to first website as fallback
          first_website = Pwb::Website.first
          if first_website
            page_content.update!(website_id: first_website.id)
            fixed_count += 1
            puts "  Fixed PageContent ##{page_content.id} (#{page_content.page_part_key}) - assigned to first website"
          end
        end
      end
      
      puts ""
      puts "Summary: Fixed #{fixed_count} PageContent records"
      puts "Done!"
    end
    
    desc "Fix all multi-tenant records (PageParts, Contents, PageContents)"
    task fix_all_website_ids: :environment do
      puts "=" * 50
      puts "Fixing all multi-tenant records..."
      puts "=" * 50
      puts ""
      
      Rake::Task["pwb:db:fix_page_parts_website_ids"].invoke
      puts ""
      Rake::Task["pwb:db:fix_page_contents_website_ids"].invoke
      puts ""
      Rake::Task["pwb:db:fix_contents_website_ids"].invoke
      
      puts ""
      puts "=" * 50
      puts "All multi-tenant records fixed!"
      puts "=" * 50
    end
    
    desc "Verify all PageParts have website_id set"
    task verify_page_parts_website_ids: :environment do
      orphaned = Pwb::PagePart.where(website_id: nil).count
      total = Pwb::PagePart.count
      
      if orphaned == 0
        puts "✅ All #{total} PageParts have website_id set"
      else
        puts "❌ #{orphaned} of #{total} PageParts are missing website_id"
        puts "Run 'rails pwb:db:fix_page_parts_website_ids' to fix"
      end
    end
    
    desc "Verify all multi-tenant records have website_id set"
    task verify_all_website_ids: :environment do
      puts "Checking multi-tenant data integrity..."
      puts ""
      
      # PageParts
      orphaned_parts = Pwb::PagePart.where(website_id: nil).count
      total_parts = Pwb::PagePart.count
      if orphaned_parts == 0
        puts "✅ PageParts: #{total_parts} records, all have website_id"
      else
        puts "❌ PageParts: #{orphaned_parts}/#{total_parts} missing website_id"
      end
      
      # Contents
      orphaned_contents = Pwb::Content.where(website_id: nil).count
      total_contents = Pwb::Content.count
      if orphaned_contents == 0
        puts "✅ Contents: #{total_contents} records, all have website_id"
      else
        puts "❌ Contents: #{orphaned_contents}/#{total_contents} missing website_id"
      end
      
      # PageContents
      orphaned_page_contents = Pwb::PageContent.where(website_id: nil).count
      total_page_contents = Pwb::PageContent.count
      if orphaned_page_contents == 0
        puts "✅ PageContents: #{total_page_contents} records, all have website_id"
      else
        puts "❌ PageContents: #{orphaned_page_contents}/#{total_page_contents} missing website_id"
      end
      
      puts ""
      if orphaned_parts + orphaned_contents + orphaned_page_contents == 0
        puts "🎉 All multi-tenant records have proper website associations!"
      else
        puts "⚠️  Run 'rails pwb:db:fix_all_website_ids' to fix issues"
      end
    end
  end
end
