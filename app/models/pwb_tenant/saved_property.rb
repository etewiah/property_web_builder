# frozen_string_literal: true

module PwbTenant
  class SavedProperty < Pwb::SavedProperty
    # Automatically scoped to current_website via acts_as_tenant
    acts_as_tenant :website, class_name: "Pwb::Website"
  end
end
