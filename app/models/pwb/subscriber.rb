module Pwb
  class Subscriber < ApplicationRecord
    has_many :subscriber_props
    has_many :props, through: :subscriber_props, class_name: "Pwb::Prop"
  end
end
