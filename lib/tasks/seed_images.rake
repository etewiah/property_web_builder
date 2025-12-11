# frozen_string_literal: true

require 'net/http'
require 'uri'

namespace :pwb do
  namespace :seed_images do
    desc "Check if seed images are available (local or R2)"
    task check: :environment do
      require_relative '../pwb/seed_images'

      puts "\n=== Seed Images Configuration ==="

      # Show configuration
      puts "R2 Account ID:  #{ENV['R2_ACCOUNT_ID'] || '(not set)'}"
      puts "R2 Bucket:      #{Pwb::SeedImages.r2_bucket || '(not set)'}"
      puts "Base URL:       #{Pwb::SeedImages.base_url || '(not configured)'}"
      puts ""

      if Pwb::SeedImages.enabled?
        puts "Mode: External URLs (R2)"
        puts ""
        check_external_availability
      else
        puts "Mode: Local files"
        puts ""
        check_local_availability

        puts ""
        puts "To enable R2 external images, set:"
        puts "  R2_ACCOUNT_ID=your_account_id"
        puts "  R2_SEED_IMAGES_BUCKET=your_bucket_name"
      end
    end

    desc "Upload seed images to R2 bucket"
    task upload: :environment do
      require_relative '../pwb/seed_images'
      require 'aws-sdk-s3'

      puts "\n=== Upload Seed Images to R2 ==="

      # Validate required environment variables
      missing_vars = []
      missing_vars << 'R2_ACCESS_KEY_ID' unless ENV['R2_ACCESS_KEY_ID'].present?
      missing_vars << 'R2_SECRET_ACCESS_KEY' unless ENV['R2_SECRET_ACCESS_KEY'].present?
      missing_vars << 'R2_ACCOUNT_ID' unless ENV['R2_ACCOUNT_ID'].present?
      missing_vars << 'R2_SEED_IMAGES_BUCKET' unless Pwb::SeedImages.r2_bucket.present?

      if missing_vars.any?
        puts "ERROR: Missing required configuration:"
        missing_vars.each { |var| puts "  - #{var}" }
        puts ""
        puts "Set these in your .env file or environment."
        exit 1
      end

      bucket_name = Pwb::SeedImages.r2_bucket
      endpoint = Pwb::SeedImages.r2_endpoint

      puts "Bucket:   #{bucket_name}"
      puts "Endpoint: #{endpoint}"
      puts ""

      # Initialize S3 client for R2
      client = Aws::S3::Client.new(
        access_key_id: ENV['R2_ACCESS_KEY_ID'],
        secret_access_key: ENV['R2_SECRET_ACCESS_KEY'],
        endpoint: endpoint,
        region: 'auto',
        force_path_style: true
      )

      # Find all images in db/seeds/images/
      images_path = Pwb::SeedImages.local_images_path
      unless images_path.exist?
        puts "ERROR: Images directory not found: #{images_path}"
        exit 1
      end

      image_files = Dir.glob(images_path.join('*.{jpg,jpeg,png,gif,webp}'))

      if image_files.empty?
        puts "No image files found in #{images_path}"
        exit 0
      end

      puts "Found #{image_files.count} image files to upload"
      puts ""

      uploaded = 0
      skipped = 0
      errors = 0

      image_files.each do |file_path|
        filename = File.basename(file_path)
        key = filename # Upload directly to bucket root (no prefix)

        begin
          # Check if file already exists
          begin
            client.head_object(bucket: bucket_name, key: key)
            puts "  SKIP: #{filename} (already exists)"
            skipped += 1
            next
          rescue Aws::S3::Errors::NotFound
            # File doesn't exist, proceed with upload
          end

          # Upload the file
          content_type = case File.extname(filename).downcase
                         when '.jpg', '.jpeg' then 'image/jpeg'
                         when '.png' then 'image/png'
                         when '.gif' then 'image/gif'
                         when '.webp' then 'image/webp'
                         else 'application/octet-stream'
                         end

          File.open(file_path, 'rb') do |file|
            client.put_object(
              bucket: bucket_name,
              key: key,
              body: file,
              content_type: content_type,
              cache_control: 'public, max-age=31536000' # 1 year cache
            )
          end

          puts "  UPLOAD: #{filename}"
          uploaded += 1
        rescue StandardError => e
          puts "  ERROR: #{filename} - #{e.message}"
          errors += 1
        end
      end

      puts ""
      puts "=== Upload Complete ==="
      puts "Uploaded: #{uploaded}"
      puts "Skipped:  #{skipped}"
      puts "Errors:   #{errors}"

      if uploaded > 0 || skipped > 0
        puts ""
        puts "Public URL: #{Pwb::SeedImages.base_url}"
        puts ""
        puts "Images are accessible at:"
        puts "  #{Pwb::SeedImages.base_url}/<filename>"
      end
    end

    desc "Upload seed images (force overwrite existing)"
    task upload_force: :environment do
      ENV['FORCE_UPLOAD'] = 'true'
      Rake::Task['pwb:seed_images:upload_all'].invoke
    end

    desc "Upload all seed images (including existing)"
    task upload_all: :environment do
      require_relative '../pwb/seed_images'
      require 'aws-sdk-s3'

      puts "\n=== Upload All Seed Images to R2 ==="

      missing_vars = []
      missing_vars << 'R2_ACCESS_KEY_ID' unless ENV['R2_ACCESS_KEY_ID'].present?
      missing_vars << 'R2_SECRET_ACCESS_KEY' unless ENV['R2_SECRET_ACCESS_KEY'].present?
      missing_vars << 'R2_ACCOUNT_ID' unless ENV['R2_ACCOUNT_ID'].present?
      missing_vars << 'R2_SEED_IMAGES_BUCKET' unless Pwb::SeedImages.r2_bucket.present?

      if missing_vars.any?
        puts "ERROR: Missing required configuration:"
        missing_vars.each { |var| puts "  - #{var}" }
        exit 1
      end

      bucket_name = Pwb::SeedImages.r2_bucket
      endpoint = Pwb::SeedImages.r2_endpoint

      client = Aws::S3::Client.new(
        access_key_id: ENV['R2_ACCESS_KEY_ID'],
        secret_access_key: ENV['R2_SECRET_ACCESS_KEY'],
        endpoint: endpoint,
        region: 'auto',
        force_path_style: true
      )

      images_path = Pwb::SeedImages.local_images_path
      image_files = Dir.glob(images_path.join('*.{jpg,jpeg,png,gif,webp}'))

      puts "Bucket: #{bucket_name}"
      puts "Uploading #{image_files.count} images (overwriting existing)..."
      puts ""

      uploaded = 0
      errors = 0

      image_files.each do |file_path|
        filename = File.basename(file_path)
        key = filename

        begin
          content_type = case File.extname(filename).downcase
                         when '.jpg', '.jpeg' then 'image/jpeg'
                         when '.png' then 'image/png'
                         when '.gif' then 'image/gif'
                         when '.webp' then 'image/webp'
                         else 'application/octet-stream'
                         end

          File.open(file_path, 'rb') do |file|
            client.put_object(
              bucket: bucket_name,
              key: key,
              body: file,
              content_type: content_type,
              cache_control: 'public, max-age=31536000'
            )
          end

          puts "  UPLOAD: #{filename}"
          uploaded += 1
        rescue StandardError => e
          puts "  ERROR: #{filename} - #{e.message}"
          errors += 1
        end
      end

      puts ""
      puts "Uploaded: #{uploaded}, Errors: #{errors}"

      if uploaded > 0
        puts ""
        puts "Public URL: #{Pwb::SeedImages.base_url}"
      end
    end

    desc "List images in R2 seed images bucket"
    task list_remote: :environment do
      require_relative '../pwb/seed_images'
      require 'aws-sdk-s3'

      missing_vars = []
      missing_vars << 'R2_ACCESS_KEY_ID' unless ENV['R2_ACCESS_KEY_ID'].present?
      missing_vars << 'R2_SECRET_ACCESS_KEY' unless ENV['R2_SECRET_ACCESS_KEY'].present?
      missing_vars << 'R2_ACCOUNT_ID' unless ENV['R2_ACCOUNT_ID'].present?
      missing_vars << 'R2_SEED_IMAGES_BUCKET' unless Pwb::SeedImages.r2_bucket.present?

      if missing_vars.any?
        puts "ERROR: Missing required configuration:"
        missing_vars.each { |var| puts "  - #{var}" }
        exit 1
      end

      bucket_name = Pwb::SeedImages.r2_bucket
      endpoint = Pwb::SeedImages.r2_endpoint

      client = Aws::S3::Client.new(
        access_key_id: ENV['R2_ACCESS_KEY_ID'],
        secret_access_key: ENV['R2_SECRET_ACCESS_KEY'],
        endpoint: endpoint,
        region: 'auto',
        force_path_style: true
      )

      puts "\n=== Images in R2 Bucket ==="
      puts "Bucket: #{bucket_name}"
      puts "Public URL: #{Pwb::SeedImages.base_url}"
      puts ""

      begin
        response = client.list_objects_v2(bucket: bucket_name)

        if response.contents.empty?
          puts "No images found."
        else
          total_size = 0
          response.contents.each do |obj|
            size_kb = (obj.size / 1024.0).round(1)
            total_size += obj.size
            puts "  #{obj.key.ljust(40)} #{size_kb.to_s.rjust(8)} KB"
          end

          puts ""
          puts "Total: #{response.contents.count} files, #{(total_size / 1024.0 / 1024.0).round(2)} MB"
        end
      rescue Aws::S3::Errors::ServiceError => e
        puts "ERROR: #{e.message}"
        exit 1
      end
    end

    desc "Show configuration for seed images"
    task config: :environment do
      require_relative '../pwb/seed_images'

      puts "\n=== Seed Images Configuration ==="
      puts ""
      puts "Environment Variables:"
      puts "  R2_ACCOUNT_ID:          #{ENV['R2_ACCOUNT_ID'] || '(not set)'}"
      puts "  R2_SEED_IMAGES_BUCKET:  #{ENV['R2_SEED_IMAGES_BUCKET'] || '(not set)'}"
      puts "  R2_ACCESS_KEY_ID:       #{ENV['R2_ACCESS_KEY_ID'].present? ? '(set)' : '(not set)'}"
      puts "  R2_SECRET_ACCESS_KEY:   #{ENV['R2_SECRET_ACCESS_KEY'].present? ? '(set)' : '(not set)'}"
      puts "  SEED_IMAGES_BASE_URL:   #{ENV['SEED_IMAGES_BASE_URL'] || '(not set)'}"
      puts ""
      puts "Computed Values:"
      puts "  Enabled:     #{Pwb::SeedImages.enabled?}"
      puts "  Base URL:    #{Pwb::SeedImages.base_url || '(none)'}"
      puts "  R2 Bucket:   #{Pwb::SeedImages.r2_bucket || '(none)'}"
      puts "  R2 Endpoint: #{Pwb::SeedImages.r2_endpoint || '(none)'}"
      puts "  Upload Ready: #{Pwb::SeedImages.r2_upload_configured?}"
      puts ""
      puts "Local Images:"
      puts "  Path:  #{Pwb::SeedImages.local_images_path}"
      puts "  Count: #{Pwb::SeedImages.local_image_count}"
    end
  end
