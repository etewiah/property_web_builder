# frozen_string_literal: true

module PwbTenant
  class Message < ApplicationRecord
    belongs_to :contact, optional: true, class_name: 'PwbTenant::Contact'
  end
end
