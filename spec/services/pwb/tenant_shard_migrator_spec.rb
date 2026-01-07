# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::TenantShardMigrator do
  let(:website) { create(:pwb_website, shard_name: 'default') }
  let(:logger) { Logger.new(nil) }

  describe '#call' do
    it 'invokes insert/delete cycles and updates shard name' do
      migrator = described_class.new(website: website, target_shard: :shard_1, logger: logger)

      allow(migrator).to receive(:tenant_table_names).and_return(['pwb_contacts'])
      allow(migrator).to receive(:fetch_rows).and_return([
                                                          { 'id' => 42, 'website_id' => website.id, 'first_name' => 'Jane' }
                                                        ], [])
      allow(migrator).to receive(:ensure_no_conflicts!).and_return(true)

      expect(migrator).to receive(:insert_rows).with('pwb_contacts', array_including(hash_including('id' => 42)), :shard_1)
      expect(migrator).to receive(:delete_rows).with('pwb_contacts', [42], :default)

      migrator.call

      expect(website.reload.shard_name).to eq('shard_1')
    end

    it 'raises when the target shard is not configured' do
      migrator = described_class.new(website: website, target_shard: :shard_2, logger: logger)
      expect { migrator.call }.to raise_error(Pwb::TenantShardMigrator::MigrationError)
    end
  end
end
