module Pwb
  class Subscriber < ApplicationRecord
    belongs_to :contact
    has_many :subscriber_props
    has_many :props, through: :subscriber_props, class_name: "Pwb::Prop"
  end
end
