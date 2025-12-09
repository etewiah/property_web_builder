class AddOnboardingStateToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_users, :onboarding_state, :string, null: false, default: 'active'
    add_column :pwb_users, :onboarding_step, :integer, default: 0
    add_column :pwb_users, :onboarding_started_at, :datetime
    add_column :pwb_users, :onboarding_completed_at, :datetime

    add_index :pwb_users, :onboarding_state
  end
end
