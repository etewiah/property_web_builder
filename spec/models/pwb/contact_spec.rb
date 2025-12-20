# == Schema Information
#
# Table name: pwb_contacts
#
#  id                   :bigint           not null, primary key
#  details              :json
#  documentation_type   :integer
#  fax                  :string
#  first_name           :string
#  flags                :integer          default(0), not null
#  last_name            :string
#  nationality          :string
#  other_email          :string
#  other_names          :string
#  other_phone_number   :string
#  primary_email        :string
#  primary_phone_number :string
#  title                :integer          default("mr")
#  website_url          :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  documentation_id     :string
#  facebook_id          :string
#  linkedin_id          :string
#  primary_address_id   :integer
#  secondary_address_id :integer
#  skype_id             :string
#  twitter_id           :string
#  user_id              :integer
#  website_id           :bigint
#
# Indexes
#
#  index_pwb_contacts_on_documentation_id          (documentation_id)
#  index_pwb_contacts_on_first_name                (first_name)
#  index_pwb_contacts_on_first_name_and_last_name  (first_name,last_name)
#  index_pwb_contacts_on_last_name                 (last_name)
#  index_pwb_contacts_on_primary_email             (primary_email)
#  index_pwb_contacts_on_primary_phone_number      (primary_phone_number)
#  index_pwb_contacts_on_title                     (title)
#  index_pwb_contacts_on_website_id                (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe Contact, type: :model do
    pending "add some examples to (or delete) #{__FILE__}"
  end
end
