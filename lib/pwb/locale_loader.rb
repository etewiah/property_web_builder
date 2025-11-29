module Pwb
  class LocaleLoader
    class << self
      # Call from console:
      # require 'pwb/locale_loader'
      # or
      # load locale_loader.rb if needed
      # Pwb::LocaleLoader.load_locale! "en", "es"

      def load_locale!(from_locale, to_locale)
        # Will go through each property and populate
        # the title and description for one locale
        # from the other
        Pwb::Prop.all.each do |prop|
          col_prefixes = ["title_", "description_"]
          update_single_record prop, col_prefixes, from_locale, to_locale
        end
        Pwb::Content.all.each do |content|
          col_prefixes = ["raw_"]
          update_single_record content, col_prefixes, from_locale, to_locale
        end
      end

      protected

      def update_single_record(item_to_update, col_prefixes, from_locale, to_locale)
        col_prefixes.each do |col_prefix|
          source_col = col_prefix + from_locale # eg title_en
          dest_col = col_prefix + to_locale # eg title_de
          execute_col_update item_to_update, dest_col, source_col
        end
      end

      def execute_col_update(item_to_update, dest_col, source_col)
        source_content = item_to_update.send source_col
        # if item_to_update[dest_col].blank?
        # above won't work
        # because dest_col is available through a join
        if (item_to_update.send dest_col).blank?
          item_to_update.update(dest_col => source_content)
        end
      end
    end
  end
end
