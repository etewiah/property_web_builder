# Use `whenever` to manage cron entries.
# Run `whenever --update-crontab` after deployment to apply changes.

every 1.day, at: '3:00 am' do
  runner "DemoResetJob.perform_later"
end
