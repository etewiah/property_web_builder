# frozen_string_literal: true

require 'net/http'
require 'uri'

require 'pwb/r2_credentials'

namespace :pwb do
  namespace :seed_images do
    desc "Check if seed images are available (local or R2)"
    task check: :environment do
      require_relative '../pwb/seed_images'

      puts "\n=== Seed Images Configuration ==="

      # Show configuration
      puts "R2 Account ID:  #{Pwb::R2Credentials.account_id || '(not set)'}"
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
      missing_vars << 'R2_ACCESS_KEY_ID' unless Pwb::R2Credentials.access_key_id.present?
      missing_vars << 'R2_SECRET_ACCESS_KEY' unless Pwb::R2Credentials.secret_access_key.present?
      missing_vars << 'R2_ACCOUNT_ID' unless (Pwb::SeedImages.r2_account_id || Pwb::R2Credentials.account_id).present?
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
        access_key_id: Pwb::R2Credentials.access_key_id,
        secret_access_key: Pwb::R2Credentials.secret_access_key,
        endpoint: endpoint,
        region: 'auto',
        force_path_style: true
      )

      # Collect all image files with their R2 keys
      # Format: { file_path => r2_key }
      image_mappings = collect_seed_image_files

      if image_mappings.empty?
        puts "No image files found"
        exit 0
      end

      puts "Total: #{image_mappings.count} image files to upload"
      puts ""

      uploaded = 0
      skipped = 0
      errors = 0

      image_mappings.each do |file_path, key|
        begin
          # Check if file already exists
          begin
            client.head_object(bucket: bucket_name, key: key)
            puts "  SKIP: #{key} (already exists)"
            skipped += 1
            next
          rescue Aws::S3::Errors::NotFound
            # File doesn't exist, proceed with upload
          end

          # Upload the file
          content_type = case File.extname(file_path).downcase
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

          puts "  UPLOAD: #{key}"
          uploaded += 1
        rescue StandardError => e
          puts "  ERROR: #{key} - #{e.message}"
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
      missing_vars << 'R2_ACCESS_KEY_ID' unless Pwb::R2Credentials.access_key_id.present?
      missing_vars << 'R2_SECRET_ACCESS_KEY' unless Pwb::R2Credentials.secret_access_key.present?
      missing_vars << 'R2_ACCOUNT_ID' unless (Pwb::SeedImages.r2_account_id || Pwb::R2Credentials.account_id).present?
      missing_vars << 'R2_SEED_IMAGES_BUCKET' unless Pwb::SeedImages.r2_bucket.present?

      if missing_vars.any?
        puts "ERROR: Missing required configuration:"
        missing_vars.each { |var| puts "  - #{var}" }
        exit 1
      end

      bucket_name = Pwb::SeedImages.r2_bucket
      endpoint = Pwb::SeedImages.r2_endpoint

      client = Aws::S3::Client.new(
        access_key_id: Pwb::R2Credentials.access_key_id,
        secret_access_key: Pwb::R2Credentials.secret_access_key,
        endpoint: endpoint,
        region: 'auto',
        force_path_style: true
      )

      # Collect all image files with their R2 keys
      image_mappings = collect_seed_image_files

      puts "Bucket: #{bucket_name}"
      puts "Uploading #{image_mappings.count} images (overwriting existing)..."
      puts ""

      uploaded = 0
      errors = 0

      image_mappings.each do |file_path, key|
        begin
          content_type = case File.extname(file_path).downcase
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

          puts "  UPLOAD: #{key}"
          uploaded += 1
        rescue StandardError => e
          puts "  ERROR: #{key} - #{e.message}"
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
      missing_vars << 'R2_ACCESS_KEY_ID' unless Pwb::R2Credentials.access_key_id.present?
      missing_vars << 'R2_SECRET_ACCESS_KEY' unless Pwb::R2Credentials.secret_access_key.present?
      missing_vars << 'R2_ACCOUNT_ID' unless (Pwb::SeedImages.r2_account_id || Pwb::R2Credentials.account_id).present?
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

    desc "List local images and their R2 keys (preview before upload)"
    task list_local: :environment do
      puts "\n=== Local Seed Images ==="
      puts ""

      mappings = collect_seed_image_files

      if mappings.empty?
        puts "No image files found."
        exit 0
      end

      # Group by prefix for organized display
      grouped = mappings.group_by { |_, key| key.split('/').first }

      grouped.each do |prefix, files|
        puts "#{prefix}/ (#{files.count} files):"
        files.sort_by { |_, key| key }.each do |file_path, key|
          size_kb = (File.size(file_path) / 1024.0).round(1)
          puts "  #{key.ljust(50)} #{size_kb.to_s.rjust(8)} KB"
        end
        puts ""
      end

      total_size = mappings.keys.sum { |f| File.size(f) }
      puts "Total: #{mappings.count} files, #{(total_size / 1024.0 / 1024.0).round(2)} MB"
    end

    desc "Upload seed images with generated variants to R2 bucket"
    task upload_with_variants: :environment do
      require_relative '../pwb/seed_images'
      require_relative '../pwb/seed_image_variants'
      require 'aws-sdk-s3'

      puts "\n=== Upload Seed Images with Variants to R2 ==="

      # Validate required environment variables
      missing_vars = []
      missing_vars << 'R2_ACCESS_KEY_ID' unless Pwb::R2Credentials.access_key_id.present?
      missing_vars << 'R2_SECRET_ACCESS_KEY' unless Pwb::R2Credentials.secret_access_key.present?
      missing_vars << 'R2_ACCOUNT_ID' unless (Pwb::SeedImages.r2_account_id || Pwb::R2Credentials.account_id).present?
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
      puts "Variant widths (naming: {basename}-{width}.webp):"
      Pwb::SeedImageVariants::VARIANT_WIDTHS.each do |width, dims|
        puts "  #{width}px: #{dims[0]}x#{dims[1]}"
      end
      puts "Format: #{Pwb::SeedImageVariants::DEFAULT_FORMAT}"
      puts ""

      # Initialize S3 client for R2
      client = Aws::S3::Client.new(
        access_key_id: Pwb::R2Credentials.access_key_id,
        secret_access_key: Pwb::R2Credentials.secret_access_key,
        endpoint: endpoint,
        region: 'auto',
        force_path_style: true
      )

      # Collect all image files with their R2 keys
      image_mappings = collect_seed_image_files

      if image_mappings.empty?
        puts "No image files found"
        exit 0
      end

      puts "Processing #{image_mappings.count} images..."
      puts ""

      uploaded_originals = 0
      uploaded_variants = 0
      skipped = 0
      errors = 0

      image_mappings.each do |file_path, key|
        puts "Processing: #{key}"

        begin
          # Upload original if not exists
          original_exists = begin
            client.head_object(bucket: bucket_name, key: key)
            true
          rescue Aws::S3::Errors::NotFound
            false
          end

          unless original_exists
            content_type = content_type_for(file_path)
            File.open(file_path, 'rb') do |file|
              client.put_object(
                bucket: bucket_name,
                key: key,
                body: file,
                content_type: content_type,
                cache_control: 'public, max-age=31536000'
              )
            end
            puts "  UPLOAD: #{key} (original)"
            uploaded_originals += 1
          else
            puts "  SKIP: #{key} (original exists)"
            skipped += 1
          end

          # Generate and upload variants
          puts "  Generating variants..."
          variants = Pwb::SeedImageVariants.generate_from_file(file_path)

          variants.each do |width, formats|
            formats.each do |format, data|
              variant_key = Pwb::SeedImageVariants.variant_key(key, width, format)

              # Check if variant already exists
              variant_exists = begin
                client.head_object(bucket: bucket_name, key: variant_key)
                true
              rescue Aws::S3::Errors::NotFound
                false
              end

              if variant_exists
                puts "    SKIP: #{variant_key} (exists)"
                skipped += 1
                next
              end

              content_type = format == 'webp' ? 'image/webp' : 'image/jpeg'
              client.put_object(
                bucket: bucket_name,
                key: variant_key,
                body: data,
                content_type: content_type,
                cache_control: 'public, max-age=31536000'
              )
              puts "    UPLOAD: #{variant_key}"
              uploaded_variants += 1
            end
          end

        rescue StandardError => e
          puts "  ERROR: #{e.message}"
          errors += 1
        end
      end

      puts ""
      puts "=== Upload Complete ==="
      puts "Original images: #{uploaded_originals}"
      puts "Variant images:  #{uploaded_variants}"
      puts "Skipped:         #{skipped}"
      puts "Errors:          #{errors}"

      if uploaded_originals > 0 || uploaded_variants > 0
        puts ""
        puts "Public URL: #{Pwb::SeedImages.base_url}"
        puts ""
        puts "Example variant URLs:"
        first_key = image_mappings.values.first
        if first_key
          puts "  Original:  #{Pwb::SeedImages.base_url}/#{first_key}"
          puts "  Thumbnail: #{Pwb::SeedImages.base_url}/#{Pwb::SeedImageVariants.variant_key(first_key, 'thumb', 'jpg')}"
          puts "  WebP:      #{Pwb::SeedImages.base_url}/#{Pwb::SeedImageVariants.variant_key(first_key, 'thumb', 'webp')}"
        end
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

      # Workaround for macOS OpenSSL 3.6+ CRL checking issue
      if http.use_ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_callback = ->(_preverify_ok, _store_ctx) { true }
      end

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
    puts "Possible causes:"
    puts "  - HTTP 401/403: R2 bucket needs public access enabled"
    puts "    (Cloudflare Dashboard > R2 > #{Pwb::SeedImages.r2_bucket} > Settings > Public Access)"
    puts "  - HTTP 404: Images not uploaded yet"
    puts "    Run: rails pwb:seed_images:upload"
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

