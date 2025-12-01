module PwbTenant
  module ScopedModel
    extend ActiveSupport::Concern

    included do
      # Use the parent class's table
      self.table_name = superclass.table_name
      
      # Global scope for this class restricted to current website
      default_scope { where(website_id: Pwb::Current.website&.id) }
      
      # Auto-assign website on creation
      before_validation :set_current_website
      
      # Fix for Globalize inheritance
      # If the parent class uses Globalize, we need to ensure the subclass
      # uses the same translation class and foreign key
      if superclass.respond_to?(:translation_class)
        define_singleton_method(:translation_class) do
          superclass.translation_class
        end
      end
    end

    private

    def set_current_website
      # Only set if not already present, allowing manual override if absolutely needed
      # though typically we want to enforce the current website context
      self.website_id ||= Pwb::Current.website&.id
    end
  end
end
