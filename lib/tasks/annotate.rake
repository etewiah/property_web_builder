# frozen_string_literal: true

# Auto-annotate models after migrations
# This ensures schema comments in model files stay up to date

if Rails.env.development?
  # Hook into db:migrate to auto-annotate
  Rake::Task["db:migrate"].enhance do
    Rake::Task["annotate:models"].invoke if Rake::Task.task_defined?("annotate:models")
  end

  Rake::Task["db:rollback"].enhance do
    Rake::Task["annotate:models"].invoke if Rake::Task.task_defined?("annotate:models")
  end

  namespace :annotate do
    desc "Annotate models with schema information"
    task models: :environment do
      puts "Annotating models..."
      system("bundle exec annotaterb models --show-foreign-keys --show-indexes")
    end

    desc "Remove annotations from models"
    task remove: :environment do
      puts "Removing annotations..."
      system("bundle exec annotaterb models --delete")
    end
  end
end
