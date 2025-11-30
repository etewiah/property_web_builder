# CarrierWave to ActiveStorage Migration Summary

## Completed Changes

### 1. Model Updates
- **Pwb::ContentPhoto**: Replaced `mount_uploader :image, ContentPhotoUploader` with `has_one_attached :image`
- **Pwb::PropPhoto**: Replaced `mount_uploader :image, PropPhotoUploader` with `has_one_attached :image`
- **Pwb::WebsitePhoto**: Replaced `mount_uploader :image, WebsitePhotoUploader` with `has_one_attached :image`

### 2. Method Updates
- **ContentPhoto#optimized_image_url**: Updated to use ActiveStorage syntax with `image.attached?` and `url_for(image)`
- **Prop#primary_image_url**: Updated to check `image.attached?` and use `url_for(image)`
- **Prop#as_json**: Updated to use ActiveStorage URLs for API responses

### 3. Helper Updates
- **ImagesHelper#opt_image_tag**: Changed `image.present?` to `image.attached?` and `image.url` to `url_for(image)`
- **ImagesHelper#get_opt_image_url**: Updated to use ActiveStorage syntax

### 4. Dependency Removal
- Commented out CarrierWave gem in Gemfile
- Removed all uploader classes:
  - `app/uploaders/pwb/content_photo_uploader.rb`
  - `app/uploaders/pwb/prop_photo_uploader.rb`
  - `app/uploaders/pwb/website_photo_uploader.rb`
- Removed empty `app/uploaders/` directory

### 5. Data Migration Script
- Created `db/migrate/20251129182000_migrate_carrierwave_to_activestorage.rb`
- Handles migration of existing files from CarrierWave storage to ActiveStorage
- Supports both local file storage and URL-based images (Cloudinary)
- Includes rollback functionality
- Migration file was renamed to avoid timestamp conflicts with ActiveStorage installation

### 6. Seeder Updates
- **Fixed ActiveStorage URL generation issue in seeder**
- Updated `lib/pwb/seeder.rb` to use ActiveStorage syntax:
  - `create_photos_from_files` method now uses `photo.image.attach()` instead of `photo.image = file`
  - `create_photos_from_urls` method updated for ActiveStorage
  - Added content type detection helpers
  - Removed CarrierWave-specific `photo.image.url` calls that caused URL generation errors

## Next Steps Required

### 1. Fix Bundler Version Issue (if needed)
If you encounter bundler version errors, run:
```bash
gem install bundler:2.6.9
# or update to latest bundler
bundle update --bundler
```

### 2. Run ActiveStorage Installation (COMPLETED)
✅ ActiveStorage installation was completed and migration files were renamed to avoid conflicts:
- `20251129181658_create_active_storage_tables.active_storage.rb` (ActiveStorage tables)
- `20251129182000_migrate_carrierwave_to_activestorage.rb` (Data migration)

### 3. Install Dependencies
```bash
bundle install
```

### 4. Run Database Migrations
```bash
bin/rails db:migrate
```

### 4. Testing Checklist

#### File Upload Testing
- [ ] Test uploading new images through ContentPhoto
- [ ] Test uploading new images through PropPhoto  
- [ ] Test uploading new images through WebsitePhoto
- [ ] Verify files are stored in ActiveStorage blob storage
- [ ] Check that file variants work correctly

#### Display Testing
- [ ] Verify existing images display correctly in views
- [ ] Test `optimized_image_url` method in ContentPhoto
- [ ] Test `primary_image_url` method in Prop
- [ ] Verify API responses include correct image URLs
- [ ] Test image helpers in views

#### Edge Cases
- [ ] Test behavior with missing/deleted files
- [ ] Test Cloudinary integration (if used)
- [ ] Verify image variants and resizing work
- [ ] Test file deletion functionality

### 5. Configuration Updates (if needed)

#### Storage Configuration
Update `config/storage.yml` if using cloud storage:
```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# For production with cloud storage
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: your_bucket_name
```

#### Environment Configuration
Update environment files to use ActiveStorage:
```ruby
# config/environments/production.rb
config.active_storage.variant_processor = :mini_magick
```

## Important Notes

1. **Backup**: Ensure you have backups of both database and uploaded files before running migration
2. **Cloudinary**: The migration script handles URL-based images but may need additional configuration for Cloudinary integration with ActiveStorage
3. **File Paths**: The migration assumes CarrierWave files are stored in `public/uploads/` directory
4. **Testing**: Thoroughly test all file upload and display functionality before deploying to production

## Rollback Plan

If issues arise, you can:
1. Run the migration rollback: `bin/rails db:rollback`
2. Uncomment CarrierWave gem in Gemfile
3. Restore uploader classes from version control
4. Run `bundle install`
5. Revert model changes

The migration includes a `down` method that will remove ActiveStorage attachments, but this is destructive and should be used with caution.
