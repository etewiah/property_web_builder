class AddCustomDomainToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_websites, :custom_domain, :string
    add_column :pwb_websites, :custom_domain_verified, :boolean, default: false
    add_column :pwb_websites, :custom_domain_verified_at, :datetime
    add_column :pwb_websites, :custom_domain_verification_token, :string

    # Unique index on custom_domain, but only for non-null values
    add_index :pwb_websites, :custom_domain, unique: true, where: "custom_domain IS NOT NULL AND custom_domain != ''"
  end
end
