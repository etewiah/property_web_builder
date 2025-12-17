# frozen_string_literal: true

# Base class for all non-namespaced models
# Used by Ahoy and other gems that expect a standard ApplicationRecord
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
