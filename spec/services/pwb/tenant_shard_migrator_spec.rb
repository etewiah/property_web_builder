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

    it 'performs no writes when dry_run is true' do
      migrator = described_class.new(website: website, target_shard: :shard_1, logger: logger, dry_run: true)

      expect(migrator).not_to receive(:migrate_records!)
      migrator.call

      expect(website.reload.shard_name).to eq('default')
    end

    it 'raises on id conflict during migration' do
      migrator = described_class.new(website: website, target_shard: :shard_1, logger: logger)

      allow(migrator).to receive(:tenant_table_names).and_return(['pwb_contacts'])
      allow(migrator).to receive(:fetch_rows).and_return([
        { 'id' => 7, 'website_id' => website.id, 'first_name' => 'Sam' }
      ], [])

      allow(migrator).to receive(:ensure_no_conflicts!).and_raise(Pwb::TenantShardMigrator::MigrationError, 'ID conflict detected')

      expect { migrator.call }.to raise_error(Pwb::TenantShardMigrator::MigrationError, /ID conflict/)
      expect(website.reload.shard_name).to eq('default')
    end

    it 'loops through multiple batches until empty' do
      migrator = described_class.new(website: website, target_shard: :shard_1, logger: logger)

      allow(migrator).to receive(:tenant_table_names).and_return(['pwb_contacts'])
      allow(migrator).to receive(:ensure_no_conflicts!).and_return(true)

      batch1 = { 'id' => 1, 'website_id' => website.id, 'first_name' => 'A' }
      batch2 = { 'id' => 2, 'website_id' => website.id, 'first_name' => 'B' }
      allow(migrator).to receive(:fetch_rows).and_return([batch1], [batch2], [])

      expect(migrator).to receive(:insert_rows).with('pwb_contacts', array_including(batch1), :shard_1).ordered
      expect(migrator).to receive(:delete_rows).with('pwb_contacts', [1], :default).ordered
      expect(migrator).to receive(:insert_rows).with('pwb_contacts', array_including(batch2), :shard_1).ordered
      expect(migrator).to receive(:delete_rows).with('pwb_contacts', [2], :default).ordered

      migrator.call
      expect(website.reload.shard_name).to eq('shard_1')
    end
  end
end
