namespace :pwb do
  desc "Migrate existing users to user_memberships"
  task migrate_to_memberships: :environment do
    puts "Starting migration of users to memberships..."
    
    success_count = 0
    error_count = 0
    skipped_count = 0
    
    Pwb::User.find_each do |user|
      unless user.website_id.present?
        puts "Skipping user #{user.id} (no website_id)"
        skipped_count += 1
        next
      end
      
      begin
        # Determine role based on existing admin flag
        role = user.admin? ? 'admin' : 'member'
        
        # Create membership if it doesn't exist
        membership = Pwb::UserMembership.find_or_initialize_by(
          user_id: user.id,
          website_id: user.website_id
        )
        
        if membership.new_record?
          membership.role = role
          membership.active = true
          membership.save!
          puts "Migrated user #{user.id} to website #{user.website_id} as #{role}"
          success_count += 1
        else
          puts "User #{user.id} already has membership for website #{user.website_id}"
          skipped_count += 1
        end
      rescue => e
        puts "Error migrating user #{user.id}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "Migration complete!"
    puts "Success: #{success_count}"
    puts "Skipped: #{skipped_count}"
    puts "Errors: #{error_count}"
  end
end