end

# Helper methods for checking image availability
def check_external_availability
  require_relative '../pwb/seed_images'

  # Sample a few images to check
  sample_images = %w[villa_ocean apartment_downtown house_family]

  puts "Checking external image availability..."
  puts ""

  available = 0
  unavailable = 0

  sample_images.each do |image_key|
    url = Pwb::SeedImages.property_url(image_key)
    uri = URI.parse(url)

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 5
      http.read_timeout = 5

      response = http.head(uri.request_uri)

      if response.code.to_i == 200
        puts "  OK: #{image_key} (#{url})"
        available += 1
      else
        puts "  MISSING: #{image_key} (HTTP #{response.code})"
        unavailable += 1
      end
    rescue StandardError => e
      puts "  ERROR: #{image_key} (#{e.class.name})"
      unavailable += 1
    end
  end

  puts ""
  if unavailable > 0
    puts "WARNING: #{unavailable} of #{sample_images.count} sample images are unavailable."
    puts ""
    puts "To upload images to R2:"
    puts "  1. Ensure R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY are set"
    puts "  2. Run: rails pwb:seed_images:upload"
  else
    puts "All sample images are available."
  end
end

def check_local_availability
  require_relative '../pwb/seed_images'

  images_path = Pwb::SeedImages.local_images_path

  if images_path.exist?
    image_files = Dir.glob(images_path.join('*.{jpg,jpeg,png,gif,webp}'))
    puts "Found #{image_files.count} local images in:"
    puts "  #{images_path}"

    if image_files.any?
      puts ""
      puts "Files:"
      image_files.first(10).each do |f|
        puts "  - #{File.basename(f)}"
      end
      puts "  ... and #{image_files.count - 10} more" if image_files.count > 10
    end

    if image_files.count < 5
      puts ""
      puts "WARNING: Few seed images available locally."
      puts "         Seeding may create properties without images."
    end
  else
    puts "WARNING: Local images directory not found:"
    puts "  #{images_path}"
  end
end
