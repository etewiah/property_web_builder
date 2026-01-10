# frozen_string_literal: true

namespace :pwb do
  namespace :testimonials do
    desc "Seed testimonials from YAML files for a website"
    task seed: :environment do
      website = Pwb::Website.first
      
      unless website
        puts "No website found. Please create a website first."
        exit
      end

      testimonial_files = Dir[Rails.root.join('db/yml_seeds/testimonials/*.yml')]
      
      if testimonial_files.empty?
        puts "No testimonial YAML files found in db/yml_seeds/testimonials/"
        exit
      end

      testimonial_files.each do |file|
        data = YAML.load_file(file)
        
        testimonial = website.testimonials.find_or_initialize_by(
          author_name: data['author_name']
        )
        
        testimonial.assign_attributes(
          author_role: data['author_role'],
          quote: data['quote'],
          rating: data['rating'],
          position: data['position'],
          visible: data['visible'],
          featured: data['featured']
        )
        
        if testimonial.save
          puts "✓ #{testimonial.author_name}"
        else
          puts "✗ Failed to save #{data['author_name']}: #{testimonial.errors.full_messages.join(', ')}"
        end
      end
      
      puts "\nSeeded #{website.testimonials.count} testimonials for #{website.subdomain || 'website'}"
    end
  end
end
