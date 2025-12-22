# frozen_string_literal: true

namespace :assets do
  desc "Sync compiled assets to Cloudflare R2 for CDN delivery"
  task sync_to_r2: :environment do
    require "aws-sdk-s3"

    # R2 configuration from environment
    account_id = ENV.fetch("R2_ACCOUNT_ID")
    access_key_id = ENV.fetch("R2_ACCESS_KEY_ID")
    secret_access_key = ENV.fetch("R2_SECRET_ACCESS_KEY")
    bucket = ENV.fetch("R2_BUCKET")

    endpoint = "https://#{account_id}.r2.cloudflarestorage.com"

    client = Aws::S3::Client.new(
      access_key_id: access_key_id,
      secret_access_key: secret_access_key,
      endpoint: endpoint,
      region: "auto",
      force_path_style: true
    )

    assets_path = Rails.root.join("public", "assets")

    unless assets_path.exist?
      puts "No assets directory found. Run 'rails assets:precompile' first."
      exit 1
    end

    puts "Syncing assets to R2 bucket: #{bucket}"

    # Content type mapping
    content_types = {
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
      ".ico" => "image/x-icon",
      ".map" => "application/json",
      ".json" => "application/json",
      ".webp" => "image/webp"
    }

    uploaded = 0
    skipped = 0

    Dir.glob("#{assets_path}/**/*").each do |file_path|
      next if File.directory?(file_path)

      key = "assets/#{file_path.sub("#{assets_path}/", "")}"
      ext = File.extname(file_path).downcase
      content_type = content_types[ext] || "application/octet-stream"

      # Check if file already exists with same size
      begin
        head = client.head_object(bucket: bucket, key: key)
        if head.content_length == File.size(file_path)
          skipped += 1
          next
        end
      rescue Aws::S3::Errors::NotFound
        # File doesn't exist, will upload
      end

      # Upload with cache headers (assets are digest-stamped, cache forever)
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
      puts "  Uploaded: #{key}" if ENV["VERBOSE"]
    end

    puts "Done! Uploaded: #{uploaded}, Skipped (unchanged): #{skipped}"
  end

  desc "Precompile assets and sync to R2"
  task cdn_deploy: :environment do
    Rake::Task["assets:precompile"].invoke
    Rake::Task["assets:sync_to_r2"].invoke
  end
end
