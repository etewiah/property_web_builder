# == Schema Information
#
# Table name: pwb_authorizations
#
#  id         :bigint           not null, primary key
#  provider   :string
#  uid        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_pwb_authorizations_on_user_id  (user_id)
#
module Pwb
  class Authorization < ApplicationRecord
    belongs_to :user
  end
end
