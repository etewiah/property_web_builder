# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_ticket_messages
#
#  id                  :uuid             not null, primary key
#  content             :text             not null
#  from_platform_admin :boolean          default(FALSE)
#  internal_note       :boolean          default(FALSE)
#  status_changed_from :string(50)
#  status_changed_to   :string(50)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  support_ticket_id   :uuid             not null
#  user_id             :bigint           not null
#  website_id          :bigint           not null
#
# Indexes
#
#  index_pwb_ticket_messages_on_support_ticket_id                 (support_ticket_id)
#  index_pwb_ticket_messages_on_support_ticket_id_and_created_at  (support_ticket_id,created_at)
#  index_pwb_ticket_messages_on_user_id                           (user_id)
#  index_pwb_ticket_messages_on_website_id                        (website_id)
#  index_pwb_ticket_messages_on_website_id_and_created_at         (website_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (support_ticket_id => pwb_support_tickets.id)
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
module PwbTenant
  class TicketMessage < Pwb::TicketMessage
    # Automatically scoped to current_website via acts_as_tenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
