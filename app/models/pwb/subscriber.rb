module Pwb
  class Subscriber < ApplicationRecord
    belongs_to :contact
    has_many :subscriber_props
    has_many :props, through: :subscriber_props, class_name: "Pwb::Prop"

    # def agent_name
    #   return "bob"
    # end

    def as_json(options = nil)
      super({only: [
               "subscriber_token", "id",
               "subscriber_url"
             ],
             methods: ["contact"]})
      # methods: admin_attribute_names}.merge(options || {}))
    end
  end
end
