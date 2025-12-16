# frozen_string_literal: true

class AddSiteAdminOnboardingToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :pwb_users, :site_admin_onboarding_completed_at, :datetime
    add_index :pwb_users, :site_admin_onboarding_completed_at
  end
end
