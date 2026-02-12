# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_messages
# Database name: primary
#
#  id               :integer          not null, primary key
#  content          :text
#  delivered_at     :datetime
#  delivery_email   :string
#  delivery_error   :text
#  delivery_success :boolean          default(FALSE)
#  host             :string
#  latitude         :float
#  locale           :string
#  longitude        :float
#  origin_email     :string
#  origin_ip        :string
#  read             :boolean          default(FALSE), not null
#  title            :string
#  url              :string
#  user_agent       :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  client_id        :integer
#  contact_id       :integer
#  realty_asset_id  :uuid
#  website_id       :bigint
#
# Indexes
#
#  index_pwb_messages_on_realty_asset_id  (realty_asset_id)
#  index_pwb_messages_on_website_id       (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_message, class: 'Pwb::Message', aliases: [:message] do
    website { Pwb::Website.first || association(:pwb_website) }
    origin_email { 'visitor@example.com' }
    content { 'Test message content' }
    read { false }
  end
end
