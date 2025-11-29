# Cloudflare R2 Setup Guide

This guide explains how to configure Active Storage to use Cloudflare R2 for file storage.

## What is Cloudflare R2?

Cloudflare R2 is an S3-compatible object storage service with zero egress fees. It's ideal for storing images, documents, and other assets.

## Prerequisites

- Cloudflare account
- R2 enabled on your account (may require payment method on file)

## Step 1: Create R2 Bucket

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **R2** in the left sidebar
3. Click **Create bucket**
4. Enter a bucket name (e.g., `property-web-builder-assets`)
5. Choose a location hint (optional)
6. Click **Create bucket**

## Step 2: Generate API Token

1. In R2, click **Manage R2 API Tokens**
2. Click **Create API token**
3. Enter a token name (e.g., `rails-active-storage`)
4. Set permissions:
   - **Object Read and Write** (or Admin if you need full access)
5. Optionally, restrict to specific bucket
6. Click **Create API token**
7. **Important:** Copy the **Access Key ID** and **Secret Access Key** immediately (you won't see them again!)

## Step 3: Get Account ID

1. In the Cloudflare dashboard, look at the URL
2. Your Account ID is in the URL: `https://dash.cloudflare.com/<ACCOUNT_ID>/r2/overview`
3. Or find it in **R2 > Overview** on the right side

## Step 4: Configure Environment Variables

Add these to your `.env` file:

```bash
R2_ACCESS_KEY_ID=your_access_key_id_here
R2_SECRET_ACCESS_KEY=your_secret_access_key_here
R2_BUCKET=your-bucket-name
R2_ACCOUNT_ID=your_cloudflare_account_id
```

**Security Note:** Never commit `.env` to version control! It's already in `.gitignore`.

## Step 5: Install Dependencies

```bash
bundle install
```

This installs the `aws-sdk-s3` gem needed for S3-compatible storage.

## Step 6: Update Environment Configuration

The production environment is already configured to use R2. For development/staging:

**config/environments/development.rb** (or staging.rb):
```ruby
# Use R2 in development (optional - can keep local for dev)
config.active_storage.service = :cloudflare_r2

# Or keep local storage for development
# config.active_storage.service = :local
```

**config/environments/production.rb**:
```ruby
# Use R2 in production
config.active_storage.service = :cloudflare_r2
```

## Step 7: Test the Configuration

Start Rails console:

```bash
bin/rails console
```

Test upload:

```ruby
# Create a test file
File.write('test.txt', 'Hello R2!')

# Upload via Active Storage
photo = Pwb::WebsitePhoto.new(photo_key: 'test')
photo.image.attach(io: File.open('test.txt'), filename: 'test.txt')
photo.save!

# Check if file was uploaded
photo.image.attached? # Should return true
photo.image.url # Should return R2 URL

# Clean up
File.delete('test.txt')
photo.destroy
```

## Accessing Files

Files stored in R2 can be accessed via:

1. **Private URLs** (default): Require authentication, temporary signed URLs
2. **Public URLs**: Set bucket to public or configure custom domain

### Setting Up Public Access

1. In R2 bucket settings, enable **Public access**
2. Or configure a custom domain:
   - R2 > Your bucket > Settings > **R2.dev subdomain** or **Custom domains**
   - Add your domain and configure DNS

## Migration from Local Storage

If you have existing files in local storage, you need to migrate them:

### Option 1: Manual Upload

1. Download files from `storage/` directory
2. Upload to R2 bucket using:
   - Cloudflare dashboard UI
   - AWS CLI (with R2 endpoint)
   - Rclone or similar tools

### Option 2: Rails Task (Create if needed)

```ruby
# lib/tasks/migrate_to_r2.rake
namespace :storage do
  desc "Migrate Active Storage files from local to R2"
  task migrate_to_r2: :environment do
    ActiveStorage::Blob.find_each do |blob|
      if blob.service_name != 'cloudflare_r2'
        puts "Migrating #{blob.filename}..."
        
        blob.open do |file|
          new_blob = ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: blob.filename,
            content_type: blob.content_type,
            service_name: 'cloudflare_r2'
          )
          
          # Update attachments to use new blob
          blob.attachments.update_all(blob_id: new_blob.id)
        end
        
        blob.purge
        puts "✓ Migrated #{blob.filename}"
      end
    end
    
    puts "Migration complete!"
  end
end
```

Run migration:
```bash
RAILS_ENV=production bin/rails storage:migrate_to_r2
```

## Troubleshooting

### Connection Errors

- Verify all environment variables are set correctly
- Check Account ID is correct (no typos)
- Ensure API token has proper permissions

### 403 Forbidden

- API token may not have write permissions
- Bucket may not exist
- Account ID may be incorrect

### Files Not Appearing

- Check R2 dashboard to confirm uploads
- Verify bucket name matches configuration
- Check Rails logs for errors

## Cost Considerations

- **Storage:** ~$0.015/GB/month
- **Class A Operations:** $4.50 per million (uploads, lists)
- **Class B Operations:** $0.36 per million (downloads)
- **Egress:** **FREE** (major advantage over S3!)

## Additional Resources

- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [Rails Active Storage Guide](https://guides.rubyonrails.org/active_storage_overview.html)
- [AWS SDK for Ruby - S3](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3.html)

## Security Best Practices

1. **Never commit credentials** - Use environment variables
2. **Rotate API tokens** periodically
3. **Use separate buckets** for development/staging/production
4. **Enable CORS** if accessing from browsers
5. **Set appropriate bucket permissions** - private by default unless public needed
