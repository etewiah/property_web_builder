# frozen_string_literal: true

class AddEmailVerificationToWebsites < ActiveRecord::Migration[7.2]
  def change
    # Email verification fields for locked site workflow
    add_column :pwb_websites, :email_verification_token, :string
    add_column :pwb_websites, :email_verification_token_expires_at, :datetime
    add_column :pwb_websites, :email_verified_at, :datetime
    add_column :pwb_websites, :owner_email, :string  # Store signup email for verification

    # Index for token lookups
    add_index :pwb_websites, :email_verification_token, unique: true, where: "email_verification_token IS NOT NULL"
  end
end
