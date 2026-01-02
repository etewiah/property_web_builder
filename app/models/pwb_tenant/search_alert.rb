# frozen_string_literal: true

module PwbTenant
  class SearchAlert < Pwb::SearchAlert
    # Note: SearchAlert belongs to SavedSearch, not directly to Website
    # Scoping happens through the saved_search association
  end
end
