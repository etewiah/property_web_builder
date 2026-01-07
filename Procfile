web: bundle exec puma -C config/puma.rb
worker: bundle exec bin/jobs
release: bundle exec rake db:migrate && bundle exec rake assets:sync_to_r2
