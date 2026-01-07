module DbShardTasks
  def self.invoke_and_reenable(task_name)
    Rake::Task[task_name].invoke
  ensure
    Rake::Task[task_name].reenable
  end
end

namespace :db do
  namespace :shards do
    CREATE_TASKS = %w[db:create db:create:tenant_shard_1 db:create:demo_shard].freeze
    MIGRATE_TASKS = %w[db:migrate db:migrate:tenant_shard_1 db:migrate:demo_shard].freeze

    desc "Create primary, tenant_shard_1, and demo_shard databases"
    task create: :environment do
      CREATE_TASKS.each { |task_name| DbShardTasks.invoke_and_reenable(task_name) }
    end

    desc "Run migrations for primary, tenant_shard_1, and demo_shard"
    task migrate: :environment do
      MIGRATE_TASKS.each { |task_name| DbShardTasks.invoke_and_reenable(task_name) }
    end

    desc "Create and migrate all shards (equivalent to running create + migrate)"
    task prepare: :environment do
      DbShardTasks.invoke_and_reenable('db:shards:create')
      DbShardTasks.invoke_and_reenable('db:shards:migrate')
    end
  end
end
