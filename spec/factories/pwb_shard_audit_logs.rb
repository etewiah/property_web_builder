# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_shard_audit_logs
# Database name: primary
#
#  id               :bigint           not null, primary key
#  changed_by_email :string           not null
#  new_shard_name   :string           not null
#  notes            :string
#  old_shard_name   :string
#  status           :string           default("completed"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  website_id       :bigint           not null
#
# Indexes
#
#  index_pwb_shard_audit_logs_on_changed_by_email  (changed_by_email)
#  index_pwb_shard_audit_logs_on_created_at        (created_at)
#  index_pwb_shard_audit_logs_on_status            (status)
#  index_pwb_shard_audit_logs_on_website_id        (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_shard_audit_log, class: 'Pwb::ShardAuditLog' do
    association :website, factory: :pwb_website
    old_shard_name { 'default' }
    new_shard_name { 'shard_1' }
    changed_by_email { 'admin@example.com' }
    status { 'completed' }
    notes { 'Moving for test' }
  end
end
