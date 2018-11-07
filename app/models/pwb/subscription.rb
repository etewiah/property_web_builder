module Pwb
  class Subscription < ApplicationRecord
    has_many :subscription_props
    has_many :props, through: :subscription_props, class_name: "Pwb::Prop"
  end
end
