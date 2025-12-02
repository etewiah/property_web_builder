require 'rails_helper'

RSpec.describe "Pwb Model Associations", type: :model do
  it "has valid associations for all Pwb models" do
    # Eager load to ensure all models are defined
    Rails.application.eager_load!

    # Find all classes inside Pwb module that inherit from ApplicationRecord
    # We filter by those that actually have a table or are abstract, to avoid issues with modules/helpers
    pwb_models = Pwb.constants.map { |c| Pwb.const_get(c) }
                          .select { |c| c.is_a?(Class) && c < ActiveRecord::Base && !c.abstract_class? }
    
    pwb_tenant_models = []
    if defined?(PwbTenant)
      pwb_tenant_models = PwbTenant.constants.map { |c| PwbTenant.const_get(c) }
                            .select { |c| c.is_a?(Class) && c < ActiveRecord::Base && !c.abstract_class? }
    end

    models = pwb_models + pwb_tenant_models

    failures = []

    models.each do |model|
      model.reflect_on_all_associations.each do |assoc|
        begin
          # This triggers the class lookup
          klass = assoc.klass
        rescue NameError => e
          failures << "Model #{model.name} has invalid association '#{assoc.name}': #{e.message}"
        rescue => e
          failures << "Model #{model.name} failed on association '#{assoc.name}': #{e.message}"
        end
      end
    end

    if failures.any?
      fail "Association errors found:\n#{failures.join("\n")}"
    end
  end
end
