# frozen_string_literal: true

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
