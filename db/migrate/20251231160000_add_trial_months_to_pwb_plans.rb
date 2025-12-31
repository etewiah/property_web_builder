# frozen_string_literal: true

class AddTrialMonthsToPwbPlans < ActiveRecord::Migration[7.2]
  def change
    # Add flexible trial span fields
    add_column :pwb_plans, :trial_value, :integer, default: 14
    add_column :pwb_plans, :trial_unit, :string, default: 'days'

    # Migrate existing trial_days data to new fields
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE pwb_plans
          SET trial_value = trial_days, trial_unit = 'days'
          WHERE trial_days IS NOT NULL
        SQL
      end
    end

    # Keep trial_days for backwards compatibility, but it's now deprecated
    # Can be removed in a future migration
  end
end
