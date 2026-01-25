# frozen_string_literal: true

# Asset CDN deployment tasks for Cloudflare R2
#
# Environment Variables (in order of precedence):
#
# Bucket:
#   CDN_ASSETS_BUCKET      - Preferred: Bucket for static assets
#   R2_ASSETS_BUCKET       - Legacy alias
#   R2_BUCKET              - Fallback (shared bucket)
#
# Access Key:
#   CDN_ASSETS_ACCESS_KEY_ID    - Preferred: Separate key for assets
#   R2_ASSETS_ACCESS_KEY_ID     - Legacy alias
#   R2_ACCESS_KEY_ID            - Fallback (shared key)
#
# Secret Key:
#   CDN_ASSETS_SECRET_ACCESS_KEY - Preferred: Separate secret for assets
#   R2_ASSETS_SECRET_ACCESS_KEY  - Legacy alias
#   R2_SECRET_ACCESS_KEY         - Fallback (shared secret)
#
# Account:
#   R2_ACCOUNT_ID          - Cloudflare account ID (required)

require "pwb/r2_credentials"

namespace :assets do
  # Helper method to get assets bucket name
  def assets_bucket
    ENV["CDN_ASSETS_BUCKET"] || Pwb::R2Credentials.assets_bucket || Pwb::R2Credentials.bucket || ENV.fetch("R2_BUCKET")
  end

  # Helper method to get assets access key
  def assets_access_key_id
    ENV["CDN_ASSETS_ACCESS_KEY_ID"] || Pwb::R2Credentials.assets_access_key_id || Pwb::R2Credentials.access_key_id || ENV.fetch("R2_ACCESS_KEY_ID")
  end

  # Helper method to get assets secret key
  def assets_secret_access_key
    ENV["CDN_ASSETS_SECRET_ACCESS_KEY"] || Pwb::R2Credentials.assets_secret_access_key || Pwb::R2Credentials.secret_access_key || ENV.fetch("R2_SECRET_ACCESS_KEY")
  end

  # Helper method to create R2 client for assets
  def assets_r2_client
    require "aws-sdk-s3"

    account_id = Pwb::R2Credentials.account_id || ENV.fetch("R2_ACCOUNT_ID")
    endpoint = "https://#{account_id}.r2.cloudflarestorage.com"

    Aws::S3::Client.new(
      access_key_id: assets_access_key_id,
      secret_access_key: assets_secret_access_key,
      endpoint: endpoint,
      region: "auto",
      force_path_style: true,
      ssl_verify_peer: false  # Workaround for macOS CRL verification issues
    )
  end

  # Content type mapping for uploads
  def content_type_for(ext)
    {
      ".js" => "application/javascript",
      ".css" => "text/css",
      ".png" => "image/png",
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".gif" => "image/gif",
      ".svg" => "image/svg+xml",
      ".woff" => "font/woff",
      ".woff2" => "font/woff2",
      ".ttf" => "font/ttf",
      ".eot" => "application/vnd.ms-fontobject",
      ".otf" => "font/otf",
      ".ico" => "image/x-icon",
      ".map" => "application/json",
      ".json" => "application/json",
      ".webp" => "image/webp"
    }[ext.downcase] || "application/octet-stream"
  end

  # Helper to sync a directory to R2
  def sync_directory_to_r2(client, bucket, local_path, r2_prefix, cache_control: "public, max-age=31536000, immutable")
    uploaded = 0
    skipped = 0

    Dir.glob("#{local_path}/**/*").each do |file_path|
      next if File.directory?(file_path)

      key = "#{r2_prefix}/#{file_path.sub("#{local_path}/", "")}"
      ext = File.extname(file_path)
      content_type = content_type_for(ext)

      # Check if file already exists with same size AND correct content-type
      begin
        head = client.head_object(bucket: bucket, key: key)
        if head.content_length == File.size(file_path) && head.content_type == content_type
          skipped += 1
          next
        end
        # File exists but has wrong size or content-type, will re-upload
      rescue Aws::S3::Errors::NotFound
        # File doesn't exist, will upload
      end

      # Upload with cache headers
      File.open(file_path, "rb") do |file|
        client.put_object(
          bucket: bucket,
          key: key,
          body: file,
          content_type: content_type,
          cache_control: cache_control
        )
      end

      uploaded += 1
      puts "  Uploaded: #{key}" if ENV["VERBOSE"]
    end

    { uploaded: uploaded, skipped: skipped }
  end

  desc "Sync compiled assets to Cloudflare R2 for CDN delivery"
  task sync_to_r2: :environment do
    bucket = assets_bucket
    client = assets_r2_client
    assets_path = Rails.root.join("public", "assets")

    unless assets_path.exist?
      puts "No assets directory found. Run 'rails assets:precompile' first."
      exit 1
    end

    puts "Syncing assets to R2 bucket: #{bucket}"

    result = sync_directory_to_r2(client, bucket, assets_path, "assets")

    puts "Done! Uploaded: #{result[:uploaded]}, Skipped (unchanged): #{result[:skipped]}"
  end

  desc "Sync public/fonts to Cloudflare R2 for CDN delivery"
  task sync_fonts_to_r2: :environment do
    bucket = assets_bucket
    client = assets_r2_client
    fonts_path = Rails.root.join("public", "fonts")

    unless fonts_path.exist?
      puts "No fonts directory found at public/fonts."
      exit 1
    end

    puts "Syncing fonts to R2 bucket: #{bucket}"

    result = sync_directory_to_r2(client, bucket, fonts_path, "fonts")

    puts "Done! Uploaded: #{result[:uploaded]}, Skipped (unchanged): #{result[:skipped]}"
  end

  desc "Precompile assets and sync to R2 (includes fonts)"
  task cdn_deploy: :environment do
    Rake::Task["assets:precompile"].invoke
    Rake::Task["assets:sync_to_r2"].invoke
    Rake::Task["assets:sync_fonts_to_r2"].invoke
  end

  desc "Configure CORS on R2 bucket for CDN delivery"
  task configure_cors: :environment do
    bucket = assets_bucket
    client = assets_r2_client

    cors_configuration = {
      cors_rules: [
        {
          allowed_headers: ["*"],
          allowed_methods: ["GET", "HEAD"],
          allowed_origins: ["https://*.propertywebbuilder.com", "http://localhost:3000"],
          max_age_seconds: 86400
        }
      ]
    }

    puts "Configuring CORS on R2 bucket: #{bucket}"

    begin
      client.put_bucket_cors(
        bucket: bucket,
        cors_configuration: cors_configuration
      )

      puts "CORS configured successfully via S3 API!"
      puts "Allowed origins: https://*.propertywebbuilder.com, http://localhost:3000"
    rescue Aws::S3::Errors::ServiceError => e
      puts "Warning: Could not set CORS via S3 API: #{e.message}"
    end

    puts ""
    puts "IMPORTANT: If using a custom domain (e.g., cdn-assets.propertywebbuilder.com),"
    puts "you may also need to configure CORS via Cloudflare Transform Rules:"
    puts ""
    puts "1. Go to Cloudflare Dashboard > Your Domain > Rules > Transform Rules"
    puts "2. Create a 'Modify Response Header' rule"
    puts "3. Set: When 'Hostname equals cdn-assets.propertywebbuilder.com'"
    puts "4. Add header: Access-Control-Allow-Origin = *"
    puts "5. Add header: Access-Control-Allow-Methods = GET, HEAD, OPTIONS"
    puts ""
  end

  desc "Fix content-type metadata for existing assets on R2 (for files with wrong MIME type)"
  task fix_content_types: :environment do
    bucket = assets_bucket
    client = assets_r2_client

    puts "Checking and fixing content-types in R2 bucket: #{bucket}"

    fixed = 0
    checked = 0
    continuation_token = nil

    loop do
      list_params = { bucket: bucket, prefix: "assets/", max_keys: 1000 }
      list_params[:continuation_token] = continuation_token if continuation_token

      response = client.list_objects_v2(list_params)

      break if response.contents.empty?

      response.contents.each do |obj|
        checked += 1
        key = obj.key
        ext = File.extname(key)
        expected_content_type = content_type_for(ext)

        # Skip files that would get application/octet-stream anyway
        next if expected_content_type == "application/octet-stream"

        begin
          head = client.head_object(bucket: bucket, key: key)
          current_content_type = head.content_type

          # Fix if content-type is wrong
          if current_content_type != expected_content_type
            puts "  Fixing: #{key} (#{current_content_type} -> #{expected_content_type})"

            # Copy object to itself with correct content-type (R2/S3 way to update metadata)
            client.copy_object(
              bucket: bucket,
              copy_source: "#{bucket}/#{key}",
              key: key,
              content_type: expected_content_type,
              cache_control: "public, max-age=31536000, immutable",
              metadata_directive: "REPLACE"
            )
            fixed += 1
          end
        rescue Aws::S3::Errors::ServiceError => e
          puts "  Error processing #{key}: #{e.message}"
        end
      end

      break unless response.is_truncated

      continuation_token = response.next_continuation_token
    end

    puts "Done! Checked: #{checked}, Fixed: #{fixed}"
  end

  desc "Force re-sync all assets to R2 (ignores size check, updates metadata)"
  task force_sync_to_r2: :environment do
    bucket = assets_bucket
    client = assets_r2_client
    assets_path = Rails.root.join("public", "assets")

    unless assets_path.exist?
      puts "No assets directory found. Run 'rails assets:precompile' first."
      exit 1
    end

    puts "Force syncing ALL assets to R2 bucket: #{bucket}"
    uploaded = 0

    Dir.glob("#{assets_path}/**/*").each do |file_path|
      next if File.directory?(file_path)

      key = "assets/#{file_path.sub("#{assets_path}/", "")}"
      ext = File.extname(file_path)
      content_type = content_type_for(ext)

      File.open(file_path, "rb") do |file|
        client.put_object(
          bucket: bucket,
          key: key,
          body: file,
          content_type: content_type,
          cache_control: "public, max-age=31536000, immutable"
        )
      end

      uploaded += 1
      puts "  Uploaded: #{key} (#{content_type})" if ENV["VERBOSE"]
    end

    puts "Done! Uploaded: #{uploaded} files"
  end

  desc "Clear all objects from R2 assets bucket"
  task clear_r2: :environment do
    bucket = assets_bucket
    client = assets_r2_client

    puts "Clearing all objects from R2 bucket: #{bucket}"
    puts "This may take a while for large buckets..."

    deleted = 0
    continuation_token = nil

    loop do
      list_params = { bucket: bucket, max_keys: 1000 }
      list_params[:continuation_token] = continuation_token if continuation_token

      response = client.list_objects_v2(list_params)

      break if response.contents.empty?

      objects_to_delete = response.contents.map { |obj| { key: obj.key } }

      client.delete_objects(
        bucket: bucket,
        delete: { objects: objects_to_delete }
      )

      deleted += objects_to_delete.size
      puts "  Deleted #{deleted} objects..." if ENV["VERBOSE"] || deleted % 1000 == 0

      break unless response.is_truncated

      continuation_token = response.next_continuation_token
    end

    puts "Done! Deleted #{deleted} objects from #{bucket}"
  end
end
