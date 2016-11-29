# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

Rails.application.configure do        
  config.action_mailer.preview_path = Pwb::Engine.root.join('spec/mailers/previews/pwb')
  # ActionMailer::Base.preview_path
end