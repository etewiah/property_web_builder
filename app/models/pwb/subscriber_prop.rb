module Pwb
  class SubscriberProp < ApplicationRecord
    belongs_to :prop
    belongs_to :subscription
  end
end
