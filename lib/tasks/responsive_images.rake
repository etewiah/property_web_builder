# frozen_string_literal: true

namespace :images do
  namespace :variants do
    desc "Generate responsive variants for all existing property photos"
    task generate_all: :environment do
      puts "Starting responsive variant generation for all photo models..."
      puts "AVIF support: #{Pwb::ResponsiveVariants.avif_supported? ? 'enabled' : 'disabled'}"
      puts "Formats: #{Pwb::ResponsiveVariants.formats_to_generate.join(', ')}"
      puts "Widths: #{Pwb::ResponsiveVariants::WIDTHS.join(', ')}"
      puts

      models = [Pwb::PropPhoto, Pwb::ContentPhoto, Pwb::WebsitePhoto]

      models.each do |model_class|
        generate_for_model(model_class)
      end

      puts
      puts "All variant generation jobs enqueued."
      puts "Monitor progress in your job queue (SolidQueue/Sidekiq)."
    end

    desc "Generate responsive variants for PropPhoto records only"
    task prop_photos: :environment do
      generate_for_model(Pwb::PropPhoto)
    end

    desc "Generate responsive variants for ContentPhoto records only"
    task content_photos: :environment do
      generate_for_model(Pwb::ContentPhoto)
    end

    desc "Generate responsive variants for WebsitePhoto records only"
    task website_photos: :environment do
      generate_for_model(Pwb::WebsitePhoto)
    end

    desc "Generate variants for a single photo (MODEL=Pwb::PropPhoto ID=123)"
    task :single, [:model, :id] => :environment do |_t, args|
      model_class = (args[:model] || ENV["MODEL"])&.constantize
      record_id = args[:id] || ENV["ID"]

      unless model_class && record_id
        puts "Usage: rake images:variants:single MODEL=Pwb::PropPhoto ID=123"
        puts "   or: rake 'images:variants:single[Pwb::PropPhoto,123]'"
        exit 1
      end

      record = model_class.find(record_id)
      attachment = record.image

      unless attachment.attached?
        puts "No image attached to #{model_class}##{record_id}"
        exit 1
      end

      if record.respond_to?(:external_url) && record.external_url.present?
        puts "#{model_class}##{record_id} uses an external URL - skipping"
        exit 0
      end

      puts "Generating variants for #{model_class}##{record_id}..."
      puts "Original: #{attachment.blob.filename} (#{attachment.blob.metadata[:width]}x#{attachment.blob.metadata[:height]})"

      generator = Pwb::ResponsiveVariantGenerator.new(attachment)

      if generator.generate_all!
        puts "Successfully generated all variants"
      else
        puts "Errors occurred:"
        generator.errors.each do |error|
          puts "  - #{error.inspect}"
        end
        exit 1
      end
    end

    desc "Show variant generation statistics"
    task stats: :environment do
      puts "Responsive Image Variant Statistics"
      puts "=" * 40
      puts

      models = [Pwb::PropPhoto, Pwb::ContentPhoto, Pwb::WebsitePhoto]

      models.each do |model_class|
        total = model_class.count
        with_image = model_class.joins(:image_attachment).count
        external = model_class.where.not(external_url: [nil, ""]).count
        eligible = with_image - external

        puts "#{model_class.name}:"
        puts "  Total records: #{total}"
        puts "  With uploaded image: #{with_image}"
        puts "  External URL: #{external}"
        puts "  Eligible for variants: #{eligible}"
        puts
      end

      puts "Configuration:"
      puts "  AVIF support: #{Pwb::ResponsiveVariants.avif_supported?}"
      puts "  Formats: #{Pwb::ResponsiveVariants.formats_to_generate.join(', ')}"
      puts "  Widths: #{Pwb::ResponsiveVariants::WIDTHS.join(', ')}"
      puts "  Variants per image: #{Pwb::ResponsiveVariants::WIDTHS.size * Pwb::ResponsiveVariants.formats_to_generate.size}"
    end

    def generate_for_model(model_class)
      puts "Processing #{model_class.name}..."

      total = model_class.count
      processed = 0
      skipped = 0

      model_class.find_each do |record|
        if record.respond_to?(:image) && record.image.attached? &&
           (record.external_url.blank? rescue true)
          Pwb::ImageVariantGeneratorJob.perform_later(model_class.name, record.id)
          processed += 1
        else
          skipped += 1
        end

        print "\r  Progress: #{processed + skipped}/#{total} (#{skipped} skipped)"
      end

      puts
      puts "  Enqueued #{processed} jobs, skipped #{skipped} records"
    end
  end
end
