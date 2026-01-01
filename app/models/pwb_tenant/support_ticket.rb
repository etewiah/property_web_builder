# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_support_tickets
#
#  id                         :uuid             not null, primary key
#  assigned_at                :datetime
#  category                   :string(50)
#  closed_at                  :datetime
#  description                :text
#  first_response_at          :datetime
#  last_message_at            :datetime
#  last_message_from_platform :boolean          default(FALSE)
#  message_count              :integer          default(0)
#  priority                   :integer          default("normal"), not null
#  resolved_at                :datetime
#  sla_resolution_breached    :boolean          default(FALSE)
#  sla_resolution_due_at      :datetime
#  sla_response_breached      :boolean          default(FALSE)
#  sla_response_due_at        :datetime
#  sla_warning_sent_at        :datetime
#  status                     :integer          default("open"), not null
#  subject                    :string(255)      not null
#  ticket_number              :string(20)       not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  assigned_to_id             :bigint
#  creator_id                 :bigint           not null
#  website_id                 :bigint           not null
#
# Indexes
#
#  idx_tickets_sla_response_breach_status                  (sla_response_breached,status)
#  index_pwb_support_tickets_on_assigned_to_id             (assigned_to_id)
#  index_pwb_support_tickets_on_assigned_to_id_and_status  (assigned_to_id,status)
#  index_pwb_support_tickets_on_creator_id                 (creator_id)
#  index_pwb_support_tickets_on_priority                   (priority)
#  index_pwb_support_tickets_on_sla_resolution_due_at      (sla_resolution_due_at)
#  index_pwb_support_tickets_on_sla_response_due_at        (sla_response_due_at)
#  index_pwb_support_tickets_on_status                     (status)
#  index_pwb_support_tickets_on_ticket_number              (ticket_number) UNIQUE
#  index_pwb_support_tickets_on_website_id                 (website_id)
#  index_pwb_support_tickets_on_website_id_and_created_at  (website_id,created_at)
#  index_pwb_support_tickets_on_website_id_and_status      (website_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (assigned_to_id => pwb_users.id)
#  fk_rails_...  (creator_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
module PwbTenant
  class SupportTicket < Pwb::SupportTicket
    # Automatically scoped to current_website via acts_as_tenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
