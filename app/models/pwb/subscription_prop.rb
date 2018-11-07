module Pwb
  class SubscriptionProp < ApplicationRecord
    belongs_to :prop
    belongs_to :subscription
  end
end
