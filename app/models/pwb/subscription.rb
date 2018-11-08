module Pwb
  class Subscription < ApplicationRecord
    belongs_to :contact
    has_many :subscription_props
    has_many :props, through: :subscription_props, class_name: "Pwb::Prop"
  end
end
