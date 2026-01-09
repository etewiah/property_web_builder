# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::ShardService do
  let(:website) { create(:pwb_website, shard_name: 'default') }
  let(:health_ok) { instance_double(Pwb::ShardHealthCheck::HealthStatus, connection_status: true, error_message: nil) }
  let(:health_bad) { instance_double(Pwb::ShardHealthCheck::HealthStatus, connection_status: false, error_message: 'Connection failed') }

  before do
    allow(Pwb::ShardRegistry).to receive(:configured?).and_return(true)
  end

  describe '.assign_shard' do
    it 'moves the website, records audit, and returns success' do
      allow(Pwb::ShardHealthCheck).to receive(:check).with('shard_1').and_return(health_ok)

      expect(Pwb::ShardAuditLog).to receive(:create!).with(hash_including(
                                                             website: website,
                                                             old_shard_name: 'default',
                                                             new_shard_name: 'shard_1',
                                                             changed_by_email: 'admin@example.com',
                                                             status: 'completed'
                                                           ))

      result = described_class.assign_shard(
        website: website,
        new_shard: 'shard_1',
        changed_by: 'admin@example.com',
        notes: 'Moving to dedicated shard'
      )

      expect(result.success?).to be(true)
      expect(result.data[:old_shard]).to eq('default')
      expect(result.data[:new_shard]).to eq('shard_1')
      expect(website.reload.shard_name).to eq('shard_1')
    end

    it 'fails when shard is invalid' do
      allow(Pwb::ShardRegistry).to receive(:configured?).and_return(false)

      result = described_class.assign_shard(
        website: website,
        new_shard: 'ghost',
        changed_by: 'admin@example.com'
      )

      expect(result.failure?).to be(true)
      expect(result.error).to include('Invalid shard')
      expect(website.reload.shard_name).to eq('default')
    end

    it 'fails when assigning to same shard' do
      result = described_class.assign_shard(
        website: website,
        new_shard: 'default',
        changed_by: 'admin@example.com'
      )

      expect(result.failure?).to be(true)
      expect(result.error).to include('already on shard')
    end

    it 'fails when health check reports failure' do
      allow(Pwb::ShardHealthCheck).to receive(:check).with('shard_1').and_return(health_bad)

      result = described_class.assign_shard(
        website: website,
        new_shard: 'shard_1',
        changed_by: 'admin@example.com'
      )

      expect(result.failure?).to be(true)
      expect(result.error).to include('Cannot assign')
    end
  end

  describe '.configured_shards' do
    it 'only returns shards that are configured' do
      allow(Pwb::ShardRegistry).to receive(:logical_shards).and_return(%i[default shard_1 shard_2])
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:default).and_return(true)
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:shard_1).and_return(false)
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:shard_2).and_return(true)

      expect(described_class.configured_shards).to contain_exactly('default', 'shard_2')
    end
  end
end