# Collect all seed image files from various directories
# Returns a hash mapping local file paths to R2 keys with prefix naming convention
#
# Directory structure -> R2 key prefix:
#   db/seeds/images/           -> seeds/
#   db/example_images/         -> example/
#   db/seeds/packs/NAME/images/ -> packs/NAME/
#
# @return [Hash<String, String>] { file_path => r2_key }
def collect_seed_image_files
  mappings = {}
  db_path = Rails.root.join('db')

  # 1. db/seeds/images/ -> seeds/filename.jpg
  seeds_images_path = db_path.join('seeds', 'images')
  if seeds_images_path.exist?
    Dir.glob(seeds_images_path.join('*.{jpg,jpeg,png,gif,webp}')).each do |file|
      filename = File.basename(file)
      mappings[file] = "seeds/#{filename}"
    end
  end

  # 2. db/example_images/ -> example/filename.jpg
  example_images_path = db_path.join('example_images')
  if example_images_path.exist?
    Dir.glob(example_images_path.join('*.{jpg,jpeg,png,gif,webp}')).each do |file|
      filename = File.basename(file)
      mappings[file] = "example/#{filename}"
    end
  end

  # 3. db/seeds/packs/*/images/ -> packs/pack_name/filename.jpg
  packs_path = db_path.join('seeds', 'packs')
  if packs_path.exist?
    Dir.glob(packs_path.join('*', 'images')).each do |pack_images_dir|
      pack_name = File.basename(File.dirname(pack_images_dir))
      Dir.glob(File.join(pack_images_dir, '*.{jpg,jpeg,png,gif,webp}')).each do |file|
        filename = File.basename(file)
        mappings[file] = "packs/#{pack_name}/#{filename}"
      end
    end
  end

  mappings
end

# Get content type for an image file
# @param file_path [String] Path to the file
# @return [String] MIME type
def content_type_for(file_path)
  case File.extname(file_path).downcase
  when '.jpg', '.jpeg' then 'image/jpeg'
  when '.png' then 'image/png'
  when '.gif' then 'image/gif'
  when '.webp' then 'image/webp'
  else 'application/octet-stream'
  end
end
