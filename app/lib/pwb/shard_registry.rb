# frozen_string_literal: true

module Pwb
  module ShardRegistry
    LOGICAL_TO_PHYSICAL = {
      default: :primary,
      shard_1: :tenant_shard_1,
      shard_2: :tenant_shard_2,
      demo: :demo_shard
    }.freeze

    module_function

    def logical_shards
      LOGICAL_TO_PHYSICAL.keys
    end

    def physical_name(logical)
      LOGICAL_TO_PHYSICAL[logical.to_sym]
    end

    def configured?(logical)
      physical = physical_name(logical)
      return false unless physical

      configs.any? { |config| config.name.to_sym == physical }
    end

    def configs
      ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)
    end

    def describe_shard(logical)
      config = configs.find { |c| c.name.to_sym == physical_name(logical) }
      return { name: logical, configured: false } unless config

      { name: logical, configured: true, database: config.database, host: config.host }
    end
  end
end
