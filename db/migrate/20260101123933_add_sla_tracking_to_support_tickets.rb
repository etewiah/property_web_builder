class AddSlaTrackingToSupportTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_support_tickets, :sla_response_due_at, :datetime
    add_column :pwb_support_tickets, :sla_resolution_due_at, :datetime
    add_column :pwb_support_tickets, :sla_response_breached, :boolean, default: false
    add_column :pwb_support_tickets, :sla_resolution_breached, :boolean, default: false
    add_column :pwb_support_tickets, :sla_warning_sent_at, :datetime

    add_index :pwb_support_tickets, :sla_response_due_at
    add_index :pwb_support_tickets, :sla_resolution_due_at
    add_index :pwb_support_tickets, [:sla_response_breached, :status],
              name: 'idx_tickets_sla_response_breach_status'
  end
end
