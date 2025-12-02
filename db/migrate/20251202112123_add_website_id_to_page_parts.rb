class AddWebsiteIdToPageParts < ActiveRecord::Migration[8.0]
  def change
    # Add website_id column to pwb_page_parts for tenant isolation
    add_column :pwb_page_parts, :website_id, :integer
    add_index :pwb_page_parts, :website_id
    
    # Update unique index to include website_id
    # Remove old index first
    remove_index :pwb_page_parts, name: "index_pwb_page_parts_on_page_part_key_and_page_slug"
    
    # Add new compound unique index ensuring uniqueness per website
    add_index :pwb_page_parts, [:page_part_key, :page_slug, :website_id], 
              name: 'index_page_parts_unique_per_website', 
              unique: true
    
    reversible do |dir|
      dir.up do
        # Backfill existing page_parts with website_id
        # Strategy: Assign to website based on the page's website_id
        
        say "Backfilling website_id for page-level page_parts..."
        execute <<-SQL
          UPDATE pwb_page_parts pp
          SET website_id = (
            SELECT p.website_id
            FROM pwb_pages p
            WHERE pp.page_slug = p.slug
            LIMIT 1
          )
          WHERE pp.page_slug != 'website'
          AND pp.page_slug IS NOT NULL;
        SQL
        
        # For "website" level page_parts (global components like footer)
        # We need to duplicate them for each website
        say "Duplicating website-level page_parts for each tenant..."
        
        # Get all websites
        websites = execute("SELECT id FROM pwb_websites ORDER BY id").to_a
        
        if websites.any?
          # Get all website-level page_parts
          website_page_parts = execute(<<-SQL).to_a
            SELECT id, page_part_key, page_slug, template, editor_setup, 
                   block_contents, is_rails_part, show_in_editor, order_in_editor,
                   theme_name, locale, flags
            FROM pwb_page_parts 
            WHERE page_slug = 'website'
          SQL
          
          website_page_parts.each do |pp|
            # Assign first record to first website
            first_website_id = websites.first['id']
            execute(<<-SQL)
              UPDATE pwb_page_parts 
              SET website_id = #{first_website_id}
              WHERE id = #{pp['id']}
            SQL
            
            # Create duplicates for other websites
            websites[1..-1].each do |website|
              execute(<<-SQL)
                INSERT INTO pwb_page_parts (
                  page_part_key, page_slug, template, editor_setup, block_contents,
                  is_rails_part, show_in_editor, order_in_editor, theme_name, locale,
                  flags, website_id, created_at, updated_at
                )
                VALUES (
                  #{connection.quote(pp['page_part_key'])},
                  #{connection.quote(pp['page_slug'])},
                  #{connection.quote(pp['template'])},
                  #{connection.quote(pp['editor_setup'])},
                  #{connection.quote(pp['block_contents'])},
                  #{connection.quote(pp['is_rails_part'])},
                  #{connection.quote(pp['show_in_editor'])},
                  #{connection.quote(pp['order_in_editor'])},
                  #{connection.quote(pp['theme_name'])},
                  #{connection.quote(pp['locale'])},
                  #{connection.quote(pp['flags'])},
                  #{website['id']},
                  NOW(),
                  NOW()
                )
              SQL
            end
          end
          
          say "Successfully duplicated #{website_page_parts.count} website-level page_parts across #{websites.count} websites", true
        end
        
        # Verify all page_parts have a website_id
        orphaned_count = execute("SELECT COUNT(*) as count FROM pwb_page_parts WHERE website_id IS NULL").first['count'].to_i
        if orphaned_count > 0
          say "WARNING: #{orphaned_count} page_parts still have NULL website_id. Manual intervention required.", true
        else
          say "All page_parts successfully assigned to websites", true
        end
      end
      
      dir.down do
        # On rollback, restore original unique index
        remove_index :pwb_page_parts, name: 'index_page_parts_unique_per_website'
        add_index :pwb_page_parts, [:page_part_key, :page_slug], 
                  name: "index_pwb_page_parts_on_page_part_key_and_page_slug"
      end
    end
    
    # Make website_id NOT NULL after backfill (commented out for safety)
    # Uncomment after verifying backfill succeeded
    # change_column_null :pwb_page_parts, :website_id, false
  end
end
