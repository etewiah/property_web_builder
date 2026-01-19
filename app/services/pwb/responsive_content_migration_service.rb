module Pwb
  class ResponsiveContentMigrationService
    include Pwb::ImagesHelper
    # Need to include ActionView helpers to use image_tag etc in the helper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper
    include ActionView::Helpers::UrlHelper
    include ActionView::Context

    def run
      count = 0
      Pwb::Content.find_each do |content|
        changed = false
        
        # Mobility stores translations in the 'translations' jsonb column
        # Structure: { "en" => "...", "es" => "..." }
        next unless content.translations.present?

        # We operate on the translations hash directly to avoid locale switching issues
        # and to ensure we catch all languages
        updated_translations = content.translations.dup

        updated_translations.each do |locale, html_content|
          next if html_content.blank?

          # Check for nested structure which seems to be how Pwb::Content stores it
          # e.g. "en" => { "raw" => "..." }
          if html_content.is_a?(Hash)
             # Try to find the actual content string
             inner_content = html_content['raw'] || html_content['content']
             
             if inner_content.is_a?(String)
               responsive_inner = make_media_responsive(inner_content)
               
               if responsive_inner != inner_content
                 # Update the inner hash in place
                 if html_content['raw']
                   html_content['raw'] = responsive_inner
                 else
                   html_content['content'] = responsive_inner
                 end
                 # We are modifying the hash object which is already in updated_translations[locale] reference
                 # But to be safe/explicit, we can ensure the reference is held (it is)
                 changed = true
               end
             end
          elsif html_content.is_a?(String)
            # Simple string case
            responsive_html = make_media_responsive(html_content)
            
            if responsive_html != html_content
              updated_translations[locale] = responsive_html
              changed = true
            end
          end
        end

        if changed
          # Update the translations column directly
          content.update_column(:translations, updated_translations)
          count += 1
        end
      end
      
      { updated_count: count }
    end
  end
end
