namespace :pwb do
  namespace :content do
    desc "Reprocess all content blocks to ensure responsive images are correctly generated"
    task reprocess_responsive: :environment do
      require 'pwb/responsive_variants'
      
      # Helper class to mixin the helper methods
      class ContentProcessor
        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::AssetTagHelper
        include ActionView::Helpers::UrlHelper
        include ActionView::Context
        include Pwb::ImagesHelper
        
        # Mock request/controller for helpers that need it
        def request
          @request ||= ActionDispatch::TestRequest.create
        end
        
        def controller
          @controller ||= ActionDispatch::TestRequest.create
        end
      end
      
      view = ContentProcessor.new
      processed_count = 0
      updated_count = 0
      
      puts "Reprocessing Pwb::Content for responsive images..."
      puts "============================================================"
      
      Pwb::Content.find_each do |content|
        processed_count += 1
        changed = false
        
        # Iterate through available locales to check translated fields
        # Pwb::Content uses Mobility with JSONB backend
        I18n.available_locales.each do |locale|
          col = "raw_#{locale}"
          
          # Skip if the model doesn't respond to this locale method
          next unless content.respond_to?(col)
          
          html = content.send(col)
          next if html.blank?
          
          # make_media_responsive is in Pwb::ImagesHelper
          # It detects .hero-section classes and applies :hero sizes
          # It also upgrades img tags to picture tags for detailed responsive behavior
          new_html = view.make_media_responsive(html)
          
          if new_html != html
            content.send("#{col}=", new_html)
            changed = true
            puts "  Fixed #{col} for Content ##{content.id} (#{content.page_part_key})"
          end
        end
        
        if changed
          if content.save
            updated_count += 1
          else
            puts "  FAILED to save Content ##{content.id}: #{content.errors.full_messages.join(', ')}"
          end
        end
      end
      
      puts "============================================================"
      puts "Done!"
      puts "Processed: #{processed_count}"
      puts "Updated:   #{updated_count}"
    end
  end
end
