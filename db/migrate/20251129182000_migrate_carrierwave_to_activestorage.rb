class MigrateCarrierwaveToActivestorage < ActiveRecord::Migration[8.0]
  def up
    # Migrate ContentPhoto images
    migrate_content_photos
    
    # Migrate PropPhoto images  
    migrate_prop_photos
    
    # Migrate WebsitePhoto images
    migrate_website_photos
  end

  def down
    # Remove ActiveStorage attachments and restore CarrierWave paths
    # This is a destructive operation and should be used with caution
    puts "WARNING: This will remove ActiveStorage attachments and restore CarrierWave paths"
    puts "Make sure you have backups before proceeding"
    
    # Remove all ActiveStorage attachments for these models
    Pwb::ContentPhoto.find_each do |photo|
      photo.image.purge if photo.image.attached?
    end
    
    Pwb::PropPhoto.find_each do |photo|
      photo.image.purge if photo.image.attached?
    end
    
    Pwb::WebsitePhoto.find_each do |photo|
      photo.image.purge if photo.image.attached?
    end
  end

  private

  def migrate_content_photos
    puts "Migrating ContentPhoto images..."
    
    Pwb::ContentPhoto.find_each do |photo|
      next unless photo.image.present? && !photo.image.attached?
      
      file_path = get_file_path(photo, 'content_photo')
      attach_file_to_record(photo, file_path) if file_path
    end
  end

  def migrate_prop_photos
    puts "Migrating PropPhoto images..."
    
    Pwb::PropPhoto.find_each do |photo|
      next unless photo.image.present? && !photo.image.attached?
      
      file_path = get_file_path(photo, 'prop_photo')
      attach_file_to_record(photo, file_path) if file_path
    end
  end

  def migrate_website_photos
    puts "Migrating WebsitePhoto images..."
    
    Pwb::WebsitePhoto.find_each do |photo|
      next unless photo.image.present? && !photo.image.attached?
      
      file_path = get_file_path(photo, 'website_photo')
      attach_file_to_record(photo, file_path) if file_path
    end
  end

  def get_file_path(photo, model_type)
    # CarrierWave typically stores files in public/uploads/
    # The image column contains the relative path from the uploads directory
    
    if photo.image.start_with?('http')
      # This is a URL (possibly Cloudinary), skip for now
      puts "Skipping URL-based image for #{model_type} ID #{photo.id}: #{photo.image}"
      return nil
    end
    
    # For local files, construct the full path
    if photo.image.start_with?('/')
      # Absolute path
      file_path = Rails.root.join('public', photo.image[1..-1])
    else
      # Relative path from uploads directory
      file_path = Rails.root.join('public', 'uploads', photo.image)
    end
    
    if File.exist?(file_path)
      file_path
    else
      puts "File not found for #{model_type} ID #{photo.id}: #{file_path}"
      nil
    end
  end

  def attach_file_to_record(photo, file_path)
    begin
      photo.image.attach(
        io: File.open(file_path),
        filename: File.basename(file_path),
        content_type: get_content_type(file_path)
      )
      puts "Successfully attached #{file_path} to #{photo.class.name} ID #{photo.id}"
    rescue => e
      puts "Error attaching file #{file_path} to #{photo.class.name} ID #{photo.id}: #{e.message}"
    end
  end

  def get_content_type(file_path)
    case File.extname(file_path).downcase
    when '.jpg', '.jpeg'
      'image/jpeg'
    when '.png'
      'image/png'
    when '.gif'
      'image/gif'
    when '.webp'
      'image/webp'
    else
      'application/octet-stream'
    end
  end
end
