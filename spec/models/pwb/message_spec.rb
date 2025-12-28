# == Schema Information
#
# Table name: pwb_messages
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
#  website_id       :bigint
#
# Indexes
#
#  index_pwb_messages_on_website_id  (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe Message, type: :model do
    let(:website) { FactoryBot.create(:pwb_website, subdomain: 'message-test') }

    let(:message) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_message, website: website)
      end
    end

    before(:each) do
      Pwb::Current.reset
    end

    it 'has a valid factory' do
      expect(message).to be_valid
    end
  end
end
