# frozen_string_literal: true

class AddAnalyticsFeatureToPlans < ActiveRecord::Migration[8.1]
  def up
    # Add analytics feature to professional and enterprise plans
    # (starter plan gets basic_analytics only in the future if needed)
    
    execute <<-SQL
      UPDATE pwb_plans 
      SET features = features || '["analytics"]'::jsonb
      WHERE slug IN ('professional', 'enterprise')
      AND NOT (features @> '["analytics"]');
    SQL
  end

  def down
    execute <<-SQL
      UPDATE pwb_plans 
      SET features = features - 'analytics'
      WHERE features @> '["analytics"]';
    SQL
  end
end
