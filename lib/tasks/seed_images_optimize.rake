# frozen_string_literal: true

# Seed Image Optimization Tasks
#
# Provides tools to optimize seed images for better performance:
# - Compress JPEGs to reduce file size
# - Resize oversized images to appropriate dimensions
# - Generate WebP versions for modern browsers
# - Report size savings

namespace :seed_images do
  # Image size targets by category
  IMAGE_TARGETS = {
    property: { width: 1200, height: 800, quality: 82 },
    hero: { width: 1600, height: 1067, quality: 80 },
    team: { width: 600, height: 800, quality: 85 },
    content: { width: 1200, height: 800, quality: 82 }
  }.freeze

  # WebP quality (slightly lower than JPEG for similar visual quality)
  WEBP_QUALITY = 80

  desc "Optimize all seed images (compress, resize, generate WebP)"
  task optimize: :environment do
    require "fileutils"

    puts "=" * 60
    puts "Seed Image Optimization"
    puts "=" * 60

    check_dependencies!

    total_before = 0
    total_after = 0
    webp_total = 0

    seed_image_dirs.each do |dir, category|
      next unless File.directory?(dir)

      puts "\n#{category.to_s.titleize} images: #{dir}"
      puts "-" * 40

      Dir.glob("#{dir}/*.jpg").each do |file|
        before_size = File.size(file)
        total_before += before_size

        # Determine target dimensions based on filename patterns
        target = determine_target(file, category)

        # Optimize JPEG
        optimize_jpeg(file, target)

        after_size = File.size(file)
        total_after += after_size

        # Generate WebP
        webp_file = file.sub(/\.jpg$/i, ".webp")
        generate_webp(file, webp_file, target)
        webp_size = File.exist?(webp_file) ? File.size(webp_file) : 0
        webp_total += webp_size

        # Report
        savings = ((before_size - after_size) / before_size.to_f * 100).round(1)
        webp_savings = webp_size > 0 ? ((before_size - webp_size) / before_size.to_f * 100).round(1) : 0

        puts format(
          "  %-40s %6s -> %6s (-%s%%) | WebP: %6s (-%s%%)",
          File.basename(file),
          human_size(before_size),
          human_size(after_size),
          savings,
          human_size(webp_size),
          webp_savings
        )
      end
    end

    puts "\n" + "=" * 60
    puts "Summary"
    puts "=" * 60
    puts format("JPEG: %s -> %s (saved %s, %.1f%%)",
                human_size(total_before),
                human_size(total_after),
                human_size(total_before - total_after),
                ((total_before - total_after) / total_before.to_f * 100))
    puts format("WebP: %s total (%.1f%% smaller than original JPEGs)",
                human_size(webp_total),
                ((total_before - webp_total) / total_before.to_f * 100))
    puts "=" * 60
  end

  desc "Optimize JPEGs only (no WebP generation)"
  task optimize_jpeg: :environment do
    check_dependencies!

    puts "Optimizing JPEG files..."

    seed_image_dirs.each do |dir, category|
      next unless File.directory?(dir)

      Dir.glob("#{dir}/*.jpg").each do |file|
        target = determine_target(file, category)
        before = File.size(file)
        optimize_jpeg(file, target)
        after = File.size(file)
        savings = ((before - after) / before.to_f * 100).round(1)
        puts "  #{File.basename(file)}: #{human_size(before)} -> #{human_size(after)} (-#{savings}%)"
      end
    end
  end

  desc "Generate WebP versions of all seed images"
  task generate_webp: :environment do
    check_dependencies!

    puts "Generating WebP files..."

    seed_image_dirs.each do |dir, category|
      next unless File.directory?(dir)

      Dir.glob("#{dir}/*.jpg").each do |file|
        target = determine_target(file, category)
        webp_file = file.sub(/\.jpg$/i, ".webp")
        generate_webp(file, webp_file, target)

        if File.exist?(webp_file)
          jpg_size = File.size(file)
          webp_size = File.size(webp_file)
          savings = ((jpg_size - webp_size) / jpg_size.to_f * 100).round(1)
          puts "  #{File.basename(webp_file)}: #{human_size(webp_size)} (-#{savings}% vs JPEG)"
        end
      end
    end
  end

  desc "Report current seed image sizes"
  task report: :environment do
    puts "=" * 70
    puts "Seed Image Report"
    puts "=" * 70

    total_jpg = 0
    total_webp = 0
    count_jpg = 0
    count_webp = 0

    seed_image_dirs.each do |dir, category|
      next unless File.directory?(dir)

      puts "\n#{category.to_s.titleize}: #{dir}"
      puts "-" * 60

      jpgs = Dir.glob("#{dir}/*.jpg").sort
      webps = Dir.glob("#{dir}/*.webp").sort

      jpgs.each do |jpg|
        size = File.size(jpg)
        total_jpg += size
        count_jpg += 1

        # Get dimensions
        dims = get_dimensions(jpg)
        webp = jpg.sub(/\.jpg$/i, ".webp")
        webp_info = if File.exist?(webp)
                      webp_size = File.size(webp)
                      total_webp += webp_size
                      count_webp += 1
                      format("WebP: %s", human_size(webp_size))
                    else
                      "WebP: missing"
                    end

        puts format("  %-35s %10s  %s  %s",
                    File.basename(jpg),
                    dims,
                    human_size(size),
                    webp_info)
      end
    end

    puts "\n" + "=" * 70
    puts "Totals"
    puts "=" * 70
    puts format("JPEG files: %d (total: %s)", count_jpg, human_size(total_jpg))
    puts format("WebP files: %d (total: %s)", count_webp, human_size(total_webp))
    if count_webp > 0 && total_jpg > 0
      puts format("WebP savings: %s (%.1f%%)",
                  human_size(total_jpg - total_webp),
                  ((total_jpg - total_webp) / total_jpg.to_f * 100))
    end
    puts "=" * 70
  end

  desc "Clean up WebP files (remove all generated .webp files)"
  task clean_webp: :environment do
    puts "Removing WebP files..."

    count = 0
    seed_image_dirs.each do |dir, _category|
      next unless File.directory?(dir)

      Dir.glob("#{dir}/*.webp").each do |file|
        File.delete(file)
        count += 1
        puts "  Deleted: #{file}"
      end
    end

    puts "Removed #{count} WebP files."
  end

  # Helper methods

  def seed_image_dirs
    base = Rails.root.join("db/seeds")
    dirs = {}

    # Base seed images
    dirs[base.join("images").to_s] = :property

    # Seed pack images
    Dir.glob(base.join("packs/*/images")).each do |pack_dir|
      pack_name = File.basename(File.dirname(pack_dir))
      dirs[pack_dir] = :property
    end

    dirs
  end

  def determine_target(file, default_category)
    filename = File.basename(file).downcase

    if filename.include?("hero") || filename.include?("banner")
      IMAGE_TARGETS[:hero]
    elsif filename.include?("team") || filename.include?("agent") || filename.include?("director") || filename.include?("assistant")
      IMAGE_TARGETS[:team]
    elsif filename.include?("office") || filename.include?("carousel")
      IMAGE_TARGETS[:content]
    else
      IMAGE_TARGETS[default_category] || IMAGE_TARGETS[:property]
    end
  end

  def optimize_jpeg(file, target)
    temp_file = "#{file}.tmp"

    # Use ImageMagick to resize and compress
    cmd = [
      "magick",
      file,
      "-resize", "#{target[:width]}x#{target[:height]}>", # Only shrink, don't enlarge
      "-quality", target[:quality].to_s,
      "-strip",                    # Remove metadata
      "-interlace", "Plane",       # Progressive JPEG
      "-sampling-factor", "4:2:0", # Chroma subsampling
      "-colorspace", "sRGB",       # Ensure sRGB
      temp_file
    ]

    system(*cmd, exception: true)
    FileUtils.mv(temp_file, file)
  rescue StandardError => e
    File.delete(temp_file) if File.exist?(temp_file)
    puts "    ERROR optimizing #{file}: #{e.message}"
  end

  def generate_webp(source, dest, target)
    # Calculate resize dimensions
    dims = get_dimensions(source)
    return unless dims

    width, height = dims.split("x").map(&:to_i)
    target_width = [width, target[:width]].min
    target_height = [height, target[:height]].min

    cmd = [
      "cwebp",
      "-q", WEBP_QUALITY.to_s,
      "-resize", target_width.to_s, target_height.to_s,
      "-m", "6",          # Compression method (0-6, higher = better but slower)
      "-mt",              # Multi-threading
      source,
      "-o", dest
    ]

    system(*cmd, out: File::NULL, err: File::NULL, exception: true)
  rescue StandardError => e
    puts "    ERROR generating WebP for #{source}: #{e.message}"
  end

  def get_dimensions(file)
    output = `magick identify -format "%wx%h" "#{file}" 2>/dev/null`.strip
    output.empty? ? nil : output
  rescue StandardError
    nil
  end

  def human_size(bytes)
    return "0 B" if bytes.zero?

    units = %w[B KB MB GB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp >= units.length

    format("%.1f %s", bytes.to_f / (1024**exp), units[exp])
  end

  def check_dependencies!
    unless system("which magick > /dev/null 2>&1")
      abort "ERROR: ImageMagick 7+ is required. Install with: brew install imagemagick"
    end

    unless system("which cwebp > /dev/null 2>&1")
      abort "ERROR: cwebp is required for WebP generation. Install with: brew install webp"
    end
  end
end
