# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::ShardHealthCheck do
  let(:shard_name) { 'shard_1' }

  describe '.check' do
    it 'returns failure when shard is not configured' do
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:shard_1).and_return(false)

      status = described_class.check(shard_name)

      expect(status.connection_status).to be(false)
      expect(status.error_message).to match(/not configured/i)
    end

    it 'returns failure when connection raises' do
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:shard_1).and_return(true)
      allow(PwbTenant::ApplicationRecord).to receive(:connected_to).and_raise(StandardError.new('boom'))

      status = described_class.check(shard_name)

      expect(status.connection_status).to be(false)
      expect(status.error_message).to eq('boom')
    end

    it 'populates metrics when connection succeeds' do
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:shard_1).and_return(true)

      # Stub private helpers to avoid real DB work
      allow(described_class).to receive(:test_connection).and_return(true)
      allow(described_class).to receive(:measure_query_time).and_return(12.5)
      allow(described_class).to receive(:get_connection_count).and_return(3)
      allow(described_class).to receive(:get_database_size).and_return(1234)
      allow(described_class).to receive(:get_slow_queries_count).and_return(1)
      allow(described_class).to receive(:get_index_hit_rate).and_return(99.1)
      allow(described_class).to receive(:get_cache_hit_rate).and_return(88.2)
      allow(described_class).to receive(:get_top_tables).and_return([{ table: 'pwb_websites', size: 100 }])

      allow(PwbTenant::ApplicationRecord).to receive(:connected_to).with(shard: :shard_1) do |&block|
        block.call
      end

      status = described_class.check(shard_name)

      expect(status.connection_status).to be(true)
      expect(status.avg_query_ms).to eq(12.5)
      expect(status.active_connections).to eq(3)
      expect(status.database_size).to eq(1234)
      expect(status.index_hit_rate).to eq(99.1)
      expect(status.cache_hit_rate).to eq(88.2)
      expect(status.table_sizes.first[:table]).to eq('pwb_websites')
      expect(status.status_label).to eq('Healthy')
      expect(status.status_color).to eq('green')
    end
  end

  describe '.check_all' do
    it 'skips shards that are not configured' do
      allow(Pwb::ShardRegistry).to receive(:logical_shards).and_return(%i[default shard_1])
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:default).and_return(false)
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:shard_1).and_return(true)

      status = instance_double(Pwb::ShardHealthCheck::HealthStatus)
      allow(described_class).to receive(:check).with('shard_1').and_return(status)

      result = described_class.check_all

      expect(result.keys).to contain_exactly('shard_1')
      expect(result['shard_1']).to eq(status)
    end
  end
end
